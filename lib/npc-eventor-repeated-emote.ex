defmodule Exedra.NPC.Eventor.RepeatedEmote do
  alias Exedra.WorldManager, as: WorldManager
  alias Exedra.NPC.Eventor, as: Eventor
  require Logger

  @behaviour Eventor

  @impl Eventor
  def name(), do: "repeated-emote"

  @impl Eventor
  def on_emote(npc_id, player_name, emote_name) do
    # Note this is not a WorldManager call, because the event will be firing in the world thread.
    # If that ever changes, this MUST be changed to a GenServer.call WorldManager :npc_callback

    # GenServer.call WorldManager, {:npc_callback, fn() ->
    do_on_emote npc_id, player_name, emote_name
  end

  @ doc """
  Takes the NPC id, the player name, and the emote name
  """
  @spec do_on_emote(integer, String.t, String.t) :: String.t
  def do_on_emote(npc_id, player_name, emote_name) do
    {:ok, npc} = Exedra.NPC.get(npc_id)
    if npc.room_id == -1 do
      nil
    else
      on_emote_npc(npc, player_name, emote_name)
    end
  end

  @doc """
  Handle the event for an NPC which is in a room.
  Takes the NPC, the player name doing the emote, and the name of the emote.
  """
  @spec on_emote_npc(Exedra.NPC.Data, String.t, String.t) :: nil
  def on_emote_npc(npc, _, _) do
    # data is the number of times this NPC has been emoted to.
    data = Map.get(npc.event_data, name())
    data = if data != nil do
      data
    else
      0
    end
    data = data + 1
    Exedra.NPC.set %{npc | event_data: Map.put(npc.event_data, name(), data)}
    # Logger.info "wander_npc " <> npc.brief <> " count " <> to_string(data)

    # {:ok, player} = Exedra.User.get player_name
    {:ok, room} = Exedra.Room.get npc.room_id

    msg = case rem(data, 4) do
            0 ->
              "Oi!"
            1 ->
              "What?"
            2 ->
              "I dun wanna do that."
            _ ->
              "I got work ta do."
          end
    msg = npc.brief <> " says, \"" <> msg <> "\""
    # TODO color
    Exedra.Room.message_players_except(room, msg, [])
    nil
  end
end
