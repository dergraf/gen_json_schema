defmodule GenJsonSchemaTest do
  use ExUnit.Case

  test "greets the world" do
    schema = GenJsonSchema.Superhero.gen()
    IO.puts(schema)
  end
end
