defmodule Grax.ConfigTest do
  use Grax.TestCase

  @original_config Map.new([:grax, :example_app], &{&1, Application.get_all_env(&1)})

  setup %{config: config} do
    Application.put_all_env(config)

    on_exit(&reset_config/0)

    {:ok, config}
  end

  describe "application id_spec" do
    @tag config: [example_app: [grax_id_spec: Example.IdSpecs.AppConfigIdSpec]]
    test "with id_spec_from_otp_app option" do
      defmodule TestSchema1 do
        use Grax.Schema, id_spec_from_otp_app: :example_app

        schema do
          property foo: EX.foo()
        end
      end

      assert TestSchema1.__id_spec__() == Example.IdSpecs.AppConfigIdSpec

      assert TestSchema1.__id_schema__() ==
               Example.IdSpecs.AppConfigIdSpec.expected_id_schema(TestSchema1)

      assert {:ok, %{__struct__: TestSchema1, __id__: %RDF.IRI{value: _}, foo: "foo"}} =
               TestSchema1.build(foo: "foo")
    end

    @tag skip: "TODO: How can we test this case"
    test "with application name detection" do
      defmodule TestSchema2 do
        use Grax.Schema

        schema do
          property foo: EX.foo()
        end
      end

      assert TestSchema2.__id_spec__() == Example.IdSpecs.AppConfigIdSpec

      assert TestSchema2.__id_schema__() ==
               Example.IdSpecs.AppConfigIdSpec.expected_id_schema(TestSchema2)

      assert {:ok, %{__struct__: TestSchema2, __id__: %RDF.IRI{value: _}, foo: "foo"}} =
               TestSchema2.build(foo: "foo")
    end
  end

  def reset_config do
    @original_config
    |> Enum.each(fn {app_key, config} ->
      Application.get_all_env(app_key)
      |> Enum.each(fn {key, _} -> Application.delete_env(app_key, key) end)

      Application.put_all_env([{app_key, config}])
    end)
  end
end
