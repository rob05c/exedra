defmodule Exedra.WorldManager do
@moduledoc """
WorldManager is used to synchronize access to multiple data.
Data must always be synchronized. While not a memory race, it's a logical race.

For example, if a player leaves a room at the same time a mob attacks them, we don't want the mob to get the player, the player leaves the room, and then the player gets the message that they've been attacked.
Hence, getting data and completing an action (like leaving a room, or attacking) must be atomic.

The WorldManager is used for those atomic actions. All things that require more than 1 piece of data must be executed thru the WorldManager.

This could be optimized in the future, e.g. we could only "lock" the rooms involved in the action.
"""

  use GenServer
  require Logger

  # defmodule Data do
  #   @enforce_keys [:user, :pid]
  #   defstruct user: "",
  #             pid:  0
  # end

  def pickup_item_by_id(server, user_name, item_id, args) do
    GenServer.call server, {:pickup_item_by_id, user_name, item_id, args}
  end

  def pickup_item_by_name(server, user_name, item_name, args) do
    GenServer.call server, {:pickup_item_by_name, user_name, item_name, args}
  end

  def drop_item(server, player_name, args) do
    GenServer.call server, {:drop_item, player_name, args}
  end

  def move(server, player_name, direction) do
    GenServer.call server, {:move, player_name, direction}
  end

  def create_currency(server, player_name, args) do
    GenServer.call server, {:create_currency, player_name, args}
  end

  def create_item(server, player_name, args) do
    GenServer.call server, {:create_item, player_name, args}
  end

  def create_npc(server, player_name, args) do
    GenServer.call server, {:create_npc, player_name, args}
  end

  def create_room(server, player_name, args) do
    GenServer.call server, {:create_room, player_name, args}
  end

  def quick_look(server, player_name) do
    GenServer.call server, {:quick_look, player_name}
  end

  def look(server, player_name) do
    GenServer.call server, {:look, player_name}
  end

  def items(server, player_name) do
    GenServer.call server, {:items, player_name}
  end

  def item_info(server, player_name) do
    GenServer.call server, {:item_info, player_name}
  end

  def item_here(server, player_name) do
    GenServer.call server, {:item_here, player_name}
  end

  def say(server, player_name, args) do
    GenServer.call server, {:say, player_name, args}
  end

  def tell(server, player_name, target_player_name, said_words) do
    GenServer.call server, {:tell, player_name, target_player_name, said_words}
  end

  def room_describe_item_by_id(server, player_name, room_description, id) do
    GenServer.call server, {:room_describe_item_by_id, player_name, room_description, id}
  end

  def room_describe_item_by_name(server, player_name, room_description, name) do
    GenServer.call server, {:room_describe_item_by_name, player_name, room_description, name}
  end

  def describe_item_by_id(server, player_name, description, id) do
    GenServer.call server, {:describe_item_by_id, player_name, description, id}
  end

  def describe_item_by_name(server, player_name, description, name) do
    GenServer.call server, {:describe_item_by_name, player_name, description, name}
  end

  # @spec set(GenServer.server, String.t, pid) :: :ok
  # def set(server, user, pid) do
  #   GenServer.cast server, {:set, user, pid}
  # end

  # @spec delete(GenServer.server, String.t) :: :ok
  # def delete(server, user) do
  #   GenServer.cast server, {:delete, user}
  # end


  @spec init([]) :: {:ok, %{}}
  def init([]) do
    {:ok,  %{}}
  end

  # # @spec start_link(String.t) :: GenServer.on_start
  # @spec start_link(atom | {:global, any} | {:via, atom, any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(name) do
    GenServer.start_link __MODULE__, [], name: name
  end

  # def start_link(opts) do
  #   GenServer.start_link(__MODULE__, :ok, opts)
  # end

  def handle_call({:pickup_item_by_id, user_name, item_id, args}, _from, state) do
    # TODO pipeline
    {:ok, player} = Exedra.User.get(user_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    reply_str = get_item_by_id(player, room, item_id, args)
    # Logger.error "get_item_by_id reply '" <> reply_str <> "'"
    {:reply, {:ok, reply_str}, state}
  end

  def handle_call({:pickup_item_by_name, user_name, item_name, args}, _from, state) do
    # TODO pipeline
    {:ok, player} = Exedra.User.get(user_name)
    {:ok, room} = Exedra.Room.get(player.room_id)
    reply_str = get_item_by_name(player, room, item_name, args)
    # Logger.error "get_item_by_name reply '" <> reply_str <> "'"
    {:reply, {:ok, reply_str}, state}
  end

  def handle_call({:move, player_name, direction}, _from, state) do
    # TODO: prevent moving from rooms without descriptions, and auto-move to on creation.
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, player_room} = Exedra.Room.get(player.room_id)
    player_msg =
      case Map.fetch(player_room.exits, direction) do
        {:ok, to_room_id} ->
          {:ok, to_room} = Exedra.Room.get(to_room_id)

          Exedra.Room.set(%{player_room | players: MapSet.delete(player_room.players, player_name)})
          Exedra.Room.set(%{to_room | players: MapSet.put(to_room.players, player_name)})
          Exedra.User.set(%{player | room_id: to_room_id})

          to_dir_str = Exedra.Room.dir_atom_to_string(direction)
          from_dir_str = Exedra.Room.dir_atom_to_string(Exedra.Room.reverse(direction))

          self_msg = "You meander " <> to_dir_str <> "."
          exit_msg = String.capitalize(player_name) <> " meanders out to the " <> to_dir_str <> "."
          entry_msg = String.capitalize(player_name) <> " meanders in from the " <> from_dir_str <> "."

          Exedra.Room.message_players(player_room, player_name, "", exit_msg)
          Exedra.Room.message_players(to_room, player_name, "", entry_msg)

          self_msg <> "\n" <> Exedra.Room.print(to_room, false, player_name)
        :error ->
          "There is no exit in that direction."
      end
    {:reply, player_msg, state}
  end

  def handle_call({:drop_item, player_name, args}, _from, state) do
    # TODO: abstract duplication with get_item
    # TODO: prevent dropping items which haven't had description or room_description set
    player_msg =
    if length(args) < 1 do
      "What do you want to drop?"
    else
      name_or_id = List.first(args)
      {:ok, player} = Exedra.User.get(player_name)
      case Integer.parse(name_or_id) do
        {id, _} ->
          cond do
            MapSet.member?(player.items, id) ->
              {:ok, room} = Exedra.Room.get(player.room_id)
              Exedra.Item.drop(id, room, player)
              {:ok, item} = Exedra.Item.get(id)
              "You drop " <> item.brief <> "."
            MapSet.member?(player.npcs, id) ->
              {:ok, npc} = Exedra.NPC.get(id)
              {:ok, room} = Exedra.Room.get(player.room_id)
              Exedra.NPC.drop(id, room, player)
              "You set " <> npc.brief <> " down carefully."
            true ->
              drop_currency(player_name, args)
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
              drop_currency(player_name, args)
            else
              {:ok, room} = Exedra.Room.get(player.room_id)
              Exedra.NPC.drop(npc_id, room, player)
              {:ok, npc} = Exedra.NPC.get(npc_id)
              "You deposit " <> npc.brief <> " carefully."
            end
          else
            {:ok, room} = Exedra.Room.get(player.room_id)
            Exedra.Item.drop(item_id, room, player)
            {:ok, item} = Exedra.Item.get(item_id)
            "You drop " <> item.brief <> "."
          end
      end
    end
    {:reply, player_msg, state}
  end

  def handle_call({:create_currency, player_name, args}, _from, state) do
    num_str = List.first(args)
    player_msg =
      case Integer.parse(num_str) do
        :error ->
          create_currency_no_num_str()
      {num, _} ->
        {:ok, player} = Exedra.User.get(player_name)
        Exedra.User.set(%{player | currency: player.currency + num})
        create_currency_msg(num_str)
      end
    {:reply, player_msg, state}
  end

  def handle_call({:create_item, player_name, args}, _from, state) do
    [name | description_list] = args
    brief_description = Enum.join(description_list, " ")
    {:ok, player} = Exedra.User.get(player_name)
    Exedra.Item.create(player, name, brief_description)
    player_msg = create_msg(brief_description)
    {:reply, player_msg, state}
  end

  def handle_call({:create_npc, player_name, args}, _from, state) do
    [name | description_list] = args
    brief_description = Enum.join(description_list, " ")
    {:ok, player} = Exedra.User.get(player_name)
    Exedra.NPC.create(player, name, brief_description)
    player_msg = create_msg(brief_description)
    {:reply, player_msg, state}
  end

  def handle_call({:create_room, player_name, args}, _from, state) do
    player_msg = if length(args) < 2 do
      "You must specify a direction and room name."
    else
      [direction_string | name_list] = args
      room_name = Enum.join(name_list, " ")
      direction = Exedra.Room.dir_string_to_atom(direction_string)
      if direction == :invalid do
        "That's not a valid direction."
      else
        {:ok, player} = Exedra.User.get(player_name)
        {:ok, player_room} = Exedra.Room.get(player.room_id)
        Exedra.Room.create_dir(player_room, direction, room_name, "")
        "The mist parts in the " <> Exedra.Room.dir_atom_to_string(direction) <> "."
      end
    end
    {:reply, player_msg, state}
  end

  def handle_call({:quick_look, player_name}, _from, state) do
    {:ok, user} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(user.room_id)
    msg = Exedra.Room.print(room, true, player_name)
    {:reply, msg, state}
  end

  def handle_call({:look, player_name}, _from, state) do
    {:ok, user} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(user.room_id)
    msg = Exedra.Room.print(room, false, player_name)
    {:reply, msg, state}
  end

  def handle_call({:items, player_name}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
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

    {:reply, msg, state}
  end

  def handle_call({:item_info, player_name}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
    # TODO: add "and" before final item.
    items = player.items
    |> Enum.map(fn(item_id) ->
      {:ok, item} = Exedra.Item.get(item_id)
      "\t" <> Integer.to_string(item.id) <> "\t" <> item.brief
    end)
    |> Enum.join("\n")

    npcs = player.npcs
    |> Enum.map(fn(npc_id) ->
      {:ok, npc} = Exedra.NPC.get(npc_id)
      npc.id <> "\t" <> npc.brief
    end)
    |> Enum.join("\n")

    msg = cond do
      String.length(items) > 0 && String.length(npcs) > 0 ->
        "You are holding: \n" <> items <> ", " <> npcs <> "."
      String.length(items) > 0 ->
        "You are holding: \n" <> items <> "."
      String.length(npcs) > 0 ->
        "You are holding: \n" <> npcs <> "."
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

    {:reply, msg, state}
  end

  def handle_call({:item_here, player_name}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
    # TODO: add "and" before final item.
    {:ok, room} = Exedra.Room.get(player.room_id)
    # TODO deduplicate with info_here
    items = room.items
    |> Enum.map(fn(item_id) ->
      {:ok, item} = Exedra.Item.get(item_id)
      "\t" <> Integer.to_string(item.id) <> "\t" <> item.brief
    end)
    |> Enum.join("\n")

    npcs = player.npcs
    |> Enum.map(fn(npc_id) ->
      {:ok, npc} = Exedra.NPC.get(npc_id)
      npc.id <> "\t" <> npc.brief
    end)
    |> Enum.join("\n")

    msg = cond do
      String.length(items) > 0 && String.length(npcs) > 0 ->
        "You see: \n" <> items <> "\n" <> npcs <> "."
      String.length(items) > 0 ->
        "You see: \n" <> items
      String.length(npcs) > 0 ->
        "You see: \n" <> npcs
      true ->
        "You see nothing."
    end

    msg = cond do
      player.currency == 1 ->
        msg <> "\n" <> currency_color() <> Integer.to_string(player.currency) <> " " <> currency_text_singular() <> Exedra.ANSI.colors[:reset]
      player.currency > 1 ->
        msg <> "\n" <> currency_color() <> Integer.to_string(player.currency) <> " " <> currency_text_plural() <> Exedra.ANSI.colors[:reset]
      true ->
        msg
    end

    {:reply, msg, state}
  end

  def handle_call({:say, player_name, args}, _from, state) do
    say_color = Exedra.ANSI.colors[:cyan]
    reset_color = Exedra.ANSI.colors[:reset]

    said = Enum.join(args, " ")
    {:ok, player} = Exedra.User.get(player_name)
    {:ok, room} = Exedra.Room.get(player.room_id)

    others_msg = say_color <> String.capitalize(player_name) <> " says, \"" <> ensure_sentence(said) <> "\"" <> reset_color
    self_msg = say_color <> "You say, \"" <> ensure_sentence(said) <> "\"" <> reset_color
    Exedra.Room.message_players(room, player_name, self_msg, others_msg) # TODO add period logic
    {:reply, self_msg, state}
  end

  def handle_call({:tell, player_name, target_player_name, said_words}, _from, state) do
    self_msg =
      case Exedra.User.get(target_player_name) do
        {:ok, _} ->
          tell_user(player_name, target_player_name, said_words)
        _ ->
          tell_no_found_player_msg(target_player_name)
      end
    {:reply, self_msg, state}
  end

  def handle_call({:room_describe_item_by_id, player_name, room_description, id}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
    self_msg =
    if MapSet.member?(player.items, id) do
      {:ok, item} = Exedra.Item.get(id)
      Exedra.Item.set %{item | room_description: room_description}
      room_describe_item_describe_msg(item.brief)
    else
      describe_item_no_item_msg()
    end
    {:reply, self_msg, state}
  end

  def handle_call({:room_describe_item_by_name, player_name, room_description, name}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
    item_id = Enum.find player.items, fn(item_id) ->
      {:ok, item} = Exedra.Item.get(item_id)
      item.name == name
    end
    self_msg = if item_id == nil do
      describe_item_no_item_msg()
    else
      {:ok, item} = Exedra.Item.get(item_id)
      Exedra.Item.set %{item | room_description: room_description}
      room_describe_item_describe_msg(item.brief)
    end
    {:reply, self_msg, state}
  end

  def handle_call({:describe_item_by_id, player_name, description, id}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
    self_msg = if MapSet.member?(player.items, id) do
      {:ok, item} = Exedra.Item.get(id)
      Exedra.Item.set %{item | description: description}
      describe_item_describe_msg(item.brief)
    else
      describe_item_no_item_msg()
    end
    {:reply, self_msg, state}
  end

  def handle_call({:describe_item_by_name, player_name, description, name}, _from, state) do
    {:ok, player} = Exedra.User.get(player_name)
    item_id = Enum.find player.items, fn(item_id) ->
      {:ok, item} = Exedra.Item.get(item_id)
      item.name == name
    end
    self_msg = if item_id == nil do
      describe_item_no_item_msg()
    else
      {:ok, item} = Exedra.Item.get(item_id)
      Exedra.Item.set %{item | description: description}
      describe_item_describe_msg(item.brief)
    end
    {:reply, self_msg, state}
  end

  def describe_item_no_item_msg(),   do: "You are not carrying that."
  def room_describe_item_describe_msg(brief),  do: "A vision of " <> brief <> " on the ground flashes in your mind's eye."
  def describe_item_describe_msg(brief),  do: "A vision of " <> brief <> " flashes in your mind's eye."

  @spec tell_user(String.t, String.t, nonempty_list(String.t)) :: :ok
  def tell_user(player_name, target_player_name, said_words) do
    case Exedra.SessionManager.get(Exedra.SessionManager, target_player_name) do
      {:ok, msg_pid} ->
        tell_connected_user(player_name, target_player_name, said_words, msg_pid)
      :error ->
        tell_target_not_online_msg()
    end
  end

  def tell_target_not_online_msg(), do: tell_color() <> "A wave of lonliness washes over you." <> reset_color()
  def tell_no_found_player_msg(name), do: tell_color() <> "You don't know anyone named \"" <> name <> "\"." <> reset_color()
  def tell_color(), do: Exedra.ANSI.colors[:yellow] # TODO deduplicate in commands
  def reset_color(), do: Exedra.ANSI.colors[:reset] # TODO deduplicate in commands

  # @spec tell_connected_user(String.t, String.t, nonempty_list(String.t), pid) :: :ok
  def tell_connected_user(player_name, target_player_name, said_words, target_pid) do
    said = Enum.join(said_words, " ")
    send target_pid, {:message, tell_other_msg(player_name, said)}
    tell_self_msg(target_player_name, said)
  end
  def tell_self_msg(target_player_name, said), do: tell_color() <> "You tell " <> String.capitalize(target_player_name) <> ", \"" <>  ensure_sentence(said) <> "\"" <> reset_color()
  def tell_other_msg(player_name, said), do: tell_color() <> String.capitalize(player_name) <> " tells you, \"" <>  ensure_sentence(said) <> "\"" <> reset_color()

  def ensure_sentence(msg) do # TODO deduplicate in commands
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

  def create_currency_msg(num_str) do
    if num_str == "1" do
      num_str <> " " <> currency_text_singular() <> " materializes in your hands."
    else
      num_str <> " " <> currency_text_plural() <> " materialize in your hands."
    end
  end

  def create_currency_no_num_str(), do: "HOW many?"

  def create_msg(brief_description), do: "A " <> brief_description <> " forms in your hands."

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

  def not_enough_currency_text(), do: "You don't have that much coin."

  # @spec handle_cast({:set, String.t, pid}, %{}) :: {:noreply, %{}}
  # def handle_cast({:set, user, pid}, data) do
  #   data = Map.put data, user, pid
  #   {:noreply, data}
  # end

  # @spec handle_cast({:delete, String.t}, %{}) :: {:noreply, %{}}
  # def handle_cast({:delete, user}, data) do
  #   data = Map.delete(data, user)
  #   {:noreply, data}
  # end

  @spec get_item_by_id(Exedra.User.Data, Exedra.Room.Data, integer, list(String.t)) :: String.t
  def get_item_by_id(player, room, id, args) do
    cond do
      MapSet.member?(room.items, id) ->
        Exedra.Item.pickup(id, room, player)
        {:ok, item} = Exedra.Item.get(id)
        get_item_msg(item.brief)
      MapSet.member?(room.npcs, id) ->
        {:ok, npc} = Exedra.NPC.get(id)
        # TODO: allow picking up NPCs with permissions
        # Exedra.NPC.pickup(id, room, player)
        # IO.puts "You pick up " <> item.brief <> "."
        get_npc_fail_msg(npc.brief)
      true ->
        get_currency(player, args)
    end
  end

  @spec get_item_by_name(Exedra.User.Data, Exedra.Room.Data, String.t, list(String.t)) :: String.t
  def get_item_by_name(player, room, name, args) do
    item_id = Enum.find room.items, fn(item_id) ->
      {:ok, item} = Exedra.Item.get(item_id)
      item.name == name
    end
    if item_id != nil do
      Exedra.Item.pickup(item_id, room, player)
      {:ok, item} = Exedra.Item.get(item_id)
      get_item_msg(item.brief)
    else
      get_npc_by_name(player, room, name, args)
    end
  end

  @spec get_currency(Exedra.User.Data, nonempty_list(String.t)) :: String.t
  def get_currency(player, args) do
    # TODO add room arg, since everything calling this has it? Or wait until Mnesia is added?
    # TODO: combine with get_item() to only call Integer.parse, User.get once.
    [num_or_noun|noun_rest] = args
    case Integer.parse(num_or_noun) do
      {num, _} ->
        get_currency_num(player, num, noun_rest)
      :error ->
        noun = num_or_noun
        get_currency_noun_num(player, noun, :all)
    end
  end

  @spec get_currency_num(Exedra.User.Data, integer, list(String.t)) :: String.t
  def get_currency_num(_, _, noun_rest) when length(noun_rest) < 1, do: not_here_text()
  def get_currency_num(player, num, noun_rest) do
    noun = List.first(noun_rest)
    get_currency_noun_num(player, noun, num)
  end

  @doc """
  Checks if the given noun is an alias for currency, and gets the requested amount, which may be :all
  """
  @spec get_currency_noun_num(Exedra.User.Data, String.t, pos_integer|:all) :: String.t
  def get_currency_noun_num(player, noun, num) do
    {:ok, room} = Exedra.Room.get(player.room_id)
    if !MapSet.member?(currency_nouns(), noun) || room.currency == 0 do
      not_here_text()
    else
      num = if num == :all || num > room.currency do
        room.currency
      else
        num
      end
      if num < 1 do
        not_here_text()
      else
        # TODO atomic/lock; race condition
        Exedra.User.set %{player | currency: player.currency + num}
        Exedra.Room.set %{room | currency: room.currency - num}
        if num == 1 do
          "You get a " <> currency_text_singular() <> "."
        else
          "You get " <> Integer.to_string(num) <> " " <> currency_text_plural() <> "."
        end
      end
    end
  end

  def not_here_text(), do: "That isn't here."
  def currency_nouns(), do: MapSet.new(["currency","gold","coin"])
  def currency_text_singular(), do: "gold coin"
  def currency_text_plural(),   do: "gold coins"
  def currency_color(),         do: Exedra.ANSI.colors[:yellow]

  @spec get_npc_by_name(Exedra.User.Data, Exedra.Room.Data, String.t, list(String.t)) :: :ok
  def get_npc_by_name(player, room, name, args) do
    npc_id = Enum.find room.npcs, fn(npc_id) ->
      {:ok, npc} = Exedra.NPC.get(npc_id)
      npc.name == name
    end
    if npc_id != nil do
      {:ok, npc} = Exedra.NPC.get(npc_id)
      # TODO: fix duplication with get_item_by_id
      # TODO: allow picking up NPCs with permissions
      # Exedra.NPC.pickup(npc_id, room, player)
      get_npc_fail_msg(npc.brief)
    else
      get_currency(player, args)
    end
  end

  def get_item_msg(brief), do: "You pick up " <> brief <> "."
  def get_npc_fail_msg(brief), do: brief <> " stares at you awkwardly." # TODO capitalise NPC name?
end
