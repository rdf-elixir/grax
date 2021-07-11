defmodule Grax.Id.CounterTestHelper do
  import ExUnit.Callbacks

  def with_counter(adapter, name) do
    start_supervised!({adapter, name})
  end

  def with_clean_fs(adapter, name) do
    remove_counter_file(adapter, name)
    on_exit(fn -> remove_counter_file(adapter, name) end)
    :ok
  end

  def remove_counter_file(adapter, name) do
    name
    |> adapter.file_path()
    |> File.rm()
  end
end
