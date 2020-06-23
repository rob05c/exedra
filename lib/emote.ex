defmodule Exedra.Emote do
@moduledoc """
Emote is a behavior that emotes implement.

Emotes have a message to send to first, second, and third person; both targetted and untargetted.
"""

  @doc """
  For untargetted emotes.
  Takes the first person name, and returns the first-person message.
  """
  @callback first(String.t) :: String.t

  # no second-person for untargetted emotes

  @doc """
  For untargetted emotes.
  Takes the first person name, and returns the third-person message.
  """
  @callback third(String.t) :: String.t

  @doc """
  Takes the first and second person names, and returns the first-person message.
  Note the 'name' of items and NPCs should be the brief description.
  """
  @callback target_first(String.t, String.t) :: String.t

  @doc """
  Takes the first and second person names, and returns the second-person message.
  Note the 'name' of items and NPCs should be the brief description.
  """
  @callback target_second(String.t, String.t) :: String.t

  @doc """
  Takes the first and second person names, and returns the third-person message.
  Note the 'name' of items and NPCs should be the brief description.
  """
  @callback target_third(String.t, String.t) :: String.t

  @doc """
  Takes the first and second person names, and returns the self message
  when no player, npc, or item is in the room with the target_name.
  """
  @callback target_missing(String.t, String.t) :: String.t
end
