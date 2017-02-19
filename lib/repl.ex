defmodule Exedra.REPL do
  alias Exedra.SessionManager, as: SessionManager

  def start(user_charlist) do
    username = String.Chars.to_string user_charlist

    loop_pid = spawn fn ->
      Process.flag(:trap_exit, true) # TODO: determine if necessary
      IO.puts "Hello " <> username <> "!"
      loop(username)
    end

    # TODO: Determine if this should be a task or genserver
    spawn fn -> input_listen(username, loop_pid) end

    SessionManager.set(SessionManager, username, loop_pid)

    loop_pid
  end

  def loop(username) do
    receive do
      {:input, input} ->
        input
        |> String.Chars.to_string
        |> String.trim_trailing
        |> String.split(" ")
        |> Exedra.Commands.execute(username)
        loop(username)
      {:die, reason} ->
        # TODO log
        IO.puts username <> " lost connection: " <> Atom.to_string(reason)
        SessionManager.delete(SessionManager, username)
        :ok
      {:message, message} ->
        IO.puts message
        loop(username)
    end
  end

  def input_listen(username, loop_pid) do
    prompt = "> "
    case IO.gets prompt do
      {:error, reason} ->
        send loop_pid, {:die, reason}
      :eof ->
        send loop_pid, {:die, :eof}
      data ->
        send loop_pid, {:input, data}
        input_listen(username, loop_pid)
    end
  end
end
