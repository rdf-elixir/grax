defmodule RDF.MappingTest do
  use RDF.Mapping.TestCase

  doctest RDF.Mapping

  describe "build/1" do
    test "with a string id" do
      assert Example.User.build("http://example.com/user/1") ==
               {:ok, %Example.User{__id__: IRI.new("http://example.com/user/1")}}
    end

    test "with a vocabulary namespace term" do
      assert Example.User.build(EX.User0) ==
               {:ok, %Example.User{__id__: IRI.new(EX.User0)}}
    end
  end
end
