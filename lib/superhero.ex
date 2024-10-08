defmodule GenJsonSchema.Superhero do
  @moduledoc false

  @typedoc "This is the Powerstats type"
  @type powerstats :: %{
          intelligence: 0..100,
          strength: 0..100,
          speed: 0..100,
          durability: 0..100,
          power: 0..100,
          combat: 0..100
        }

  @typedoc """
        name: Appearance
        title: This is the appearance
        description: This is the description for appearance
  """
  @type appearance :: %{
          gender: String.t() | nil,
          race: String.t() | nil,
          height: GenJsonSchema.Type.integer(minimum: 100, maximum: 1000, nullable: true),
          weight: GenJsonSchema.Type.integer(minimum: 1, maximum: 250),
          eyeColor: :green | :blue | :brown | :black | :white,
          hairColor: :no_hair | :white | :brown | :black | :blonde | :red
        }

  defmodule Bio do
    @type alive :: boolean()
    @typedoc """
    title: Superhero Biographies
    description: "All you need to know about your Superhero"
    """
    @type t :: %{
            fullName: String.t(),
            alterEgo: String.t(),
            aliases: [String.t()] | nil,
            placeOfBirth: String.t(),
            firstAppearance: String.t(),
            publisher: :marvel | :dc,
            alignment: :good | :bad,
            alive: alive(),
            status: :verified
          }
  end

  @type superhero :: %{
          id: non_neg_integer(),
          name: String.t(),
          slug: String.t(),
          powerstats: powerstats(),
          appearance: appearance(),
          biography: Bio.t(),
          all: powerstats() | appearance() | Bio.t()
        }

  def gen() do
    GenJsonSchema.gen(__MODULE__, :superhero, case: :to_kebab)
  end
end
