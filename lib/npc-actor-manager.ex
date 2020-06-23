defmodule Exedra.NPCActorManager do
@moduledoc """
NPCActorManager is used to do npc actions every tick.
"""
  use GenServer
  require Logger

  # TODO offset NPC actions, so they don't all happen at once.
  #      Shorten tick, mod and return on individual npcs?
  @tick_seconds 5

  @spec init([]) :: {:ok, %{}}
  def init([]) do
    schedule_tick()
    {:ok,  %{}}
  end

  defp schedule_tick() do
    Process.send_after(self(), :tick, @tick_seconds * 1000)
  end

  # # @spec start_link(String.t) :: GenServer.on_start
  # @spec start_link(atom | {:global, any} | {:via, atom, any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(name) do
    GenServer.start_link __MODULE__, [], name: name
  end

  def handle_info(:tick, state) do
    tick()
    schedule_tick()
    {:noreply, state}
  end

  def tick() do
    npc_ids = Exedra.NPC.all()
    Enum.each npc_ids, fn(npc_id) ->
      {:ok, npc} = Exedra.NPC.get(npc_id)
      if npc.room_id == -1 do
        Logger.info "tick " <> npc.name <> " no room, skipping"
        nil # don't tick NPCs that aren't in a room (e.g. in someone's inventory)
      else
        tick_npc(npc)
      end
    end

    # TODO only tick NPCs when a player is in the local area?
  end

  def tick_npc(npc) do
    Logger.info "tick_npc " <> npc.name
    Enum.each npc.actors, fn(actor) ->
      actor.act(npc.id)
    end
  end
end
