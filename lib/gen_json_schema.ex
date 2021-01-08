defmodule GenJsonSchema do
  @moduledoc """
  Documentation for `GenJsonSchema`.
  """

  def gen(module, root) do
    {:ok, types} = Code.Typespec.fetch_types(module)

    types =
      types
      |> Enum.map(fn {:type, {type_name, type_impl, _}} -> {type_name, type_impl} end)
      |> Enum.into(%{})

    {_, object, user_types} =
      types
      |> Map.fetch!(root)
      |> type()

    definitions =
      user_types
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.map(fn user_type ->
        {_, object, _} =
          types
          |> Map.fetch!(user_type)
          |> type()

        {user_type, object}
      end)
      |> Enum.into(%{})

    obj = Map.put(object, :definitions, definitions)

    obj
    |> Jason.encode!(pretty: true)
  end

  defp type({:type, _, :map, def_map_fields}) do
    {properties, required, user_types} =
      Enum.reduce(def_map_fields, {%{}, [], []}, fn
        {:type, _, :map_field_exact, [{:atom, _, name}, type_info]}, {props, required, acc_us} ->
          {is_required, property, user_type} = type(type_info)

          {Map.put(props, name, property),
           case is_required do
             true -> [name | required]
             false -> required
           end, [user_type | acc_us]}
      end)

    {true,
     %{type: :object, properties: properties, required: required, additionalProperties: false},
     user_types}
  end

  defp type({:type, _, t, elements}) when t == :list or t == :nonempty_list do
    {user_types, [property]} =
      Enum.reduce(elements, {[], []}, fn type_info, {acc_us, acc_l} ->
        {_is_required, property, user_type} = type(type_info)

        {[user_type | acc_us], [property | acc_l]}
      end)

    extras =
      case t do
        :nonempty_list ->
          %{minItems: 1}

        _ ->
          %{}
      end

    case Map.has_key?(property, :enum) do
      true ->
        {true, Map.merge(extras, %{type: :array}), user_types}

      false ->
        {true, Map.merge(extras, %{type: :array, items: property}), user_types}
    end
  end

  defp type({:type, _, :union, unions}) do
    {is_required, user_types, properties} =
      Enum.reduce(unions, {true, [], []}, fn type_info, {acc_req, acc_us, acc_l} ->
        {_is_required, property, user_type} = type(type_info)

        property =
          case property do
            %{enum: [e]} -> e
            _ -> property
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
        {is_required, %{enum: properties}, user_types}

      false when num_properties > 1 ->
        {is_required, %{anyOf: properties}, user_types}

      _ ->
        [property] = properties
        {is_required, property, user_types}
    end
  end

  defp type({:type, _, :range, range}) do
    [{:integer, _, min}, {:integer, _, max}] = range
    {true, %{type: property_type(:integer), minimum: min, maximum: max}, []}
  end

  defp type({:type, _, :neg_integer, _type_args}) do
    {true, %{type: property_type(:integer), exclusiveMaximum: 0}, []}
  end

  defp type({:type, _, :non_neg_integer, _type_args}) do
    {true, %{type: property_type(:integer), minimum: 0}, []}
  end

  defp type({:type, _, :pos_integer, _type_args}) do
    {true, %{type: property_type(:integer), minimum: 1}, []}
  end

  defp type({:type, _, type, _type_args}) do
    {true, %{type: property_type(type)}, []}
  end

  defp type({:user_type, _, type, _type_args}) do
    {true, %{"$ref": "#/definitions/#{type}"}, [type]}
  end

  defp type({:remote_type, _, [{:atom, _, module_name}, {:atom, _, type_name}, type_args]}) do
    type = property_type({module_name, type_name, type_args})

    extra_props =
      case module_name do
        GenJsonSchema.Type ->
          apply(GenJsonSchema.Type, :t, [type_name, type_args])

        _ ->
          %{}
      end

    {true, Map.merge(%{type: type}, extra_props), []}
  end

  defp type({_val_type, _, nil}) do
    {false, nil, []}
  end

  defp type({_val_type, _, value}) do
    {true, %{enum: [value]}, []}
  end

  defp property_type({GenJsonSchema.Type, type, _opts}), do: "#{type}"
  defp property_type({String, :t, []}), do: "string"
  defp property_type(:string), do: "string"
  defp property_type(:atom), do: "string"
  defp property_type(:integer), do: "integer"
  defp property_type(:float), do: "number"
  defp property_type(:list), do: "array"
  defp property_type(:nonempty_list), do: "array"
  defp property_type(:range), do: "number"
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
