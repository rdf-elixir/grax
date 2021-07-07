defmodule Grax.Id.Counter.TextFileTest do
  use Grax.TestCase

  alias Grax.Id.Counter

  describe "initialized counter" do
    setup [:with_counter]

    test "counter behaviour", %{counter: counter} do
      assert Counter.TextFile.value(counter) == {:ok, 0}
      assert Counter.TextFile.inc(counter) == {:ok, 1}
      assert Counter.TextFile.value(counter) == {:ok, 1}
      assert Counter.TextFile.inc(counter) == {:ok, 2}
      assert Counter.TextFile.inc(counter) == {:ok, 3}
      assert Counter.TextFile.inc(counter) == {:ok, 4}
      assert Counter.TextFile.value(counter) == {:ok, 4}
      assert Counter.TextFile.reset(counter) == :ok
      assert Counter.TextFile.value(counter) == {:ok, 0}
      assert Counter.TextFile.inc(counter) == {:ok, 1}
      assert Counter.TextFile.value(counter) == {:ok, 1}
      assert Counter.TextFile.reset(counter, 42) == :ok
      assert Counter.TextFile.value(counter) == {:ok, 42}
      assert Counter.TextFile.inc(counter) == {:ok, 43}
      assert Counter.TextFile.value(counter) == {:ok, 43}
    end
  end

  def with_counter(context) do
    name = :example_counter
    remove_counter_file(name)
    on_exit(fn -> remove_counter_file(name) end)
    counter = start_supervised!({Counter.TextFile, name})
    {:ok, Map.put(context, :counter, counter)}
  end

  defp remove_counter_file(name) do
    name
    |> Counter.TextFile.file_path()
    |> File.rm()
  end
end
