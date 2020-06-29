defmodule Exedra.REPL do
  alias Exedra.SessionManager, as: SessionManager
  alias Exedra.Player, as: Player

  def start(player_charlist) do
    playername = String.Chars.to_string player_charlist

    loop_pid = spawn fn ->
      Process.flag(:trap_exit, true) # TODO: determine if necessary
      IO.puts "Hello " <> playername <> "!"
      loop(playername)
    end

    # TODO: Determine if this should be a task or genserver
    spawn fn -> input_listen(playername, loop_pid) end

    login playername, loop_pid

    loop_pid
  end

  def loop(player_name) do
    receive do
      {:input, input} ->
        input
        |> String.Chars.to_string
        |> String.trim_trailing
        |> String.split(" ")
        |> Exedra.WorldManager.player_exec(player_name)
        |> IO.puts
        # TODO this is a race.
        #      Fix WorldManager.player_exec to return the prompt
        {:ok, player} = Exedra.Player.get(player_name)
        IO.puts Player.prompt(player)
        loop(player_name)
      {:die, reason} ->
        # TODO log
        IO.puts player_name <> " lost connection: " <> Atom.to_string(reason)
        logout player_name
        :ok
      {:message, message} ->
        IO.puts message
        # TODO this is a race.
        #      Fix WorldManager.player_exec to return the prompt
        {:ok, player} = Exedra.Player.get(player_name)
        IO.puts Player.prompt(player)
        loop(player_name)
    end
  end

  def input_listen(player_name, loop_pid) do
    prompt = ">"
    case IO.gets prompt do
      {:error, reason} ->
        send loop_pid, {:die, reason}
      :eof ->
        send loop_pid, {:die, :eof}
      data ->
        send loop_pid, {:input, data}
        input_listen(player_name, loop_pid)
    end
  end

  def logout(player_name) do
    SessionManager.delete(SessionManager, player_name)
    {:ok, player} = Exedra.Player.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    Exedra.Room.set(%{room | players: MapSet.delete(room.players, player_name)})
  end

  # TODO: logout existing logins for this player
  def login(player_name, loop_pid) do
    SessionManager.set SessionManager, player_name, loop_pid
    {:ok, player} = Exedra.Player.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    Exedra.Room.set %{room | players: MapSet.put(room.players, player_name)}
  end
end
