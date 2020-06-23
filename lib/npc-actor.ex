defmodule Exedra.NPCActor do
@moduledoc """
NPCActor is a behavior that NPC actors must implement.

NPC Actors are functions which are run every tick interval.
They are things like: wandering around, picking up things, giving away things, etc.
"""

  @doc """
  Takes the npc id. Anything done that requires multiple data objects must
  Be done via functions in the WorldManager GenServer
  """
  @callback act(integer) :: nil
end
