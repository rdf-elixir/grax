defmodule Grax.Id.Counter.SupervisorTest do
  use ExUnit.Case

  alias Grax.Id.Counter

  @text_file_counter_name :text_file_counter
  @dets_counter_name :dets_counter

  setup do
    with {:ok, context} <- with_text_file_counter(%{}) do
      with_dets_counter(context)
    end
  end

  test "counters are restarted and persisted", %{
    text_file_counter_pid: text_file_counter_pid,
    text_file_counter_value: text_file_counter_value,
    dets_counter_pid: dets_counter_pid,
    dets_counter_value: dets_counter_value
  } do
    assert Counter.TextFile.process(@text_file_counter_name) == text_file_counter_pid
    Process.exit(text_file_counter_pid, :kill)
    Process.sleep(100)

    refute text_file_counter_pid ==
             (new_text_file_counter_pid = Counter.TextFile.process(@text_file_counter_name))

    assert Counter.TextFile.value(@text_file_counter_name) == {:ok, text_file_counter_value}

    assert Counter.Dets.process(@dets_counter_name) == dets_counter_pid
    Process.exit(dets_counter_pid, :kill)
    Process.sleep(100)

    refute dets_counter_pid ==
             (new_dets_counter_pid = Counter.Dets.process(@dets_counter_name))

    assert Counter.Dets.value(@dets_counter_name) == {:ok, dets_counter_value}

    Counter.TextFile.inc(@text_file_counter_name)
    Counter.Dets.inc(@dets_counter_name)

    Counter.Supervisor
    |> Process.whereis()
    |> Process.exit(:kill)

    Process.sleep(100)

    refute Counter.TextFile.process(@text_file_counter_name) == new_text_file_counter_pid
    refute Counter.Dets.process(@dets_counter_name) == new_dets_counter_pid

    assert Counter.TextFile.value(@text_file_counter_name) == {:ok, text_file_counter_value + 1}
    assert Counter.Dets.value(@dets_counter_name) == {:ok, dets_counter_value + 1}
  end

  def with_text_file_counter(context) do
    counter_path = Counter.TextFile.file_path(@text_file_counter_name)
    Enum.each(1..3, fn _ -> Counter.TextFile.inc(@text_file_counter_name) end)
    on_exit(fn -> File.rm(counter_path) end)

    {:ok,
     context
     |> Map.put(
       :text_file_counter_value,
       3 = Counter.TextFile.value(@text_file_counter_name) |> elem(1)
     )
     |> Map.put(:text_file_counter_pid, Counter.TextFile.process(@text_file_counter_name))}
  end

  def with_dets_counter(context) do
    counter_path = Counter.Dets.file_path(@dets_counter_name)
    Enum.each(1..4, fn _ -> Counter.Dets.inc(@dets_counter_name) end)
    # TODO: This doesn't work across multiple test cases, since the ets table is still present
    on_exit(fn -> File.rm(counter_path) end)

    {:ok,
     context
     |> Map.put(:dets_counter_value, 4 = Counter.Dets.value(@dets_counter_name) |> elem(1))
     |> Map.put(:dets_counter_pid, Counter.Dets.process(@dets_counter_name))}
  end
end
