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
  def execute(["createcurrency"   | args], username), do: create_currency(   username, args)
  def execute(["cc"               | args], username), do: create_currency(   username, args)

  def execute(["createnpc" | args], username), do: create_npc(username, args)
  def execute(["cn"        | args], username), do: create_npc(username, args)

  def execute(["get" | args], username), do: get_item(username, args)
  def execute(["g"   | args], username), do: get_item(username, args)

  def execute(["drop" | args], username), do: drop_item(username, args)
  def execute(["d"    | args], username), do: drop_item(username, args)

  def execute(["items" | _], username), do: items(username)
  def execute(["i"     | _], username), do: items(username)

  def execute(["say" | args], username), do: say(username, args)
  def execute(["'"   | args], username), do: say(username, args)

  def execute(["tell" | args], username), do: tell(username, args)

  def execute(["help" | _], _), do: help()
  def execute(["h" | _], _), do: help()
  def execute(["?" | _], _), do: help()

  def execute([""], _), do: nothing()
  def execute(_, _), do: unknown()

  def help() do
    msg = """
north                               n
east                                e
south                               s
northwest                           nw
northeast                           ne
southwest                           sw
southeast                           se

look                                l
quicklook                           ql
get              <id>               g
drop             <id>               d
items                               i
say              <text>             '
tell             <player> <text>

createroom       <dir>  <fragment>  cr
createitem       <id>   <fragment>  ci
describeitem     <id>   <paragraph> di
roomdescribeitem <id>   <sentence>  rdi
createnpc        <name> <fragment>  cn

help                                ?
"""
    IO.puts msg
  end

  def say(player_name, args) do
    say_color = Exedra.ANSI.colors[:cyan]
    reset_color = Exedra.ANSI.colors[:reset]

    said = Enum.join(args, " ")
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)

    others_msg = say_color <> String.capitalize(player_name) <> " says, \"" <> ensure_sentence(said) <> "\"" <> reset_color
    self_msg = say_color <> "You say, \"" <> ensure_sentence(said) <> "\"" <> reset_color
    Exedra.Room.message_players(room, player_name, self_msg, others_msg) # TODO add period logic
  end

  def tell_color(), do: Exedra.ANSI.colors[:yellow]
  def reset_color(), do: Exedra.ANSI.colors[:reset]
  def tell_no_such_player_msg(), do: tell_color() <> "Who do you want to tell?" <> reset_color()
  def tell_no_found_player_msg(name), do: tell_color() <> "You don't know anyone named \"" <> name <> "\"." <> reset_color()
  def tell_target_not_online_msg(), do: tell_color() <> "A wave of lonliness washes over you." <> reset_color()
  def tell_crazy_msg(text), do: tell_color() <> "You think to yourself, \"" <> ensure_sentence(text) <> "\"" <> reset_color()
  def tell_self_msg(target_player_name, said), do: tell_color() <> "You tell " <> String.capitalize(target_player_name) <> ", \"" <>  ensure_sentence(said) <> "\"" <> reset_color()
  def tell_other_msg(player_name, said), do: tell_color() <> String.capitalize(player_name) <> " tells you, \"" <>  ensure_sentence(said) <> "\"" <> reset_color()

  @spec tell(String.t, list(String.t)) :: :ok
  def tell(_, args) when length(args) < 2,                 do: IO.puts tell_no_such_player_msg()
  def tell(player_name, [player_name | said_words]),       do: IO.puts tell_crazy_msg(Enum.join(said_words, " "))
  def tell(player_name, [target_player_name | said_words]) do
    case Exedra.User.get(target_player_name) do
      {:ok, _} ->
        tell_user(player_name, target_player_name, said_words)
      _ ->
        IO.puts tell_no_found_player_msg(target_player_name)
    end
  end

  @spec tell_user(String.t, String.t, nonempty_list(String.t)) :: :ok
  def tell_user(player_name, target_player_name, said_words) do
    case Exedra.SessionManager.get(Exedra.SessionManager, target_player_name) do
      {:ok, msg_pid} ->
        tell_connected_user(player_name, target_player_name, said_words, msg_pid)
      :error ->
        IO.puts tell_target_not_online_msg()
    end
  end

  @spec tell_connected_user(String.t, String.t, nonempty_list(String.t), pid) :: :ok
  def tell_connected_user(player_name, target_player_name, said_words, target_pid) do
    said = Enum.join(said_words, " ")
    send target_pid, {:message, tell_other_msg(player_name, said)}
    IO.puts tell_self_msg(target_player_name, said)
  end

  def ensure_sentence(msg) do
    msg = case String.length(msg) do
            0 ->
              msg
            1 ->
              String.upcase(msg)
            _ ->
              {first_word, rest} = String.split_at(msg, 1)
              String.upcase(first_word) <> rest
          end
    if String.ends_with? msg, [".", "?", "!"] do
      msg
    else
      msg <> "."
    end
  end

  def currency_text_singular() do
    "gold coin"
  end

  def currency_text_plural() do
    "gold coins"
  end

  def currency_color() do
    Exedra.ANSI.colors[:yellow]
  end

  def items(username) do
    {:ok, player} = Exedra.User.get(username)
    # TODO: add "and" before final item.
    items = player.items
    |> Enum.map(fn(item_id) ->
      {:ok, item} = Exedra.Item.get(item_id)
      item.brief
    end)
    |> Enum.join(", ")

    npcs = player.npcs
    |> Enum.map(fn(npc_id) ->
      {:ok, npc} = Exedra.NPC.get(npc_id)
      npc.brief
    end)
    |> Enum.join(", ")

    msg = cond do
      String.length(items) > 0 && String.length(npcs) > 0 ->
        "You are holding: " <> items <> ", " <> npcs <> "."
      String.length(items) > 0 ->
        "You are holding: " <> items <> "."
      String.length(npcs) > 0 ->
        "You are holding: " <> npcs <> "."
      true ->
        "You are holding nothing."
    end

    msg = cond do
      player.currency == 1 ->
        msg <> "\n" <> currency_color() <> Integer.to_string(player.currency) <> " " <> currency_text_singular() <> Exedra.ANSI.colors[:reset]
      player.currency > 1 ->
        msg <> "\n" <> currency_color() <> Integer.to_string(player.currency) <> " " <> currency_text_plural() <> Exedra.ANSI.colors[:reset]
      true ->
        msg
    end

    IO.puts msg
  end

  def look(username) do
    {:ok, user} = Exedra.User.get(username)
    {:ok, room} = Exedra.Room.get(user.room_id)
    IO.puts Exedra.Room.print(room, false, username)
  end

  def quick_look(username) do
    {:ok, user} = Exedra.User.get(username)
    {:ok, room} = Exedra.Room.get(user.room_id)
    IO.puts Exedra.Room.print(room, true, username)
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

  def create_npc(username, args) do
    if length(args) < 2 do
      IO.puts "You must specify a name and brief description."
    else
      [name | description_list] = args
      brief_description = Enum.join(description_list, " ")
      {:ok, player} = Exedra.User.get(username)
      Exedra.NPC.create(player, name, brief_description)
      IO.puts "A " <> brief_description <> " forms in your hands."
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

  @spec create_currency(String.t, list(String.t)) :: :ok
  def create_currency(username, args) do
    if length(args) < 1 do
      IO.puts "You must specify a quantity."
    else
      num_str = List.first(args)

      case Integer.parse(num_str) do
        :error ->
          IO.puts "HOW many?"
        {num, _} ->
          {:ok, player} = Exedra.User.get(username)
          Exedra.User.set(%{player | currency: player.currency + num}) # TODO atomic/lock; race condition
          if num == 1 do
            IO.puts num_str <> " " <> currency_text_singular() <> " materializes in your hands."
          else
            IO.puts num_str <> " " <> currency_text_plural() <> " materialize in your hands."
          end
      end
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

  @doc """
  Get the requested currency from the room, if the command is of the form '(num|) currency_noun()', e.g. 'get coin' or 'get 10 gold'. Otherwise, the "that isn't here" message is sent.

  This should be called after get_item(), to give items priority. E.g. if the room has  "a special silver coin", "get coin" should get that first.

  Must be given a nonempty args list - get_item called before this should return if len(args)<1
  """
  @spec get_currency(String.t, nonempty_list(String.t)) :: :ok
  def get_currency(username, args) do
    # TODO: combine with get_item() to only call Integer.parse, User.get once.
    [num_or_noun|noun_rest] = args
    case Integer.parse(num_or_noun) do
      {num, _} ->
        if length(noun_rest) < 1 do
          IO.puts not_here_text()
        else
          noun = List.first(noun_rest)
          get_currency_noun_num(username, noun, num)
        end
      :error ->
        noun = num_or_noun
        get_currency_noun_num(username, noun, :all)
    end
  end

  @doc """
  Checks if the given noun is an alias for currency, and gets the requested amount, which may be :all
  """
  @spec get_currency_noun_num(String.t, String.t, pos_integer|:all) :: :ok
  def get_currency_noun_num(username, noun, num) do
    {:ok, player} = Exedra.User.get(username)
    {:ok, room} = Exedra.Room.get(player.room_id)
    if !MapSet.member?(currency_nouns(), noun) || room.currency == 0 do
      IO.puts not_here_text()
    else
      num = if num == :all || num > room.currency do
        room.currency
      else
        num
      end
      if num < 1 do
        IO.puts not_here_text()
      else
        # TODO atomic/lock; race condition
        Exedra.User.set %{player | currency: player.currency + num}
        Exedra.Room.set %{room | currency: room.currency - num}
        if num == 1 do
          IO.puts "You get a " <> currency_text_singular() <> "."
        else
          IO.puts "You get " <> Integer.to_string(num) <> " " <> currency_text_plural() <> "."
        end
      end
    end
  end

  # TODO use guards to reduce indentation
  def get_item(username, args) do
    if length(args) < 1 do
      IO.puts "What do you want to get?"
    else
      name_or_id = List.first(args)

      {:ok, player} = Exedra.User.get(username)
      {:ok, room} = Exedra.Room.get(player.room_id)

      case Integer.parse(name_or_id) do
        {id, _} ->
          cond do
            MapSet.member?(room.items, id) ->
              Exedra.Item.pickup(id, room, player)
              {:ok, item} = Exedra.Item.get(id)
              IO.puts "You pick up " <> item.brief <> "."
            MapSet.member?(room.npcs, id) ->
              {:ok, npc} = Exedra.NPC.get(id)
              # TODO: allow picking up NPCs with permissions
              # Exedra.NPC.pickup(id, room, player)
              # IO.puts "You pick up " <> item.brief <> "."
              IO.puts npc.brief <>  " stares at you awkwardly."
            true ->
              get_currency(username, args)
          end
        :error ->
          name = name_or_id
          item_id = Enum.find room.items, fn(item_id) ->
            {:ok, item} = Exedra.Item.get(item_id)
            item.name == name
          end
          if item_id == nil do
            npc_id = Enum.find room.npcs, fn(npc_id) ->
              {:ok, npc} = Exedra.NPC.get(npc_id)
              npc.name == name
            end
            if npc_id == nil do
              get_currency(username, args)
            else
              {:ok, npc} = Exedra.NPC.get(npc_id)
              # TODO: fix duplication with ID get above
              # TODO: allow picking up NPCs with permissions
              # Exedra.NPC.pickup(npc_id, room, player)
              IO.puts npc.brief <>  " eyes you suspiciously."
            end
          else
            Exedra.Item.pickup(item_id, room, player)
            {:ok, item} = Exedra.Item.get(item_id)
            IO.puts "You pick up " <> item.brief <> "."
          end
      end
    end
  end

  def currency_nouns(), do: MapSet.new(["currency","gold","coin"])
  def not_here_text(), do: "That isn't here."
  def not_enough_currency_text(), do: "You don't have that much coin."

  @doc """
  Drops the requested currency held, if the drop command is of the form 'drop (num|) currency_noun()', e.g. 'drop coin' or 'drop 10 gold'. Otherwise, the "you're not holding that" message is sent.

  This should be called after drop_item(), to give items priority. E.g. if a player has "a special silver coin", "drop coin" should drop that first.

  Must be given a nonempty args list - drop_item called before this should return if len(args)<1
  """
  @spec drop_currency(String.t, nonempty_list(String.t)) :: :ok
  def drop_currency(username, args) do
    # TODO: combine with drop_item() to only call Integer.parse, User.get once.
    [num_or_noun|noun_rest] = args
    case Integer.parse(num_or_noun) do
      {num, _} ->
        if length(noun_rest) < 1 do
          IO.puts not_here_text()
        else
          noun = List.first(noun_rest)
          drop_currency_num_noun(username, num, noun)
        end
      :error ->
        noun = num_or_noun
        drop_currency_num_noun(username, 1, noun)
    end
  end

  @doc """
  Checks if the given noun is an alias for currency, and drops the requested amount.
  """
  @spec drop_currency_num_noun(String.t, pos_integer, String.t) :: :ok
  def drop_currency_num_noun(username, num, noun) do
    if MapSet.member? currency_nouns(), noun do
      {:ok, player} = Exedra.User.get(username)
      if player.currency >= num do
        {:ok, room} = Exedra.Room.get(player.room_id)
        # TODO atomic/lock; race condition
        Exedra.Room.set %{room | currency: room.currency + num}
        Exedra.User.set %{player | currency: player.currency - num}
        if num == 1 do
          IO.puts "You drop a " <> currency_text_singular() <> "."
        else
          IO.puts "You drop " <> Integer.to_string(num) <> " " <> currency_text_plural() <> "."
        end
      else
        IO.puts not_enough_currency_text()
      end
    else
      IO.puts not_here_text()
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
          cond do
            MapSet.member?(player.items, id) ->
              {:ok, room} = Exedra.Room.get(player.room_id)
              Exedra.Item.drop(id, room, player)
              {:ok, item} = Exedra.Item.get(id)
              IO.puts "You drop " <> item.brief <> "."
            MapSet.member?(player.npcs, id) ->
              {:ok, npc} = Exedra.NPC.get(id)
              {:ok, room} = Exedra.Room.get(player.room_id)
              Exedra.NPC.drop(id, room, player)
              IO.puts "You set " <> npc.brief <> " down carefully."
            true ->
              drop_currency(username, args)
          end
        :error ->
          name = name_or_id
          item_id = Enum.find player.items, fn(item_id) ->
            {:ok, item} = Exedra.Item.get(item_id)
            item.name == name
          end
          if item_id == nil do
            npc_id = Enum.find player.npcs, fn(npc_id) ->
              {:ok, npc} = Exedra.NPC.get(npc_id)
              npc.name == name
            end
            if npc_id == nil do
              drop_currency(username, args)
            else
              {:ok, room} = Exedra.Room.get(player.room_id)
              Exedra.NPC.drop(npc_id, room, player)
              {:ok, npc} = Exedra.NPC.get(npc_id)
              IO.puts "You deposit " <> npc.brief <> " carefully."
            end
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
        {:ok, to_room} = Exedra.Room.get(to_room_id)

        # TODO lock. Like everything else.
        Exedra.Room.set(%{player_room | players: MapSet.delete(player_room.players, playername)})
        Exedra.Room.set(%{to_room | players: MapSet.put(to_room.players, playername)})
        Exedra.User.set(%{player | room_id: to_room_id})

        to_dir_str = Exedra.Room.dir_atom_to_string(direction)
        from_dir_str = Exedra.Room.dir_atom_to_string(Exedra.Room.reverse(direction))

        self_msg = "You meander " <> to_dir_str <> "."
        exit_msg = String.capitalize(playername) <> " meanders out to the " <> to_dir_str <> "."
        entry_msg = String.capitalize(playername) <> " meanders in from the " <> from_dir_str <> "."

        IO.puts self_msg
        Exedra.Room.message_players(player_room, playername, "", exit_msg)
        Exedra.Room.message_players(to_room, playername, "", entry_msg)
        IO.puts Exedra.Room.print(to_room, false, playername)
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
