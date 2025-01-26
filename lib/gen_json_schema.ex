defmodule GenJsonSchema do
  @moduledoc """
  Documentation for `GenJsonSchema`.
  """

  def gen(module, root, opts \\ []) do
    {:ok, types} =
      Code.Typespec.fetch_types(module)

    {:docs_v1, _, :elixir, _, _moduledoc, _, module_doc} = Code.fetch_docs(module)

    typedocs =
      Enum.reduce(module_doc, %{}, fn
        {{:type, type_name, 0}, _lno, [], %{"en" => docstring}, _}, acc ->
          Map.put(acc, type_name, parse_typedoc(docstring))

        {{:type, type_name, 0}, _lno, [], _, _}, acc ->
          Map.put(acc, type_name, parse_typedoc(String.capitalize("#{type_name}")))

        _, acc ->
          acc
      end)

    {objects, user_types} =
      types
      |> Enum.sort_by(fn
        {:type, {_type_name, {:type, 0, _, [{:user_type, {lno, _}, _user_type_name, []}]}, []}} ->
          lno

        {:type, {_type_name, {:remote_type, {lno, _}, _}, _}} ->
          lno

        {:type, {_type_name, {:type, {lno, _}, _, _}, _}} ->
          lno

        _ ->
          :push_to_end
      end)
      |> Enum.reduce({[], []}, fn {:type, {type_name, type_impl, _}},
                                  {object_acc, user_types_acc} ->
        {_, object, user_types} = type(type_impl, opts)
        {[{type_name, object} | object_acc], [user_types | user_types_acc]}
      end)

    root_typedoc = Map.get(typedocs, root, %{})
    root_object = Keyword.fetch!(objects, root) |> Map.merge(root_typedoc)

    definitions =
      user_types
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.reduce([], fn
        {remote_user_type, remote_object}, acc_defs ->
          {%Jason.OrderedObject{values: remote_definitions}, remote_object} =
            Map.pop(remote_object, :definitions)

          [[{remote_user_type, remote_object} | remote_definitions] | acc_defs]

        user_type, acc_defs ->
          typedoc = Map.get(typedocs, user_type, %{})

          object =
            Keyword.fetch!(objects, user_type)

          object = Map.merge(object, typedoc)
          [{user_type, object} | acc_defs]
      end)

    Map.put(root_object, :definitions, Jason.OrderedObject.new(List.flatten(definitions)))
  end

  defp type({:type, _, :map, def_map_fields}, opts) do
    {properties, required, user_types, additional_properties} =
      Enum.reduce(def_map_fields, {[], [], [], false}, fn
        # additional_properties configured in object
        {:type, _, :map_field_exact,
         [{:remote_type, _, [{:atom, 0, String}, {:atom, _, :t}, []]}, type_info]},
        {props, required, acc_us, _additional_properties} ->
          {_is_required, property, user_type} = type(type_info, opts)
          {props, required, [user_type | acc_us], property}

        # object property
        {:type, _, :map_field_exact, [{:atom, _, name}, type_info]},
        {props, required, acc_us, additional_properties} ->
          {is_required, property, user_type} = type(type_info, opts)
          name = format_property(name, opts)

          {[{name, property} | props],
           case is_required do
             true -> [name | required]
             false -> required
           end, [user_type | acc_us], additional_properties}
      end)

    {true,
     %{
       "type" => "object",
       "properties" => Jason.OrderedObject.new(Enum.reverse(properties)),
       "additionalProperties" => additional_properties != false
     }
     |> Map.merge(
       if required == [] do
         %{}
       else
         %{"required" => required}
       end
     ), user_types}
  end

  defp type({:type, _, t, elements}, opts) when t == :list or t == :nonempty_list do
    {user_types, [property]} =
      Enum.reduce(elements, {[], []}, fn type_info, {acc_us, acc_l} ->
        {_is_required, property, user_type} = type(type_info, opts)

        {[user_type | acc_us], [property | acc_l]}
      end)

    extras =
      case t do
        :nonempty_list ->
          %{"minItems" => 1}

        _ ->
          %{}
      end

    case Map.has_key?(property, :enum) do
      true ->
        {true, Map.merge(extras, %{"type" => "array"}), user_types}

      false ->
        {true, Map.merge(extras, %{"type" => "array", "items" => property}), user_types}
    end
  end

  defp type({:type, _, :union, unions}, opts) do
    {is_required, user_types, properties} =
      Enum.reduce(unions, {true, [], []}, fn type_info, {acc_req, acc_us, acc_l} ->
        {_is_required, property, user_type} = type(type_info, opts)

        property =
          case property do
            %{"enum" => [e]} -> e
            %{"const" => c} -> c
            _ -> property |> IO.inspect()
          end

        {acc_req, acc_l, acc_us} =
          case {acc_req, property} do
            {false, nil} -> {false, acc_l, acc_us}
            {false, _} -> {false, [property | acc_l], [user_type | acc_us]}
            {true, nil} -> {false, acc_l, acc_us}
            _ -> {acc_req, [property | acc_l], [user_type | acc_us]}
          end

        {acc_req, acc_us, acc_l}
      end)

    num_properties = length(properties)

    case List.flatten(user_types) == [] do
      true when num_properties > 1 ->
        {is_required, %{"enum" => properties}, user_types}

      false when num_properties > 1 ->
        {is_required, %{"oneOf" => properties}, user_types}

      _ ->
        [property] = properties
        {is_required, property, user_types}
    end
  end

  defp type({:type, _, :range, range}, _opts) do
    [{:integer, _, min}, {:integer, _, max}] = range
    {true, %{"type" => property_type(:integer), "minimum" => min, "maximum" => max}, []}
  end

  defp type({:type, _, :neg_integer, _type_args}, _opts) do
    {true, %{"type" => property_type(:integer), "exclusiveMaximum" => 0}, []}
  end

  defp type({:type, _, :non_neg_integer, _type_args}, _opts) do
    {true, %{"type" => property_type(:integer), "minimum" => 0}, []}
  end

  defp type({:type, _, :pos_integer, _type_args}, _opts) do
    {true, %{"type" => property_type(:integer), "minimum" => 1}, []}
  end

  defp type({:type, _, type, _type_args}, _opts) do
    {true, %{"type" => property_type(type)}, []}
  end

  defp type({:user_type, _, type, _type_args}, _opts) do
    {true, %{"$ref" => "#/definitions/#{type}"}, [type]}
  end

  defp type(
         {:remote_type, _, [{:atom, _, GenJsonSchema.Type}, {:atom, _, type_name}, type_args]},
         _opts
       ) do
    type = property_type({GenJsonSchema.Type, type_name, type_args})
    extra_props = apply(GenJsonSchema.Type, :t, [type_name, type_args])

    type =
      case Map.pop(extra_props, :nullable) do
        {true, extra_props} ->
          %{"oneOf" => [Map.merge(%{"type" => type}, extra_props), %{"type" => "null"}]}

        {_, extra_props} ->
          Map.merge(%{"type" => type}, extra_props)
      end

    {true, type, []}
  end

  defp type({:remote_type, _, [{:atom, _, module_name}, {:atom, _, type_name}, type_args]}, opts) do
    if module_name in [Enum, String] do
      type = property_type({module_name, type_name, type_args})
      {true, %{"type" => type}, []}
    else
      remote_type = GenJsonSchema.gen(module_name, type_name, opts)
      type = "#{module_name}_#{type_name}"

      {true, %{"$ref" => "#/definitions/#{type}"}, [{type, remote_type}]}
    end
  end

  defp type({_val_type, _, nil}, _opts) do
    {false, nil, []}
  end

  defp type({_val_type, _, value}, _opts) when is_boolean(value) or not is_atom(value) do
    {true, %{"enum" => [value]}, []}
  end

  defp type({_val_type, _, value}, _opts) when is_atom(value) do
    {true, %{"const" => value}, []}
  end

  defp property_type({GenJsonSchema.Type, type, _opts}), do: "#{type}"
  defp property_type({String, :t, []}), do: "string"
  defp property_type(:string), do: "string"
  defp property_type(:nonempty_binary), do: "string"
  defp property_type(:binary), do: "string"
  defp property_type(:atom), do: "string"
  defp property_type(:integer), do: "integer"
  defp property_type(:float), do: "number"
  defp property_type(:list), do: "array"
  defp property_type(:nonempty_list), do: "array"
  defp property_type(:range), do: "number"
  defp property_type(:boolean), do: "boolean"
  defp property_type(nil), do: "null"
  defp property_type({_module, _type, _opts}), do: "ref"

  defp parse_typedoc(docstring) when is_binary(docstring) do
    case YamlElixir.read_from_string(docstring) do
      {:ok, docs} when is_map(docs) ->
        docs

      {:ok, docstring} ->
        %{"title" => docstring}

      {:error, _} ->
        %{"title" => docstring}
    end
  end

  defp format_property(name, opts) when is_atom(name) do
    case Keyword.get(opts, :case) do
      nil ->
        "#{name}"

      recase_func ->
        apply(Recase, recase_func, ["#{name}"])
    end
  end
end

defmodule GenJsonSchema.Type do
  @moduledoc """
  Custom types for JsonSchema
  """

  @type string(_opts) :: String.t()
  @type integer(_opts) :: integer()
  @type number(_opts) :: float()

  def t(_type, opts) do
    to_keywords(opts)
    |> Enum.into(%{})
  end

  defp to_keywords([{:type, _, :list, [{:type, _, :tuple, tuple}]}]) do
    [{:atom, _, key}, {_, _, value}] = tuple
    [{key, value}]
  end

  defp to_keywords([{:type, _, :list, [{:type, _, :union, tuples}]}]) do
    tuples
    |> Enum.map(fn {:type, _, :tuple, [{:atom, _, key}, {_, _, value}]} -> {key, value} end)
  end
end
