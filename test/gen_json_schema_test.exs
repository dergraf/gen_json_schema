defmodule GenJsonSchemaTest do
  use ExUnit.Case

  test "greets the world" do
    schema = GenJsonSchema.TestSpecs.gen()
    IO.puts(schema)
  end
end
