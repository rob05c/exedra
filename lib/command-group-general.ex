defmodule Exedra.CommandGroup.General do
  alias Exedra.CommandGroup, as: CommandGroup
  alias Exedra.WorldManager, as: WorldManager

  @behaviour CommandGroup

  @impl CommandGroup
  def exec(["north"     | _], player_name), do: move(player_name, :n)
  def exec(["n"         | _], player_name), do: move(player_name, :n)
  def exec(["east"      | _], player_name), do: move(player_name, :e)
  def exec(["e"         | _], player_name), do: move(player_name, :e)
  def exec(["south"     | _], player_name), do: move(player_name, :s)
  def exec(["s"         | _], player_name), do: move(player_name, :s)
  def exec(["west"      | _], player_name), do: move(player_name, :w)
  def exec(["w"         | _], player_name), do: move(player_name, :w)
  def exec(["northeast" | _], player_name), do: move(player_name, :ne)
  def exec(["ne"        | _], player_name), do: move(player_name, :ne)
  def exec(["northwest" | _], player_name), do: move(player_name, :nw)
  def exec(["nw"        | _], player_name), do: move(player_name, :nw)
  def exec(["southeast" | _], player_name), do: move(player_name, :se)
  def exec(["se"        | _], player_name), do: move(player_name, :se)
  def exec(["southwest" | _], player_name), do: move(player_name, :sw)
  def exec(["sw"        | _], player_name), do: move(player_name, :sw)
  def exec(["look"      | _], player_name), do: look(player_name)
  def exec(["l"         | _], player_name), do: look(player_name)
  def exec(["quicklook" | _], player_name), do: quick_look(player_name)
  def exec(["ql"        | _], player_name), do: quick_look(player_name)
  def exec(["get"    | args], playername), do: get_item(playername, args)
  def exec(["g"      | args], playername), do: get_item(playername, args)
  def exec(["drop"   | args], playername), do: drop_item(playername, args)
  def exec(["d"      | args], playername), do: drop_item(playername, args)
  def exec(["give"   | args], playername), do: give(playername, args)
  def exec(["items"     | _], playername), do: items(playername)
  def exec(["i"         | _], playername), do: items(playername)
  def exec(["ii"        | _], playername), do: item_info(playername)
  def exec(["iteminfo"  | _], playername), do: item_info(playername)
  def exec(["ih"        | _], playername), do: info_here(playername)
  def exec(["infohere"  | _], playername), do: info_here(playername)
  def exec(["say"    | args], playername), do: say(playername, args)
  def exec(["'"      | args], playername), do: say(playername, args)
  def exec(["tell"   | args], playername), do: tell(playername, args)
  def exec(["help"      | _], _), do: help()
  def exec(["h"         | _], _), do: help()
  def exec(["?"         | _], _), do: help()

  def exec([""], _), do: nothing()
  def exec(_, _), do: :unhandled

  def nothing() do
    ""
  end

  def help() do
    """
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
itemhere                            ih
say              <text>             '
tell             <player> <text>

createroom       <dir>  <fragment>  cr
createitem       <id>   <fragment>  ci
describeitem     <id>   <paragraph> di
roomdescribeitem <id>   <sentence>  rdi
createnpc        <name> <fragment>  cn

help                                ?
"""
  end

  def say(player_name, args) do
    GenServer.call WorldManager, {:say, player_name, args}
  end

  def tell_color(), do: Exedra.ANSI.colors[:yellow]
  def reset_color(), do: Exedra.ANSI.colors[:reset]


  @spec tell(String.t, list(String.t)) :: :ok
  def tell(_, args) when length(args) < 2,                 do: tell_no_such_player_msg()
  def tell(player_name, [player_name | said_words]),       do: tell_crazy_msg(Enum.join(said_words, " "))
  def tell(player_name, [target_player_name | said_words]) do
    GenServer.call WorldManager, {:tell, player_name, target_player_name, said_words}
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

  # TODO move currency and other text to their own module

  def currency_text_singular(), do: "gold coin"
  def currency_text_plural(),   do: "gold coins"
  def currency_color(),         do: Exedra.ANSI.colors[:yellow]

  def items(player_name) do
    GenServer.call WorldManager, {:items, player_name}
  end

  def item_info(player_name) do
    GenServer.call WorldManager, {:item_info, player_name}
  end

  def info_here(player_name) do
    GenServer.call WorldManager, {:info_here, player_name}
  end

  def look(player_name) do
    GenServer.call WorldManager, {:look, player_name}
  end

  def quick_look(player_name) do
    GenServer.call WorldManager, {:quick_look, player_name}
  end

  # TODO use guards to reduce indentation
  @spec get_item(String.t, list(String.t)) :: :ok
  def get_item(_, args) when length(args) < 1, do: "What do you want to get?"

  def get_item(player_name, args) do
    item_name_or_id = List.first(args)
    case Integer.parse(item_name_or_id) do
      {item_id, _} ->
        {:ok, reply_str} = GenServer.call WorldManager, {:pickup_item_by_id, player_name, item_id, args}
        reply_str
      :error ->
        {:ok, reply_str} = GenServer.call WorldManager, {:pickup_item_by_name, player_name, item_name_or_id, args}
        reply_str
    end
  end

  def get_item_msg(brief), do: "You pick up " <> brief <> "."
  def get_npc_fail_msg(brief), do: brief <> " stares at you awkwardly." # TODO capitalise NPC name?

  def currency_nouns(), do: MapSet.new(["currency","gold","coin"])

  def drop_item(player_name, args) do
    # TODO: abstract duplication with get_item
    # TODO: prevent dropping items which haven't had description or room_description set
    GenServer.call WorldManager, {:drop_item, player_name, args}
  end

  def give(player_name, args) do
    # TODO: prevent giving items which haven't had description or room_description set
    GenServer.call WorldManager, {:give, player_name, args}
  end

  def move(player_name, direction) do
    # TODO: prevent moving from rooms without descriptions, and auto-move to on creation.
    GenServer.call WorldManager, {:move, player_name, direction}
  end

end
