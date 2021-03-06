defmodule Exedra.Room do
  require Logger

  alias Exedra.ANSI, as: ANSI
  alias Exedra.Player, as: Player
  alias Exedra.CommandGroup.General, as: CommandGroupGeneral

  @data_file "data/rooms"

  @enforce_keys [:id, :title, :description]
  defstruct [
    id:          0,
    title:       "",
    description: "",
    exits:       %{},
    # container:   Container.t,
    items:       MapSet.new, # set<item_id>
    players:     MapSet.new, # set<player_name>
    npcs:        MapSet.new, # set<npc_id>
    currency:    0
  ]

  @room_zero %{
    title: "Primordial Fog",
    description: "A primordial fog permeates the area, obscuring all."
  }

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_charlist(@data_file)) do
      {:ok, :rooms} ->
        IO.puts "Rooms file loaded"
        :ok
      {:error, _} ->
        IO.puts "Rooms file didn't exist, creating new table"
        :rooms = :ets.new(:rooms, [:named_table, :set, :public])
        :ets.insert_new(:rooms, {0, %Exedra.Room{id: 0, title: @room_zero.title, description: @room_zero.description}})
    end
    :ok
  end

  def create(title, description) do
    next_id = :ets.update_counter(:rooms, :next_id, 1, {1,0})
    new_room = %Exedra.Room{id: next_id, title: title, description: description}
    :ets.insert_new(:rooms, {next_id, new_room})
    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:rooms,String.to_charlist(@data_file), sync: true)

    new_room
  end

  # TODO lock
  # link links the fromRoom to the toRoom in the given direction. Note this does not create a bidirectional link. The `to_room` must be linked in the opposite direction, to establish a bidirectional link. If the from_room has an existing exit in the given direction, it is overwritten.
  def link(from_room, to_room, direction) do
    from_room = %{from_room | exits: Map.put(from_room.exits, direction, to_room.id)}
    :ets.insert(:rooms, {from_room.id, from_room})

    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:rooms,String.to_charlist(@data_file), sync: true)
  end

  def link_rooms(from_room, to_room, direction) do
    link(from_room, to_room, direction)
    link(to_room, from_room, reverse(direction))
  end

  def get(id) do
    case :ets.lookup(:rooms, id) do
      [{_, room}] ->
        {:ok, room}
      [] ->
        :error
    end
  end

  def set(room) do
    :ets.insert(:rooms, {room.id, room})

    # debug - writing all players to disk every time someone moves doesn't scale.
    :ets.tab2file(:rooms, String.to_charlist(@data_file), sync: true)
  end

  def print(room, brief, self_player_name) do
    # TODO: add player custom colouring
    s = ANSI.colors[:brown] <> room.title <> ANSI.colors[:reset] <> "\n"
    s = if brief do
      s
    else
      s <> ANSI.colors[:cyan] <> room.description <> ANSI.colors[:reset] <> "\n"
    end

    items = room.items
    |> Enum.map(fn(item_id) ->
        {:ok, item} = Exedra.Item.get(item_id)
        item.room_description
      end)
    |> Enum.join(", ")

    s = if String.length(items) > 0 do
      s <> ANSI.colors[:cyan] <> items <> "." <> ANSI.colors[:reset] <> "\n"
    else
      s
    end

    npcs = room.npcs
    |> Enum.map(fn(npc_id) ->
        {:ok, npc} = Exedra.NPC.get(npc_id)
        npc.brief # TODO change to room_description when the command is implemented
      end)
    |> Enum.join(", ")

    s = if String.length(npcs) > 0 do
      s <> ANSI.colors[:grey] <> npcs <> "." <> ANSI.colors[:reset] <> "\n"
    else
      s
    end

    players_no_self = Enum.filter room.players, fn(player_name) -> player_name != self_player_name end
    s = s <> case length(players_no_self) do
               0 ->
                 ""
               1 ->
                 String.capitalize(List.first(players_no_self)) <> " is here.\n"
               2 ->
                 [player_a | player_b] = players_no_self
                 String.capitalize(player_a) <> " and " <> String.capitalize(List.first(player_b)) <> " are here.\n"
               _ ->
                 [some_player | rest_players] = players_no_self
                 Enum.reduce(rest_players, "", fn(rest_player_name, acc) ->
                   acc <> String.capitalize(rest_player_name) <> ", "
                 end) <> "and " <> String.capitalize(some_player) <> " are here.\n"
             end


    # TODO: make this more efficient?
    # TODO: add "and" to last exit
    exits = room.exits
    |> Map.keys
    |> Enum.map(fn(dir) -> dir_atom_to_string(dir) end)
    |> Enum.join(", ")


    s = s <> case room.currency do
               0 ->
                 ""
               1 ->
                 CommandGroupGeneral.currency_color() <> "A " <> CommandGroupGeneral.currency_text_singular() <> " is here." <> ANSI.colors[:reset] <> "\n"
               _ ->
                 CommandGroupGeneral.currency_color() <> Integer.to_string(room.currency) <> " " <> CommandGroupGeneral.currency_text_plural() <> " are here." <> ANSI.colors[:reset] <> "\n"
             end

    s = s <> ANSI.colors[:blue] <> if String.length(exits) == 0 do
      "There are no visible exits."
    else
      "You see exits leading " <> exits <> "."
    end <> ANSI.colors[:reset]
    s
  end

  def message_players(room, player_name, self_msg, others_msg) do
    # TODO deduplicate with message_players_except
    # Logger.info "message_players"
    # Logger.info inspect(room.players)
    Enum.map room.players, fn(room_player_name) ->
      case Exedra.SessionManager.get(Exedra.SessionManager, room_player_name) do
        {:ok, msg_pid} ->
          if room_player_name == player_name do
            if self_msg != "" do
              {:ok, player} = Player.get(room_player_name)
              send msg_pid, {:message, self_msg <>  "\n" <> Player.prompt(player)} # TODO catch? rescue?
            else
              nil
            end
          else
            {:ok, player} = Player.get(room_player_name)
            send msg_pid, {:message, others_msg <>  "\n" <> Player.prompt(player)} # TODO catch? rescue?
          end
        :error ->
          # Logger.error "player " <> room_player_name <> " was in room but not logged in."
          # TODO lock. There's a race here, like every other data mutation
          Exedra.Room.set(%{room | players: MapSet.delete(room.players, room_player_name)})
          nil
      end
    end
  end

  @doc """
  Sends the message to all players in the room, except the exceptions.
  This is generally used for things like targetted emotes, which will send custom messages to the targeter and targetee.
  """
  @spec message_players_except(Exedra.Room, String.t, [String.t]) :: nil
  def message_players_except(room, msg, player_name_exceptions) do
    Enum.map room.players, fn(room_player_name) ->
      case Exedra.SessionManager.get(Exedra.SessionManager, room_player_name) do
        {:ok, msg_pid} ->
          if Enum.member? player_name_exceptions, room_player_name do
            nil
          else
            {:ok, player} = Exedra.Player.get(room_player_name)
            msg = msg <>  "\n" <> Player.prompt(player)
            send msg_pid, {:message, msg} # TODO catch? rescue?
          end
        :error ->
          # Logger.error "player " <> room_player_name <> " was in room but not logged in."
          # TODO lock. There's a race here, like every other data mutation
          Exedra.Room.set(%{room | players: MapSet.delete(room.players, room_player_name)})
          nil
      end
    end
  end

  def create_dir(room, direction, title, description) do
    new_room = create(title, description)
    link_rooms(room, new_room, direction)
  end

  def reverse(dir) do
    case dir do
      :n ->
        :s
      :e ->
        :w
      :s ->
        :n
      :w ->
        :e
      :ne ->
        :sw
      :nw ->
        :se
      :se ->
        :nw
      :sw ->
        :ne
    end
  end

  def dir_atom_to_string(dir) do
    case dir do
      :n ->
        "north"
      :e ->
        "east"
      :s ->
        "south"
      :w ->
        "west"
      :ne ->
        "northeast"
      :nw ->
        "northwest"
      :se ->
        "southeast"
      :sw ->
        "southwest"
    end
  end

  def dir_string_to_atom(dir) do
    case dir do
      "n" ->
        :n
      "north" ->
        :n
      "e" ->
        :e
      "east" ->
        :e
      "s" ->
        :s
      "south" ->
        :s
      "w" ->
        :w
      "west" ->
        :w
      "northeast" ->
        :ne
      "ne" ->
        :ne
      "northwest" ->
        :nw
      "nw" ->
        :nw
      "southeast" ->
        :se
      "se" ->
        :se
      "southwest" ->
        :sw
      "sw" ->
        :sw
        _ ->
        :invalid
    end
  end

  @doc """
  find_npc_or_player_name_or_id finds the NPC or Player with the given name or ID.
  Returns {:npc, id}, {:player, id}, or :not_found.
  """
  @spec find_npc_or_player_name_or_id(Exedra.Room, integer) :: {:npc, Exedra.NPC} | {:player, Exedra.Player} | :not_found
  def find_npc_or_player_name_or_id(room, name_or_id) do
    Logger.info "Room.fnopnoi '" <> name_or_id <> "'"
    player_or_nil = Exedra.Player.find_in(name_or_id, room.players)
    if player_or_nil != nil do
      {:player, player_or_nil}
    else
      npc_or_nil = Exedra.NPC.find_in name_or_id, room.npcs
      if npc_or_nil != nil do
        {:npc, npc_or_nil}
      else
        :not_found
      end
    end
  end
end
