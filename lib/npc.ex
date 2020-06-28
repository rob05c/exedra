defmodule Exedra.NPC do
  require Logger

  @data_file "data/npcs"

  defmodule Data do
    @enforce_keys [:id, :name, :brief]
    # name elf
    # brief a stately elf
    # description is a paragraph
    # room_description A stately elf patrols the area diligently.
    # dead_description An elf lies on the ground in a pool of blood, no longer stately.
    # exit_description A stately elf leaves to the $dir
    # entry_description A stately elf enters from the $dir
    # plural_brief elves
    defstruct id:                0,
      name:              "",
      brief:             "",
      description:       "",
      room_description:  "",
      dead_description:  "",
      exit_description:  "",
      entry_description: "",
      plural_brief:      "",
      currency:          0,
      items:             MapSet.new, # set<item_id>
      actors:            [],  # [NPCActor]
      actor_data:        %{}, # map<actor.name(), data>
      events:            [],  # [Exedra.NPC.Eventor]
      event_data:        %{}, # map<hook.name(), data>
      room_id:           -1
  end

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_charlist(@data_file)) do
      {:ok, :npcs} ->
        IO.puts "NPCs file loaded"
        :ok
      {:error, _} ->
        IO.puts "NPCs file didn't exist, creating new table"
        :npcs = :ets.new(:npcs, [:named_table, :set, :public])
    end
    :ok
  end

  def create(player, name, brief) do
    next_id = :ets.update_counter(:npcs, :next_id, 1, {1,0})
    new_npc = %Exedra.NPC.Data{id: next_id, name: name, brief: brief}
    :ets.insert_new(:npcs, {next_id, new_npc})

    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:npcs, String.to_charlist(@data_file), sync: true)

    Exedra.User.set(%{player | npcs: MapSet.put(player.npcs, new_npc.id)})

    new_npc
  end

  def pickup(npc_id, room, player) do
    {:ok, npc} = Exedra.NPC.get npc_id
    Exedra.Room.set(%{room | npcs: MapSet.delete(room.npcs, npc_id)})
    Exedra.User.set(%{player | npcs: MapSet.put(player.npcs, npc_id)})
    Exedra.NPC.set(%{npc | room_id: -1})
  end

  def drop(npc_id, room, player) do
    Logger.info "NPC.drop"
    {:ok, npc} = Exedra.NPC.get npc_id
    Exedra.User.set(%{player | npcs: MapSet.delete(player.npcs, npc_id)})
    Exedra.Room.set(%{room | npcs: MapSet.put(room.npcs, npc_id)})
    Exedra.NPC.set(%{npc | room_id: room.id})
  end

  @doc """
  Moves the npc to the given room_id.
  MUST NOT be used to drop from a player's inventory. Use drop instead.
  MUST only be used to move from one room to another.
  """
  def move(npc_id, room_id) do
    {:ok, npc} = Exedra.NPC.get npc_id
    {:ok, old_room} = Exedra.Room.get npc.room_id
    {:ok, room} = Exedra.Room.get room_id
    Exedra.Room.set(%{old_room | npcs: MapSet.delete(room.npcs, npc_id)})
    Exedra.Room.set(%{room | npcs: MapSet.put(room.npcs, npc_id)})
    Exedra.NPC.set(%{npc | room_id: room.id})
  end

  def get(id) do
    case :ets.lookup(:npcs, id) do
      [{_, ets_npc}] ->
        # if the struct was modified after it was saved, it won't match. So we need to cast it
        # to the latest Exedra.NPC.Data struct. Otherwise we'll get 'key not found' errors.
        npc = struct(Exedra.NPC.Data, Map.from_struct(ets_npc))
        {:ok, npc}
      [] ->
        :error
    end
  end

  @doc """
  Returns a list of all NPC ids
  """
  @spec all() :: [integer]
  def all() do
    # TODO benchmark, cache for speed?
    id = :ets.first(:npcs)
    if id == :"$end_of_table" do
      # Logger.info "all first is end, returning []"
      []
    else
      ids = if is_integer(id) do # skip counter atoms
        [id]
      else
        []
      end
      ids = all_next(ids, id)
      ids
    end
  end

  def all_next(acc, id) do
    # Logger.info "all_next id" <> to_string(id)
    id = :ets.next(:npcs, id)
    # Logger.info "all_next got id" <> to_string(id)
    if id == :"$end_of_table" do
      acc
    else
      acc = if is_integer(id) do # skip counter atoms
        [id | acc]
      else
        acc
      end
      all_next(acc, id)
    end
  end

  def set(npc) do
    :ets.insert(:npcs, {npc.id, npc})

    # debug - writing all users to disk every time someone moves doesn't scale.
    :ets.tab2file(:npcs, String.to_charlist(@data_file), sync: true)
  end

  #TODO deduplicate with Item.find_in

  @doc """
  Finds the npc name or id in the given set of IDs.
  Returns the npc, or nil.
  """
  @spec find_in(String.t, MapSet.t) :: Exedra.NPC.Data | nil
  def find_in(name_or_id, ids) do
    # TODO change to return {:ok, NPC.t} | :error ??
    case Integer.parse(name_or_id) do
      {id, _} ->
        find_id_in(id, ids)
      :error ->
        find_name_in(name_or_id, ids)
    end
  end

  @doc """
  Finds the npc id in the given set of IDs.
  Returns the npc, or nil.
  """
  @spec find_id_in(integer, MapSet.t) :: Exedra.NPC.Data | nil
  def find_id_in(id, ids) do
    if MapSet.member?(ids, id) do
      {:ok, npc} = Exedra.NPC.get(id)
      npc
    else
      nil
    end
  end

  @doc """
  Finds the npc name in the given set of IDs.
  Returns the npc, or nil.
  """
  @spec find_name_in(String.t, MapSet.t) :: Exedra.NPC.Data | nil
  def find_name_in(name, ids) do
    id = Enum.find ids, fn(id) ->
      {:ok, npc} = Exedra.NPC.get(id) # TODO avoid multiple gets
      npc.name == name # TODO fuzzy match?
    end
    find_id_in(id, ids)
  end

  def npc_not_here_msg(), do: "Nobody like that is here."

  @doc """
  Handles an inspectnpc call from the player.
  Returns the NPC inspect text, or a not-found message.
  """
  @spec do_inspect_npc(String.t, String.t) :: String.t
  def do_inspect_npc(player_name, npc_name_or_id) do
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    npc_or_nil = Exedra.NPC.find_in npc_name_or_id, room.npcs
    if npc_or_nil == nil do
      npc_not_here_msg()
    else
      Exedra.NPC.inspect npc_or_nil
    end
  end

  @doc """
  Handles an inspectnpc call from the player.
  Returns the NPC inspect text, or a not-found message.
  """
  @spec inspect(Exedra.NPC.Data) :: String.t
  def inspect(npc) do
    msg = """
Name:  #{npc.name}
Brief: #{npc.brief}
Description: #{npc.description}
Room Description: #{npc.room_description}
Dead Description: #{npc.dead_description}
Exit Description: #{npc.exit_description}
Entry Description: #{npc.entry_description}
Plural Brief: #{npc.plural_brief}
Currency: #{npc.currency}
Room ID: #{npc.room_id}
"""
    items_msg = npc.items
    |> Enum.map(fn(item_id) ->
      {:ok, item} = Exedra.Item.get item_id
      "  #{item.id} #{item.brief}"
    end)
    |> Enum.join("\n")
    msg = msg <> "Items:\n" <> items_msg

    actors_msg = npc.actors
    |> Enum.map(fn(actor_module) ->
      name = actor_module.name()
      "  #{name}"
    end)
    |> Enum.join("\n")
    msg = msg <> "Actors:\n" <> actors_msg

    msg
  end

  @doc """
  Handles an addnpcaction call from the player.
  Returns the text to show the player.
  """
  @spec do_add_action(String.t, [String.t]) :: String.t
  def do_add_action(player_name, args) do
    npc_name_or_id = Enum.at args, 0
    action_name = Enum.at args, 1
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)

    npc_or_nil = find_in(npc_name_or_id, room.npcs)
    if npc_or_nil == nil do
      "Nobody by that name is here"
    else
      add_action_by_name npc_or_nil, action_name
    end
  end

  @doc """
  Adds the given action to the npc, if the action exists.
  Returns the text to show the player.
  """
  @spec add_action_by_name(String.t, String.t) :: String.t
  def add_action_by_name(npc, action_name) do
    cond do
      action_name == Exedra.NPCActor.Wander.name() ->
        add_action npc, Exedra.NPCActor.Wander
        npc.brief <> " will now " <> action_name <> "."
      true ->
        "No action by that name exists"
    end
  end

  @doc """
  Adds the given action to the npc.
  """
  @spec add_action(Exedra.NPC.Data, module) :: nil
  def add_action(npc, action) do
    Exedra.NPC.set(%{npc | actors: npc.actors ++ [action]})
  end

  @doc """
  Handles an addnpcevent call from the player.
  Returns the text to show the player.
  """
  @spec do_add_event(String.t, [String.t]) :: String.t
  def do_add_event(player_name, args) do
    npc_name_or_id = Enum.at args, 0
    event_name = Enum.at args, 1
    {:ok, player} = Exedra.User.get player_name
    {:ok, room} = Exedra.Room.get player.room_id

    npc_or_nil = find_in npc_name_or_id, room.npcs
    if npc_or_nil == nil do
      "Nobody by that name is here"
    else
      add_event_by_name npc_or_nil, event_name
    end
  end

  @doc """
  Adds the given event to the npc, if the event exists.
  Returns the text to show the player.
  """
  @spec add_event_by_name(String.t, String.t) :: String.t
  def add_event_by_name(npc, event_name) do
    cond do
      event_name == Exedra.NPC.Eventor.RepeatedEmote.name() ->
        add_event npc, Exedra.NPC.Eventor.RepeatedEmote
        npc.brief <> " will now " <> event_name <> "."
      true ->
        "No event by that name exists"
    end
  end

  @doc """
  Adds the given event to the npc.
  """
  @spec add_event(Exedra.NPC.Data, module) :: nil
  def add_event(npc, event) do
    Exedra.NPC.set(%{npc | events: npc.events ++ [event]})
  end
end
