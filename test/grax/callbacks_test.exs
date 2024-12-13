defmodule Grax.CallbacksTest do
  use Grax.TestCase

  test "on_load/3" do
    assert {:ok, %Example.UserWithCallbacks{} = user} =
             Example.UserWithCallbacks.load(example_graph(), EX.User0, test: 42)

    assert user ==
             user0_with_callback()
             |> Grax.put_additional_statements(%{RDF.type() => [EX.User, EX.PremiumUser]})
  end

  test "on_load/3 during preloading" do
    assert {:ok, %Example.UserWithCallbacks{} = user} =
             example_graph()
             |> Graph.add([
               EX.friend(EX.User0, EX.User1),
               RDF.type(EX.User1, EX.PremiumUser)
             ])
             |> Example.UserWithCallbacks.load(EX.User0, test: 42)

    assert user ==
             user0_with_callback()
             |> Grax.put!(
               friends: [
                 Example.UserWithCallbacks.build!(EX.User1,
                   name: "Erika Mustermann",
                   email: "erika@mustermann.de",
                   canonical_email: "mailto:erika@mustermann.de",
                   comments: [~I<http://example.com/Comment1>],
                   customer_type: :admin
                 )
                 |> Grax.put_additional_statements(%{RDF.type() => [EX.User, EX.PremiumUser]})
               ]
             )
             |> Grax.put_additional_statements(%{RDF.type() => [EX.User, EX.PremiumUser]})
  end

  test "on_to_rdf3" do
    assert user0_with_callback() |> Grax.to_rdf(test: 42) ==
             {:ok,
              :post
              |> example_graph()
              |> Graph.add(
                :user
                |> example_description()
                |> Description.put({RDF.type(), [EX.User, EX.Admin]})
              )}
  end

  def user0_with_callback() do
    %{
      struct(
        Example.UserWithCallbacks,
        Map.from_struct(Example.user(EX.User0, depth: 1))
      )
      | customer_type: :admin
    }
  end
end
