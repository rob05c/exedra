defmodule Exedra.NPC do

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
    defstruct id: 0, name: "", brief: "", description: "", room_description: "", dead_description: "", exit_description: "", entry_description: "", plural_brief: ""
  end

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_char_list(@data_file)) do
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
    :ets.tab2file(:npcs, String.to_char_list(@data_file), sync: true)

    Exedra.User.set(%{player | npcs: MapSet.put(player.npcs, new_npc.id)})

    new_npc
  end

  def pickup(npc_id, room, player) do
    Exedra.Room.set(%{room | npcs: MapSet.delete(room.npcs, npc_id)})
    Exedra.User.set(%{player | npcs: MapSet.put(player.npcs, npc_id)})
  end

  def drop(npc_id, room, player) do
    Exedra.User.set(%{player | npcs: MapSet.delete(player.npcs, npc_id)})
    Exedra.Room.set(%{room | npcs: MapSet.put(room.npcs, npc_id)})
  end


  def get(id) do
    case :ets.lookup(:npcs, id) do
      [{_, npc}] ->
        {:ok, npc}
      [] ->
        :error
    end
  end

  def set(npc) do
    :ets.insert(:npcs, {npc.id, npc})

    # debug - writing all users to disk every time someone moves doesn't scale.
    :ets.tab2file(:npcs, String.to_char_list(@data_file), sync: true)
  end
end
