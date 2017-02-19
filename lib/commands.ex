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

  def execute(["createitem"       | args], username), do: create_item(       username, args)
  def execute(["ci"               | args], username), do: create_item(       username, args)
  def execute(["describeitem"     | args], username), do: describe_item(     username, args)
  def execute(["di"               | args], username), do: describe_item(     username, args)
  def execute(["roomdescribeitem" | args], username), do: room_describe_item(username, args)
  def execute(["rdi"              | args], username), do: room_describe_item(username, args)


  def execute(["get" | args], username), do: get_item(username, args)
  def execute(["g"   | args], username), do: get_item(username, args)

  def execute(["drop" | args], username), do: drop_item(username, args)
  def execute(["d"    | args], username), do: drop_item(username, args)

  def execute(["items" | args], username), do: items(username)
  def execute(["i"     | args], username), do: items(username)

  def execute([""], _), do: nothing()

  def execute(_, _), do: unknown()

  def items(username) do
    {:ok, player} = Exedra.User.get(username)
    # TODO: add "and" before final item.
    items = player.items
    |> Enum.map(fn(item_id) ->
        {:ok, item} = Exedra.Item.get(item_id)
        item.brief
      end)
    |> Enum.join(", ")
    IO.puts "You are holding: " <> items <> "."
  end


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

  def room_describe_item(username, args) do
    # len(args) >= 5 because name_or_id is arg 1, and the minimal grammatically correct description is 'article noun verb adverb', e.g. 'the sword lies here'
    if length(args) < 5 do
      IO.puts "What do you want to describe?"
    else
      [name_or_id | description_words] = args
      room_description = Enum.join(description_words, " ")
      {:ok, player} = Exedra.User.get(username)
      case Integer.parse(name_or_id) do
        {id, _} ->
          if MapSet.member?(player.items, id) do
            {:ok, item} = Exedra.Item.get(id)
            Exedra.Item.set %{item | room_description: room_description}
            IO.puts "A vision of " <> item.brief <> " on the ground flashes in your mind's eye."
          else
            IO.puts "You aren't carrying that."
          end
        :error ->
          name = name_or_id
          item_id = Enum.find player.items, fn(item_id) ->
            {:ok, item} = Exedra.Item.get(item_id)
            item.name == name
          end
          if item_id == nil do
            IO.puts "You are not carrying that."
          else
            {:ok, item} = Exedra.Item.get(item_id)
            Exedra.Item.set %{item | room_description: room_description}
            IO.puts "A vision of " <> item.brief <> " on the ground flashes in your mind's eye."
          end
      end
    end
  end

  # TODO: abstract duplication with room_describe_item
  def describe_item(username, args) do
    # len(args) >= 5 because name_or_id is arg 1, and the minimal grammatically correct description is 'article noun verb adverb', e.g. 'the sword lies here'
    if length(args) < 5 do
      IO.puts "What do you want to describe?"
    else
      [name_or_id | description_words] = args
      description = Enum.join(description_words, " ")
      {:ok, player} = Exedra.User.get(username)
      case Integer.parse(name_or_id) do
        {id, _} ->
          if MapSet.member?(player.items, id) do
            {:ok, item} = Exedra.Item.get(id)
            Exedra.Item.set %{item | description: description}
            IO.puts "A vision of " <> item.brief <> " on the ground flashes in your mind's eye."
          else
            IO.puts "You aren't carrying that."
          end
        :error ->
          name = name_or_id
          item_id = Enum.find player.items, fn(item_id) ->
            {:ok, item} = Exedra.Item.get(item_id)
            item.name == name
          end
          if item_id == nil do
            IO.puts "You are not carrying that."
          else
            {:ok, item} = Exedra.Item.get(item_id)
            Exedra.Item.set %{item | description: description}
            IO.puts "A vision of " <> item.brief <> " on the ground flashes in your mind's eye."
          end
      end
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
  # TODO: prevent dropping items which haven't had description or room_description set
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

  # TODO: prevent moving from rooms without descriptions, and auto-move to on creation.
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
