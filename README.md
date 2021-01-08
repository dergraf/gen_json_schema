# gen_json_schema

Generates a JSON Schema from Elixir/Erlang type specs.

Status: Usable (though incomplete and likely buggy)

TODO: Add Tests


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gen_json_schema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gen_json_schema, "~> 0.1.0"}
  ]
end
```

## Usage

The example module below defines multiple types and implements a single `gen/0` function which returns a JSON document containing the JSON schema.

```elixir
defmodule Superhero do
  @type powerstats :: %{
          intelligence: 0..100,
          strength: 0..100,
          speed: 0..100,
          durability: 0..100,
          power: 0..100,
          combat: 0..100
        }
  @type appearance :: %{
          gender: String.t() | nil,
          race: String.t() | nil,
          height: GenJsonSchema.Type.integer(minimum: 100, maximum: 1000),
          weight: GenJsonSchema.Type.integer(minimum: 1, maximum: 250),
          eyeColor: :green | :blue | :brown | :black | :white,
          hairColor: :no_hair | :white | :brown | :black | :blonde | :red
        }
  @type biography :: %{
          fullName: String.t(),
          alterEgo: String.t(),
          aliases: [String.t()] | nil,
          placeOfBirth: String.t(),
          firstAppearance: String.t(),
          publisher: :marvel | :dc,
          alignment: :good | :bad
        }

  @type superhero :: %{
          id: non_neg_integer(),
          name: String.t(),
          slug: String.t(),
          powerstats: powerstats(),
          appearance: appearance(),
          biography: biography()
        }

  def gen() do
    GenJsonSchema.gen(__MODULE__, :superhero)
  end
end
```

Generating the schema:

```
$ iex -S mix
iex(1)> Superhero.gen |> IO.puts
{
  "additionalProperties": false,
  "definitions": {
    "appearance": {
      "additionalProperties": false,
      "properties": {
        "eyeColor": {
          "enum": [
            "white",
            "black",
            "brown",
            "blue",
            "green"
          ]
        },
        "gender": {
          "type": "string"
        },
        "hairColor": {
          "enum": [
            "red",
            "blonde",
            "black",
            "brown",
            "white",
            "no_hair"
          ]
        },
        "height": {
          "maximum": 1000,
          "minimum": 100,
          "type": "integer"
        },
        "race": {
          "type": "string"
        },
        "weight": {
          "maximum": 250,
          "minimum": 1,
          "type": "integer"
        }
      },
      "required": [
        "hairColor",
        "eyeColor",
        "weight",
        "height"
      ],
      "type": "object"
    },
    "biography": {
      "additionalProperties": false,
      "properties": {
        "aliases": {
          "items": {
            "type": "string"
          },
          "type": "array"
        },
        "alignment": {
          "enum": [
            "bad",
            "good"
          ]
        },
        "alterEgo": {
          "type": "string"
        },
        "firstAppearance": {
          "type": "string"
        }, 
        "fullName": {
          "type": "string"
        },
        "placeOfBirth": {
          "type": "string"
        },
        "publisher": {
          "enum": [
            "dc",
            "marvel"
          ]
        }
      },
      "required": [
        "alignment",
        "publisher",
        "firstAppearance",
        "placeOfBirth",
        "alterEgo",
        "fullName"
      ],
      "type": "object"
    },
    "powerstats": {
      "additionalProperties": false,
      "properties": {
        "combat": {
          "maximum": 100,
          "minimum": 0,
          "type": "integer"
        },
        "durability": {
          "maximum": 100,
          "minimum": 0,
          "type": "integer"
        },
        "intelligence": {
          "maximum": 100,
          "minimum": 0,
          "type": "integer"
        },
        "power": {
          "maximum": 100,
          "minimum": 0,
          "type": "integer"
        },
        "speed": {
          "maximum": 100,
          "minimum": 0,
          "type": "integer"
        },
        "strength": {
          "maximum": 100,
          "minimum": 0,
          "type": "integer"
        }
      },
      "required": [
        "combat",
        "power",
        "durability",
        "speed",
        "strength",
        "intelligence"
      ],
      "type": "object"
    }
  },
  "properties": {
    "appearance": {
      "$ref": "#/definitions/appearance"
    },
    "biography": {
      "$ref": "#/definitions/biography"
    },
    "id": {
      "minimum": 0,
      "type": "integer"
    },
    "name": {
      "type": "string"
    },
    "powerstats": {
      "$ref": "#/definitions/powerstats"
    },
    "slug": {
      "type": "string"
    }
  },
  "required": [
    "biography",
    "appearance",
    "powerstats", 
    "slug",
    "name",
    "id"
  ],
  "type": "object"
}
:ok
```