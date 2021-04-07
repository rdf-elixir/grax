defmodule Grax.ConfigTest do
  use Grax.TestCase

  @original_config Application.get_all_env(:grax)

  setup %{config: config} do
    Application.put_all_env(grax: config)

    on_exit(&reset_config/0)

    {:ok, config}
  end

  @tag config: [id_spec: Example.IdSpecs.AppConfigIdSpec]
  test "application id_spec" do
    defmodule TestSchema do
      use Grax.Schema

      schema do
        property foo: EX.foo()
      end
    end

    assert TestSchema.__id_spec__() == Example.IdSpecs.AppConfigIdSpec

    assert TestSchema.__id_schema__() ==
             Example.IdSpecs.AppConfigIdSpec.expected_id_schema()

    assert {:ok, %{__struct__: TestSchema, __id__: %RDF.IRI{value: _}, foo: "foo"}} =
             TestSchema.build(foo: "foo")
  end

  def reset_config do
    Application.get_all_env(:grax)
    |> Enum.each(fn {key, _} -> Application.delete_env(:grax, key) end)

    Application.put_all_env(grax: @original_config)
  end
end
