defmodule Exedra.CommandGroup do
@moduledoc """
CommandGroup is a behavior that command groups that players belong to must implement.

Command groups are things like: general, admin, wizard, fighter, etc.
"""

  # Takes the player name and the input words, and returns the output string (which may be empty),
  # or if this group doesn't handle the given user input command, returns :unhandled.
  @callback exec([String.t], String.t) :: String.t | :unhandled
end
