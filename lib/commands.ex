defmodule Exedra.Commands do
  require Logger
  alias Exedra.WorldManager, as: WorldManager

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

  def execute(["ii"       | _], username), do: item_info(username)
  def execute(["iteminfo" | _], username), do: item_info(username)

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
west                                w
northwest                           nw
northeast                           ne
southwest                           sw
southeast                           se

look                                l
quicklook                           ql
get              <id>               g
drop             <id>               d
items                               i
iteminfo                            ii
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
    IO.puts WorldManager.say(Exedra.WorldManager, player_name, args)
  end

  def tell_color(), do: Exedra.ANSI.colors[:yellow]
  def reset_color(), do: Exedra.ANSI.colors[:reset]


  @spec tell(String.t, list(String.t)) :: :ok
  def tell(_, args) when length(args) < 2,                 do: IO.puts tell_no_such_player_msg()
  def tell(player_name, [player_name | said_words]),       do: IO.puts tell_crazy_msg(Enum.join(said_words, " "))
  def tell(player_name, [target_player_name | said_words]) do
    IO.puts WorldManager.tell(Exedra.WorldManager, player_name, target_player_name, said_words)
  end
  def tell_no_such_player_msg(), do: tell_color() <> "Who do you want to tell?" <> reset_color()
  def tell_crazy_msg(text), do: tell_color() <> "You think to yourself, \"" <> ensure_sentence(text) <> "\"" <> reset_color()

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

  def currency_text_singular(), do: "gold coin"
  def currency_text_plural(),   do: "gold coins"
  def currency_color(),         do: Exedra.ANSI.colors[:yellow]

  def items(player_name) do
    IO.puts WorldManager.items(Exedra.WorldManager, player_name)
  end

  def item_info(player_name) do
    IO.puts WorldManager.item_info(Exedra.WorldManager, player_name)
  end

  def look(player_name) do
    IO.puts WorldManager.look(Exedra.WorldManager, player_name)
  end

  def quick_look(player_name) do
    IO.puts WorldManager.quick_look(Exedra.WorldManager, player_name)
  end

  def create_room(player_name, args) do
    IO.puts WorldManager.create_room(Exedra.WorldManager, player_name, args)
  end

  def create_no_name_desc_msg(), do: "You must specify a name and brief description."


  @spec create_npc(String.t, list(String.t)) :: :ok
  def create_npc(_, args) when length(args) < 2, do: IO.puts create_no_name_desc_msg()
  def create_npc(player_name, args) when length(args) >= 2 do
    IO.puts WorldManager.create_npc(Exedra.WorldManager, player_name, args)
  end

  @spec create_item(String.t, list(String.t)) :: :ok
  def create_item(_, args) when length(args) < 2, do: IO.puts create_no_name_desc_msg()
  def create_item(player_name, args) do
    IO.puts WorldManager.create_item(Exedra.WorldManager, player_name, args)
  end

  def create_currency_no_name_desc_msg(), do: "You must specify a quantity."

  @spec create_currency(String.t, list(String.t)) :: :ok
  def create_currency(_, args) when length(args) < 1, do: IO.puts create_currency_no_name_desc_msg()
  def create_currency(player_name, args) do
    IO.puts WorldManager.create_currency(Exedra.WorldManager, player_name, args)
  end

  def describe_item_too_short_msg(), do: "What do you want to describe?"

  @spec room_describe_item(String.t, list(String.t)) :: :ok
  def room_describe_item(_, args) when length(args) < 5, do: IO.puts describe_item_too_short_msg() # len(args) >= 5 because name_or_id is arg 1, and the minimal grammatically correct description is 'article noun verb adverb', e.g. 'the sword lies here'
  def room_describe_item(player_name, args) do
    [name_or_id | description_words] = args
    room_description = Enum.join(description_words, " ")
    case Integer.parse(name_or_id) do
      {id, _} ->
        room_describe_item_by_id(player_name, room_description, id)
      :error ->
        name = name_or_id
        room_describe_item_by_name(player_name, room_description, name)
    end
  end

  @spec room_describe_item_by_id(Exedra.User.Data, String.t, integer) :: :ok
  def room_describe_item_by_id(player_name, room_description, id) do
    IO.puts Exedra.WorldManager.room_describe_item_by_id(Exedra.WorldManager, player_name, room_description, id)
  end

  @spec room_describe_item_by_name(Exedra.User, String.t, String.t) :: :ok
  def room_describe_item_by_name(player_name, room_description, name) do
    IO.puts Exedra.WorldManager.room_describe_item_by_name(Exedra.WorldManager, player_name, room_description, name)
  end

  # TODO: abstract duplication with room_describe_item
  @spec describe_item(String.t, list(String.t)) :: :ok
  def describe_item(_, args) when length(args) < 5, do: IO.puts describe_item_too_short_msg() # len(args) >= 5 because name_or_id is arg 1, and the minimal grammatically correct description is 'article noun verb noun', e.g. 'the sword lies here'
  def describe_item(player_name, args) do
    [name_or_id | description_words] = args
    description = Enum.join(description_words, " ")
    case Integer.parse(name_or_id) do
      {id, _} ->
        describe_item_by_id(player_name, description, id)
      :error ->
        name = name_or_id
        describe_item_by_name(player_name, description, name)
    end
  end

  @spec describe_item_by_id(Exedra.User.Data, String.t, integer) :: :ok
  def describe_item_by_id(player_name, description, id) do
    IO.puts Exedra.WorldManager.describe_item_by_id(Exedra.WorldManager, player_name, description, id)
  end

  @spec describe_item_by_name(Exedra.User.Data, String.t, String.t) :: :ok
  def describe_item_by_name(player_name, description, name) do
    IO.puts Exedra.WorldManager.describe_item_by_name(Exedra.WorldManager, player_name, description, name)
  end

  # TODO use guards to reduce indentation
  @spec get_item(String.t, list(String.t)) :: :ok
  def get_item(_, args) when length(args) < 1, do: IO.puts "What do you want to get?"

  def get_item(user_name, args) do
    item_name_or_id = List.first(args)
    reply_str = case Integer.parse(item_name_or_id) do
                  {item_id, _} ->
                    # Logger.error "get_item id is " <> item_id
                   {:ok, reply_str} = Exedra.WorldManager.pickup_item_by_id(Exedra.WorldManager, user_name, item_id, args)
                   # Logger.error "get_item id '" <> item_id <> "' reply '" <> reply_str <> "'"
                   reply_str
                  :error ->
                    # Logger.error "get_item id is error "
                   item_name = item_name_or_id
                   {:ok, reply_str} = Exedra.WorldManager.pickup_item_by_name(Exedra.WorldManager, user_name, item_name, args)
                   reply_str
               end
    IO.puts reply_str
  end

  def get_item_msg(brief), do: "You pick up " <> brief <> "."
  def get_npc_fail_msg(brief), do: brief <> " stares at you awkwardly." # TODO capitalise NPC name?

  def currency_nouns(), do: MapSet.new(["currency","gold","coin"])

  def drop_item(player_name, args) do
    # TODO: abstract duplication with get_item
    # TODO: prevent dropping items which haven't had description or room_description set
    IO.puts Exedra.WorldManager.drop_item(Exedra.WorldManager, player_name, args)
  end

  def move(player_name, direction) do
    # TODO: prevent moving from rooms without descriptions, and auto-move to on creation.
    IO.puts WorldManager.move(Exedra.WorldManager, player_name, direction)
  end

  def unknown() do
    IO.puts "I don't understand."
  end

  def nothing() do
    nil
  end

end
