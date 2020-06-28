defmodule Exedra.NPC.Eventor do
@moduledoc """
NPC.Eventor.Emote is a trigger in response to an emote being done to the NPC.

NPC.Eventor are function triggers in response to events.

Events are things like a player leaving the room, an emote being performed with the NPC as the target, etc.

Eventors can be registered to Events.

"""

  @doc """
  The name of the event. Must be unique.
  """
  @callback name() :: String.t

  @doc """
  For untargetted emotes.
  Takes the npc id, the name of the player doing the emote, and the name of the emote.
  """
  @callback on_emote(integer, String.t, String.t) :: nil
end
