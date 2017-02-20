defmodule Exedra.Room do
  require Logger

  alias Exedra.ANSI, as: ANSI

  @data_file "data/rooms"

  defmodule Data do
    @enforce_keys [:id, :title, :description]
    defstruct id: 0, title: "", description: "", exits: %{}, items: MapSet.new, players: MapSet.new
  end

  @room_zero %{
    title: "Primordial Fog",
    description: "A primordial fog permeates the area, obscuring all."
  }

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_char_list(@data_file)) do
      {:ok, :rooms} ->
        IO.puts "Rooms file loaded"
        :ok
      {:error, _} ->
        IO.puts "Rooms file didn't exist, creating new table"
        :rooms = :ets.new(:rooms, [:named_table, :set, :public])
        :ets.insert_new(:rooms, {0, %Exedra.Room.Data{id: 0, title: @room_zero.title, description: @room_zero.description}})
    end
    :ok
  end

  def create(title, description) do
    next_id = :ets.update_counter(:rooms, :next_id, 1, {1,0})
    new_room = %Exedra.Room.Data{id: next_id, title: title, description: description}
    :ets.insert_new(:rooms, {next_id, new_room})
    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:rooms,String.to_char_list(@data_file), sync: true)

    new_room
  end

  # TODO lock
  # link links the fromRoom to the toRoom in the given direction. Note this does not create a bidirectional link. The `to_room` must be linked in the opposite direction, to establish a bidirectional link. If the from_room has an existing exit in the given direction, it is overwritten.
  def link(from_room, to_room, direction) do
    from_room = %{from_room | exits: Map.put(from_room.exits, direction, to_room.id)}
    :ets.insert(:rooms, {from_room.id, from_room})

    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:rooms,String.to_char_list(@data_file), sync: true)
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

    # debug - writing all users to disk every time someone moves doesn't scale.
    :ets.tab2file(:rooms, String.to_char_list(@data_file), sync: true)
  end

  def print(room, brief) do
    # TODO: add user custom colouring
    s = ANSI.colors[:brown] <> room.title <> ANSI.colors[:reset] <> "\n"
    s = if brief do
      s
    else
      s <> ANSI.colors[:grey] <> room.description <> ANSI.colors[:reset] <> "\n"
    end

    items = room.items
    |> Enum.map(fn(item_id) ->
        {:ok, item} = Exedra.Item.get(item_id)
        item.room_description
      end)
    |> Enum.join(" ")

    s = if String.length(items) > 0 do
      s <> ANSI.colors[:darkgrey] <> items <> ANSI.colors[:reset] <> "\n"
    else
      s
    end

    # TODO: make this more efficient?
    # TODO: add "and" to last exit
    exits = room.exits
    |> Map.keys
    |> Enum.map(fn(dir) -> dir_atom_to_string(dir) end)
    |> Enum.join(", ")

    s = s <> ANSI.colors[:blue] <> if String.length(exits) == 0 do
      "There are no visible exits."
    else
      "You see exits leading " <> exits <> "."
    end <> ANSI.colors[:reset]
    s
  end

  def message_players(room, player_name, self_msg, others_msg) do
    Logger.info "message_players"
    Logger.info inspect(room.players)
    Enum.map room.players, fn(room_player_name) ->
      case Exedra.SessionManager.get(Exedra.SessionManager, room_player_name) do
        {:ok, msg_pid} ->
          if room_player_name == player_name do
            Logger.info "self message"
            send msg_pid, {:message, self_msg} # TODO catch? rescue?
          else
            Logger.info "others message"
            send msg_pid, {:message, others_msg} # TODO catch? rescue?
          end
        {:error} ->
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
end
