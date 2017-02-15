defmodule Exedra.Commands do
  def execute(["north"     | _], username),  do: move(username, :n)
  def execute(["n"         | _], username),  do: move(username, :n)
  def execute(["east"      | _], username),  do: move(username, :e)
  def execute(["e"         | _], username),  do: move(username, :e)
  def execute(["south"     | _], username),  do: move(username, :s)
  def execute(["s"         | _], username),  do: move(username, :s)
  def execute(["west"      | _], username),  do: move(username, :w)
  def execute(["w"         | _], username),  do: move(username, :w)
  def execute(["northeast" | _], username),  do: move(username, :ne)
  def execute(["ne"        | _], username),  do: move(username, :ne)
  def execute(["northwest" | _], username),  do: move(username, :nw)
  def execute(["nw"        | _], username),  do: move(username, :nw)
  def execute(["southeast" | _], username),  do: move(username, :se)
  def execute(["se"        | _], username),  do: move(username, :se)
  def execute(["southwest" | _], username),  do: move(username, :sw)
  def execute(["sw"        | _], username),  do: move(username, :sw)

  def execute(["look" | _], username), do: look(username)
  def execute(["l"    | _], username), do: look(username)

  def execute(["quicklook" | _], username), do: quick_look(username)
  def execute(["ql"        | _], username), do: quick_look(username)

  def execute(["createroom" | args], username), do: create_room(username, args)
  def execute(["cr"         | args], username), do: create_room(username, args)

  def execute(["createitem" | args], username), do: create_item(username, args)
  def execute(["ci"         | args], username), do: create_item(username, args)

  def execute(["get" | args], username), do: get_item(username, args)
  def execute(["g"   | args], username), do: get_item(username, args)

  def execute(["drop" | args], username), do: drop_item(username, args)
  def execute(["d"    | args], username), do: drop_item(username, args)

  def execute([""], _), do: nothing()

  def execute(_, _), do: unknown()

  def look(username) do
    {:ok, user} = Exedra.User.get(username)
    {:ok, room} = Exedra.Room.get(user.room_id)
    IO.puts Exedra.Room.print(room, false)
  end

  def quick_look(username) do
    {:ok, user} = Exedra.User.get(username)
    {:ok, room} = Exedra.Room.get(user.room_id)
    IO.puts Exedra.Room.print(room, true)
  end

  def create_room(username, args) do
    if length(args) < 2 do
      IO.puts "You must specify a direction and room name."
    else
      [direction_string | name_list] = args
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
  end

  def create_item(username, args) do
    if length(args) < 2 do
      IO.puts "You must specify a name and brief description."
    else
      [name | description_list] = args
      brief_description = Enum.join(description_list, " ")
      {:ok, player} = Exedra.User.get(username)
      Exedra.Item.create(player, name, brief_description)
      IO.puts "A " <> brief_description <> " materializes in your hands."
    end
  end

  def get_item(username, args) do
    if length(args) < 1 do
      IO.puts "What do you want to get?"
    else
      name_or_id = List.first(args)

      {:ok, player} = Exedra.User.get(username)
      {:ok, room} = Exedra.Room.get(player.room_id)

      case Integer.parse(name_or_id) do
        {id, _} ->
          if MapSet.member?(room.items, id) do
            Exedra.Item.pickup(id, room, player)
            {:ok, item} = Exedra.Item.get(id)
            IO.puts "You pick up " <> item.brief <> "."
          else
            IO.puts "That isn't here."
          end
        :error ->
          name = name_or_id
          item_id = Enum.find room.items, fn(item_id) ->
            {:ok, item} = Exedra.Item.get(item_id)
            item.name == name
          end
          if item_id == nil do
            IO.puts "That is not here."
          else
            Exedra.Item.pickup(item_id, room, player)
            {:ok, item} = Exedra.Item.get(item_id)
            IO.puts "You pick up " <> item.brief <> "."
          end
      end
    end
  end

  # TODO: abstract duplication with get_item
  def drop_item(username, args) do
    if length(args) < 1 do
      IO.puts "What do you want to get?"
    else
      name_or_id = List.first(args)
      {:ok, player} = Exedra.User.get(username)
      case Integer.parse(name_or_id) do
        {id, _} ->
          if MapSet.member?(player.items, id) do
            {:ok, room} = Exedra.Room.get(player.room_id)
            Exedra.Item.drop(id, room, player)
            {:ok, item} = Exedra.Item.get(id)
            IO.puts "You drop " <> item.brief <> "."
          else
            IO.puts "That isn't here."
          end
        :error ->
          name = name_or_id
          item_id = Enum.find player.items, fn(item_id) ->
            {:ok, item} = Exedra.Item.get(item_id)
            item.name == name
          end
          if item_id == nil do
            IO.puts "That is not here."
          else
            {:ok, room} = Exedra.Room.get(player.room_id)
            Exedra.Item.drop(item_id, room, player)
            {:ok, item} = Exedra.Item.get(item_id)
            IO.puts "You drop " <> item.brief <> "."
          end
      end
    end
  end


  def move(playername, direction) do
    {:ok, player} = Exedra.User.get(playername)
    {:ok, player_room} = Exedra.Room.get(player.room_id)
    case Map.fetch(player_room.exits, direction) do
      {:ok, to_room_id} ->
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

  def unknown() do
    IO.puts "I don't understand."
  end

  def nothing() do
    nil
  end
end
