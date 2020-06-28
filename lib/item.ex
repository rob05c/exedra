defmodule Exedra.Item do
  require Logger

  @data_file "data/items"

  # name is a single word, like 'sword' or 'feather'. This is the keyword used to issue commands like 'drop sword'.
  # brief is a noun clause, like 'a wooden sword' or 'a dull, blue orb'. This is what is seen in arbitrary locations, such as inventory and wielding.
  # description is a paragraph. This is what is seen when inspecting an item in detail, for example 'probe sword'.
  # room_description is a declarative sentence, complete with period.. It is what is seen when the item is on the ground. For example, 'a chipped wooden sword lies here, muddy with footprints.'
  @enforce_keys [:id, :name, :brief]
  defstruct id:               0,
    name:             "",
    brief:            "",
    description:      "",
    room_description: "",
    currency:         0

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_charlist(@data_file)) do
      {:ok, :items} ->
        IO.puts "Items file loaded"
        :ok
      {:error, _} ->
        IO.puts "Items file didn't exist, creating new table"
        :items = :ets.new(:items, [:named_table, :set, :public])
    end
    :ok
  end

  def create(player, name, brief) do
    next_id = :ets.update_counter(:items, :next_id, 1, {1,0})
    new_item = %Exedra.Item{id: next_id, name: name, brief: brief}
    :ets.insert_new(:items, {next_id, new_item})

    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:items, String.to_charlist(@data_file), sync: true)

    Exedra.Player.set(%{player | items: MapSet.put(player.items, new_item.id)})

    new_item
  end

  def pickup(item_id, room, player) do
    Exedra.Room.set(%{room | items: MapSet.delete(room.items, item_id)})
    Exedra.Player.set(%{player | items: MapSet.put(player.items, item_id)})
  end

  def drop(item_id, room, player) do
    Exedra.Player.set(%{player | items: MapSet.delete(player.items, item_id)})
    Exedra.Room.set(%{room | items: MapSet.put(room.items, item_id)})
  end

  def give_npc(item_id, player, npc) do
    Exedra.Player.set(%{player | items: MapSet.delete(player.items, item_id)})
    Exedra.NPC.set(%{npc | items: MapSet.put(npc.items, item_id)})
  end

  def give_player(item_id, player_from, player_to) do
    Exedra.Player.set(%{player_from | items: MapSet.delete(player_from.items, item_id)})
    Exedra.NPC.set(%{player_to | items: MapSet.put(player_to.items, item_id)})
  end

  def get(id) do
    case :ets.lookup(:items, id) do
      [{_, item}] ->
        {:ok, item}
      [] ->
        :error
    end
  end

  def set(item) do
    :ets.insert(:items, {item.id, item})

    # debug - writing all players to disk every time someone moves doesn't scale.
    :ets.tab2file(:items, String.to_charlist(@data_file), sync: true)
  end

  @doc """
  Finds the item name or id in the given set of IDs.
  Returns the item, or nil.
  """
  @spec find_in(String.t, MapSet.t) :: Exedra.Item | nil
  def find_in(name_or_id, ids) do
    # TODO change to return {:ok, Item} | :error ??
    case Integer.parse(name_or_id) do
      {id, _} ->
        find_id_in(id, ids)
      :error ->
        find_name_in(name_or_id, ids)
    end
  end

  @doc """
  Finds the item id in the given set of IDs.
  Returns the item, or nil.
  """
  @spec find_id_in(integer, MapSet.t) :: Exedra.Item | nil
  def find_id_in(id, ids) do
    if MapSet.member?(ids, id) do
      {:ok, item} = Exedra.Item.get(id)
      item
    else
      nil
    end
  end

  @doc """
  Finds the item name in the given set of IDs.
  Returns the item, or nil.
  """
  @spec find_name_in(String.t, MapSet.t) :: Exedra.Item | nil
  def find_name_in(name, ids) do
    id = Enum.find ids, fn(id) ->
      {:ok, item} = Exedra.Item.get(id) # TODO avoid multiple gets
      item.name == name # TODO fuzzy match?
    end
    find_id_in(id, ids)
  end

  @doc """
  do_give processes a give command from the player.
  Takes the player name, and the words they typed, and returns the response to send them.
  """
  @spec do_give(String.t, list(String.t)) :: String.t
  def do_give(player_name, args) do
    cond do
      length(args) < 1 ->
        "What do want to give?"
      length(args) < 2 || (length(args) > 2 && Enum.at(args, 1) != "to") ->
        "Who do you want to give to?"
      true ->
        Logger.info "Item.do_give zero '" <> Enum.at(args,0) <> " one '" <> Enum.at(args,1) <> "' two '" <> Enum.at(args, 2)

        # if they used the "give foo to bar" syntax, change it to "give foo bar"
        args = if length(args) > 2 && Enum.at(args, 1) == "to" do
          List.update_at(args, 1, fn(_) -> Enum.at(args, 2) end)
        else
          args
        end

        Logger.info "Item.do_give calling give_to '" <> Enum.at(args,0) <> "' and '" <> Enum.at(args,1)
        give_to player_name, Enum.at(args, 0), Enum.at(args, 1)
    end
  end

  @doc """
  give_to gives the item in the player's inventory to the target.
  The item may be the ID or name of an item in the player's inventory.
  The target may be the ID or name of an NPC or player in the same room.
  """
  @spec give_to(String.t, String.t, String.t) :: String.t
  def give_to(player_name, item_name_or_id, target_name_or_id) do
    {:ok, player} = Exedra.Player.get(player_name)
    Logger.info "Item.give_to calling find_in '" <> item_name_or_id <> "' in player.items"
    item_or_nil = find_in(item_name_or_id, player.items)
    if item_or_nil == nil do
      "You aren't carrying that."
    else
      give_item_to(player, item_or_nil, target_name_or_id)
    end
  end

  @doc """
  give_item_to gives the item in the player's inventory to the target.
  The target may be the ID or name of an NPC or player in the same room.
  """
  @spec give_item_to(Exedra.Player.t, Exedra.Item, String.t) :: String.t
  def give_item_to(player, item, target_name_or_id) do
    {:ok, room} = Exedra.Room.get(player.room_id)
    case Exedra.Room.find_npc_or_player_name_or_id(room, target_name_or_id) do
      {:npc, npc} ->
        give_item_to_npc player, item, npc
      {:player, other_player} ->
        give_item_to_player player, item, other_player
      :not_found ->
        "They aren't here."
    end
  end

  @doc """
  Gives the item in the player's inventory to the target player.
  """
  @spec give_item_to_player(Exedra.Player.t, Exedra.Item, Exedra.Player.t) :: String.t
  def give_item_to_player(player, item, target_player) do
    Exedra.Player.set(%{target_player | items: MapSet.put(target_player.items, item.id)})
    Exedra.Player.set(%{player | items: MapSet.delete(player.items, item.id)})
    # TODO message room? Stealth handing?
    Exedra.Player.message(target_player, player.name <> " gives you " <> item.brief <> ".")
    "You give " <> item.brief <> " to " <> target_player.name <> "."
  end

  @doc """
  Gives the item in the player's inventory to the npc.
  """
  @spec give_item_to_npc(Exedra.Player, Exedra.Item, Exedra.NPC) :: String.t
  def give_item_to_npc(player, item, npc) do
    Exedra.NPC.set(%{npc | items: MapSet.put(npc.items, item.id)})
    Exedra.Player.set(%{player | items: MapSet.delete(player.items, item.id)})
    "You give " <> item.brief <> " to " <> npc.brief <> "."
  end
end
