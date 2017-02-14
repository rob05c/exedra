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

    line = prompt
    |> IO.gets
    |> String.Chars.to_string
    |> String.trim_trailing

    line_args = String.split(line, " ")
    # TODO abstract commands
    case List.first(line_args) do
      nil ->
        nil
      "l" ->
        {:ok, user} = Exedra.User.get(username)
        {:ok, room} = Exedra.Room.get(user.room_id)
        IO.puts Exedra.Room.print(room, false)
      "ql" ->
        {:ok, user} = Exedra.User.get(username)
        {:ok, room} = Exedra.Room.get(user.room_id)
        IO.puts Exedra.Room.print(room, true)
      "createroom" ->
        if length(line_args) < 3 do
          IO.puts "You must specify a direction and room name."
        else
          [_ | direction_name] = line_args
          [direction_string | name_list] = direction_name
          room_name = Enum.join(name_list, " ")
          direction = Exedra.Room.dir_string_to_atom(direction_string)
          if direction == :invalid do
            IO.puts "That's not a valid direction."
          else
            {:ok, player} = Exedra.User.get(username)
            {:ok, player_room} = Exedra.Room.get(player.room_id)
            Exedra.Room.create_dir(player_room, direction, room_name, "")
            IO.puts "The mist parts in the " <> Exedra.Room.dir_atom_to_string(direction) <> "."
          end
        end
      "n" ->
        move(username, :n)
      "north" ->
        move(username, :n)
      "e" ->
        move(username, :e)
      "east" ->
        move(username, :e)
      "s" ->
        move(username, :s)
      "south" ->
        move(username, :s)
      "w" ->
        move(username, :w)
      "west" ->
        move(username, :w)
      _ ->
        IO.puts "I don't understand '" <> line <> "'."
    end

    loop(username)
  end

  def move(playername, direction) do
    {:ok, player} = Exedra.User.get(playername)
    {:ok, player_room} = Exedra.Room.get(player.room_id)
    case Map.fetch(player_room.exits, direction) do
      {:ok, to_room_id} ->
        IO.puts "getting room id "
        IO.inspect to_room_id
        {:ok, to_room} = Exedra.Room.get(to_room_id)
        player = %{player | room_id: to_room_id}
        Exedra.User.set(player)
        IO.puts "You meander " <> Exedra.Room.dir_atom_to_string(direction) <> "."
        IO.puts Exedra.Room.print(to_room, false)
      :error ->
        IO.puts "There is no exit in that direction."
    end
  end
end
