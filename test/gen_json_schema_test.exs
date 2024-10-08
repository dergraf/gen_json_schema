defmodule GenJsonSchemaTest do
  use ExUnit.Case

  test "greets the world" do
    schema = GenJsonSchema.Superhero.gen()
    IO.inspect(schema)
  end
end
