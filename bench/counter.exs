Grax.Id.Counter.Dets.start_link(:dets_counter)
Grax.Id.Counter.TextFile.start_link(:text_file_counter)

IO.puts("---------------------------------------------------------------------")
IO.puts("Read benchmark")
IO.puts("---------------------------------------------------------------------\n")

Benchee.run(%{
  "text file" => fn -> Grax.Id.Counter.TextFile.value(:text_file_counter) end,
  "dets" => fn -> Grax.Id.Counter.Dets.value(:dets_counter) end
})

IO.puts("\n\n")
IO.puts("---------------------------------------------------------------------")
IO.puts("Write benchmark")
IO.puts("---------------------------------------------------------------------\n")

Benchee.run(%{
  "text file" => fn -> Grax.Id.Counter.TextFile.inc(:text_file_counter) end,
  "dets" => fn -> Grax.Id.Counter.Dets.inc(:dets_counter) end
})

Grax.Id.Counter.Dets.file_path(:dets_counter) |> File.rm()
Grax.Id.Counter.TextFile.file_path(:text_file_counter) |> File.rm()
