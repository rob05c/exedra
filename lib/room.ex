defmodule Exedra.Room do

  @data_file "data/rooms"

  defmodule Data do
    @enforce_keys [:id, :title, :description]
    defstruct id: 0, title: "", description: "", exits: %{}
  end

  @room_zero %{
    title: "Primordial Fog",
    description: "A primordial fog permeates the area, obscuring all"
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
    next_id = :ets.update_counter(:rooms, :next_id, 1, 0)
    :ets.insert_new(:rooms, {next_id, %Exedra.Room.Data{id: next_id, title: title, description: description}})
  end

  def get(id) do
    case :ets.lookup(:rooms, id) do
      [{id, room}] ->
        {:ok, room}
      [] ->
        :error
    end
  end

  def print(room, brief) do
    s = room.title <> "\n"
    s = if brief do
      s
    else
      s <> room.description <> "\n"
    end

    # TODO: make this more efficient?
    # TODO: add "and" to last exit
    exits = room.exits
    |> Map.keys
    |> Enum.map(fn(dir) -> dir_atom_to_string(dir) end)
    |> Enum.join(", ")

    s = s <> if String.length(exits) == 0 do
      "There are no visible exits."
    else
      "You see exits leading " <> exits <> "."
    end
    s
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
end
