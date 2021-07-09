defmodule Grax.Id.Counter.Adapter.TestCase do
  use ExUnit.CaseTemplate

  using(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      alias Grax.Id.Counter

      @test_counter_name :example_counter

      describe "initialized counter" do
        setup [:with_clean_fs, :with_counter]

        test "counter behaviour", %{counter: counter} do
          assert unquote(adapter).value(counter) == {:ok, 0}
          assert unquote(adapter).inc(counter) == {:ok, 1}
          assert unquote(adapter).value(counter) == {:ok, 1}
          assert unquote(adapter).inc(counter) == {:ok, 2}
          assert unquote(adapter).inc(counter) == {:ok, 3}
          assert unquote(adapter).inc(counter) == {:ok, 4}
          assert unquote(adapter).value(counter) == {:ok, 4}
          assert unquote(adapter).reset(counter) == :ok
          assert unquote(adapter).value(counter) == {:ok, 0}
          assert unquote(adapter).inc(counter) == {:ok, 1}
          assert unquote(adapter).value(counter) == {:ok, 1}
          assert unquote(adapter).reset(counter, 42) == :ok
          assert unquote(adapter).value(counter) == {:ok, 42}
          assert unquote(adapter).inc(counter) == {:ok, 43}
          assert unquote(adapter).value(counter) == {:ok, 43}
        end

        test "inc when the counter file does not exist", %{counter: counter} do
          assert unquote(adapter).inc(counter) == {:ok, 1}
        end

        test "reset when the counter file does not exist", %{counter: counter} do
          assert unquote(adapter).reset(counter) == :ok
        end
      end

      def with_counter(context) do
        counter = start_supervised!({unquote(adapter), @test_counter_name})
        {:ok, Map.put(context, :counter, @test_counter_name)}
      end

      def with_clean_fs(context) do
        remove_counter_file(@test_counter_name)
        on_exit(fn -> remove_counter_file(@test_counter_name) end)
        {:ok, context}
      end

      def remove_counter_file(name) do
        name
        |> unquote(adapter).file_path()
        |> File.rm()
      end

      defoverridable with_clean_fs: 1, with_counter: 1
    end
  end
end
