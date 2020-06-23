defmodule Exedra.NPCActor.Wander do
  alias Exedra.NPCActor, as: NPCActor
  alias Exedra.WorldManager, as: WorldManager

  require Logger

  @behaviour NPCActor

  def name(), do: "wander"

  @impl NPCActor
  def act(npc_id) do
    WorldManager.npc_wander(Exedra.WorldManager, npc_id)
  end

  def wander(npc_id) do
    {:ok, npc} = Exedra.NPC.get(npc_id)
    if npc.room_id == -1 do
      nil
    else
      wander_npc(npc)
    end
  end

  def wander_npc(npc) do
    # debug - example of getting and setting actor data
    data = Map.get(npc.actor_data, name())
    data = if data != nil do
      data
    else
      0
    end
    data = data + 1
    Exedra.NPC.set(%{npc | actor_data: Map.put(npc.actor_data, name(), data)})
    Logger.info "wander_npc " <> npc.brief <> " count " <> to_string(data)

    {:ok, room} = Exedra.Room.get npc.room_id
    exits = Map.keys room.exits
    num_exits = length(exits)
    if num_exits == 0 do
      nil
    else
      exit_n = Enum.random(0..num_exits-1)
      exit_dir = Enum.at(exits, exit_n)
      {:ok, new_room_id} = Map.fetch room.exits, exit_dir
      {:ok, new_room} = Exedra.Room.get new_room_id
      dir_str = Exedra.Room.dir_atom_to_string(exit_dir)
      # TODO handle non-reversible exits
      from_dir_str = Exedra.Room.dir_atom_to_string(Exedra.Room.reverse(exit_dir))
      out_msg = npc.brief <> " wanders out to the " <> dir_str
      in_msg = npc.brief <> " wanders in from the " <> from_dir_str

      Exedra.NPC.move npc.id, new_room_id
      Exedra.Room.message_players room, "", "", out_msg
      Exedra.Room.message_players new_room, "", "", in_msg
    end
  end
end
