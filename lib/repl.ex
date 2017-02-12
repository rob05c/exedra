defmodule Exedra.REPL do
  def start(user_charlist) do
    user = String.Chars.to_string user_charlist
    spawn fn ->
      Process.flag(:trap_exit, true) # TODO: determine if necessary
      IO.puts "Hallo " <> user <> "!"
      loop()
    end
  end

  def loop() do
    prompt = "> "

    line = prompt
    |> IO.gets
    |> String.Chars.to_string
    |> String.trim_trailing

    if line == "hi" do
      IO.puts "Yo."
    else
      IO.puts "I don't understand '" <> line <> "'."
    end
    loop()
  end
end
