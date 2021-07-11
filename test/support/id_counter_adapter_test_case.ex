defmodule Grax.Id.Counter.Adapter.TestCase do
  use ExUnit.CaseTemplate

  using(opts) do
    adapter = Keyword.get(opts, :adapter)

    quote do
      alias Grax.Id.{Counter, CounterTestHelper}

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
        CounterTestHelper.with_counter(unquote(adapter), @test_counter_name)
        {:ok, Map.put(context, :counter, @test_counter_name)}
      end

      def with_clean_fs(context) do
        CounterTestHelper.with_clean_fs(unquote(adapter), @test_counter_name)
        {:ok, context}
      end

      defoverridable with_clean_fs: 1, with_counter: 1
    end
  end
end
