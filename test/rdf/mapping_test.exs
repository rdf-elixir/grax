defmodule RDF.MappingTest do
  use ExUnit.Case
  doctest RDF.Mapping

  test "greets the world" do
    assert RDF.Mapping.hello() == :world
  end
end
