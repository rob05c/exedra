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

    login username, loop_pid

    loop_pid
  end

  def loop(username) do
    receive do
      {:input, input} ->
        input
        |> String.Chars.to_string
        |> String.trim_trailing
        |> String.split(" ")
        |> Exedra.WorldManager.user_exec(username)
        |> IO.puts
        loop(username)
      {:die, reason} ->
        # TODO log
        IO.puts username <> " lost connection: " <> Atom.to_string(reason)
        logout username
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

  def logout(player_name) do
    SessionManager.delete(SessionManager, player_name)
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    Exedra.Room.set(%{room | players: MapSet.delete(room.players, player_name)})
  end

  # TODO: logout existing logins for this player
  def login(player_name, loop_pid) do
    SessionManager.set SessionManager, player_name, loop_pid
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    Exedra.Room.set %{room | players: MapSet.put(room.players, player_name)}
  end
end
