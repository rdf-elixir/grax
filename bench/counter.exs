counter_path = "bench/data"
Grax.Id.Counter.Dets.start_link(:dets_counter, path: counter_path)
Grax.Id.Counter.TextFile.start_link(:text_file_counter, path: counter_path)

IO.puts("---------------------------------------------------------------------")
IO.puts("Read benchmark")
IO.puts("---------------------------------------------------------------------\n")

Benchee.run(%{
  "text file" => fn -> Grax.Id.Counter.TextFile.value(:text_file_counter) end,
  "dets" => fn -> Grax.Id.Counter.Dets.value(:dets_counter) end
})

IO.puts("---------------------------------------------------------------------")
IO.puts("Write benchmark")
IO.puts("---------------------------------------------------------------------\n")

Benchee.run(%{
  "text file" => fn -> Grax.Id.Counter.TextFile.inc(:text_file_counter) end,
  "dets" => fn -> Grax.Id.Counter.Dets.inc(:dets_counter) end
})
