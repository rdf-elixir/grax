defmodule Grax.Schema.LoaderTest do
  use Grax.TestCase

  alias Grax.Schema.Loader

  test "load_all/0" do
    loaded = Loader.load_all()
    assert Example.User in loaded
    assert Example.User in loaded
  end

  test "all_modules/0" do
    modules = Loader.all_modules()
    assert Example.User in modules
    assert Example.User in modules
  end
end
