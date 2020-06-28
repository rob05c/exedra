defmodule Exedra.Emote.Greet do
  alias Exedra.Emote, as: Emote

  @behaviour Emote

  @impl
  def name(), do: "greet"

  @impl Emote
  def first(_), do: "Greetings! You enthuse."

  @impl Emote
  def third(player_name), do: "Greetings! " <> player_name <> " enthuses."

  @impl Emote
  def target_first(_, target_name), do: "You greet " <> target_name <> " warmly!"

  @impl Emote
  def target_second(player_name, _), do: player_name <> " greets you warmly!"

  @impl Emote
  def target_third(player_name, target_name), do: player_name <> " greets " <> target_name <> " warmly!"

  @impl Emote
  def target_missing(_, _), do: "Whom do you want to greet?"
end
