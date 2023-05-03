defmodule Grax.Schema.InheritanceTest do
  use Grax.TestCase

  alias Grax.Schema.Inheritance

  test "paths/1" do
    assert Inheritance.paths(Example.User) == []
    assert Inheritance.paths(Example.ParentSchema) == []
    assert Inheritance.paths(Example.ChildSchema) == [[Example.ParentSchema]]
    assert Inheritance.paths(Example.ChildSchemaWithClass) == [[Example.ParentSchema]]

    assert Inheritance.paths(Example.ChildOfMany) == [
             [Example.ParentSchema],
             [Example.AnotherParentSchema],
             [Example.ChildSchemaWithClass, Example.ParentSchema]
           ]
  end
end
