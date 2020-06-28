defmodule Exedra.CommandGroup.Admin do
  alias Exedra.CommandGroup, as: CommandGroup
  alias Exedra.WorldManager, as: WorldManager

  @behaviour CommandGroup

  @impl CommandGroup
  def exec(["createroom"       | args], player_name), do: create_room(       player_name, args)
  def exec(["cr"               | args], player_name), do: create_room(       player_name, args)
  def exec(["createitem"       | args], player_name), do: create_item(       player_name, args)
  def exec(["ci"               | args], player_name), do: create_item(       player_name, args)
  def exec(["describeitem"     | args], player_name), do: describe_item(     player_name, args)
  def exec(["di"               | args], player_name), do: describe_item(     player_name, args)
  def exec(["roomdescribeitem" | args], player_name), do: room_describe_item(player_name, args)
  def exec(["rdi"              | args], player_name), do: room_describe_item(player_name, args)
  def exec(["createcurrency"   | args], player_name), do: create_currency(   player_name, args)
  def exec(["cc"               | args], player_name), do: create_currency(   player_name, args)
  def exec(["createnpc"        | args], player_name), do: create_npc(        player_name, args)
  def exec(["cn"               | args], player_name), do: create_npc(        player_name, args)
  def exec(["inspectnpc"       | args], player_name), do: inspect_npc(       player_name, args)
  def exec(["inpc"             | args], player_name), do: inspect_npc(       player_name, args)
  def exec(["addnpcaction"     | args], player_name), do: add_npc_action(    player_name, args)
  def exec(["addnpcevent"      | args], player_name), do: add_npc_event(     player_name, args)

  def exec(_, _), do: :unhandled

  def create_room(player_name, args) do
    GenServer.call WorldManager, {:create_room, player_name, args}
  end

  def create_no_name_desc_msg(), do: "You must specify a name and brief description."

  @spec create_npc(String.t, list(String.t)) :: :ok
  def create_npc(_, args) when length(args) < 2, do: create_no_name_desc_msg()
  def create_npc(player_name, args) when length(args) >= 2 do
    GenServer.call WorldManager, {:create_npc, player_name, args}
  end

  def inspect_npc_no_name_desc_msg(), do: "Who do you want to inspect?"

  def inspect_npc(_, args) when length(args) < 1, do: inspect_npc_no_name_desc_msg()
  def inspect_npc(player_name, args) when length(args) >= 1 do
    GenServer.call WorldManager, {:inspect_npc, player_name, args}
  end

  def add_npc_action_no_npc_msg(), do: "Who do you want to add an action to?"
  def add_npc_action_no_action_msg(), do: "What action do you want to add?"

  def add_npc_action(_, args) when length(args) < 1, do: add_npc_action_no_npc_msg()
  def add_npc_action(_, args) when length(args) < 2, do: add_npc_action_no_action_msg()
  def add_npc_action(player_name, args) when length(args) >= 2 do
    GenServer.call WorldManager, {:add_npc_action, player_name, args}
  end

  def add_npc_event_no_npc_msg(), do: "Who do you want to add an event to?"
  def add_npc_event_no_event_msg(), do: "What event do you want to add?"

  def add_npc_event(_, args) when length(args) < 1, do: add_npc_event_no_npc_msg()
  def add_npc_event(_, args) when length(args) < 2, do: add_npc_event_no_event_msg()
  def add_npc_event(player_name, args) when length(args) >= 2 do
    GenServer.call WorldManager, {:add_npc_event, player_name, args}
  end

  @spec create_item(String.t, list(String.t)) :: :ok
  def create_item(_, args) when length(args) < 2, do: create_no_name_desc_msg()
  def create_item(player_name, args) do
    GenServer.call WorldManager, {:create_item, player_name, args}
  end

  def create_currency_no_name_desc_msg(), do: "You must specify a quantity."

  @spec create_currency(String.t, list(String.t)) :: :ok
  def create_currency(_, args) when length(args) < 1, do: create_currency_no_name_desc_msg()
  def create_currency(player_name, args) do
    GenServer.call WorldManager, {:create_currency, player_name, args}
  end

  def describe_item_too_short_msg(), do: "What do you want to describe?"

  @spec room_describe_item(String.t, list(String.t)) :: :ok
  def room_describe_item(_, args) when length(args) < 5, do: describe_item_too_short_msg() # len(args) >= 5 because name_or_id is arg 1, and the minimal grammatically correct description is 'article noun verb adverb', e.g. 'the sword lies here'
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

  @spec room_describe_item_by_id(Exedra.Player.t, String.t, integer) :: :ok
  def room_describe_item_by_id(player_name, room_description, id) do
    GenServer.call WorldManager, {:room_describe_item_by_id, player_name, room_description, id}
  end

  @spec room_describe_item_by_name(Exedra.Player, String.t, String.t) :: :ok
  def room_describe_item_by_name(player_name, room_description, name) do
    GenServer.call WorldManager, {:room_describe_item_by_name, player_name, room_description, name}
  end

  # TODO: abstract duplication with room_describe_item
  @spec describe_item(String.t, list(String.t)) :: :ok
  def describe_item(_, args) when length(args) < 5, do: describe_item_too_short_msg() # len(args) >= 5 because name_or_id is arg 1, and the minimal grammatically correct description is 'article noun verb noun', e.g. 'the sword lies here'
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

  @spec describe_item_by_id(Exedra.Player.t, String.t, integer) :: :ok
  def describe_item_by_id(player_name, description, id) do
    GenServer.call WorldManager, {:describe_item_by_id, player_name, description, id}
  end

  @spec describe_item_by_name(Exedra.Player.t, String.t, String.t) :: :ok
  def describe_item_by_name(player_name, description, name) do
    GenServer.call WorldManager, {:describe_item_by_name, player_name, description, name}
  end
end
