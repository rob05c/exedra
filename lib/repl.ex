defmodule Exedra.REPL do
  def start(user_charlist) do
    username = String.Chars.to_string user_charlist
    spawn fn ->
      Process.flag(:trap_exit, true) # TODO: determine if necessary
      IO.puts "Hello " <> username <> "!"
      loop(username)
    end
  end

  def loop(username) do
    prompt = "> "

    case IO.gets prompt do
      {:error, reason} ->
        # TODO log
        IO.puts username <> " lost connection: " <> Atom.to_string(reason)
      input ->
        input
        |> String.Chars.to_string
        |> String.trim_trailing
        |> String.split(" ")
        |> Exedra.Commands.execute(username)
        loop(username)
    end


  end

end
