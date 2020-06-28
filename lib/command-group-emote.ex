defmodule Exedra.CommandGroup.Emote do
  alias Exedra.CommandGroup, as: CommandGroup
  alias Exedra.WorldManager, as: WorldManager

  require Logger

  @behaviour CommandGroup

  @impl CommandGroup
  def exec(["greet"     | args], player_name), do: emote(player_name, :greet, args)

  def exec(_, _), do: :unhandled

  def emote(player_name, emote, args) do
    GenServer.call WorldManager, {:emote, player_name, emote, args}
  end

  @doc """
  Handles a player emote command.
  Should be called from Worldmanager, for synchronization.
  Returns the message to send the player.
  """
  @spec do_emote(String.t, atom, [String.t]) :: String.t
  def do_emote(player_name, emote, args) do
    case emote do
      :greet ->
        do_emote_module Exedra.Emote.Greet, player_name, args
    end
  end

  @doc """
  Handles a player greet command.
  Should be called from Worldmanager, for synchronization.
  Returns the message to send the player.
  """
  @spec do_emote_module(module, String.t, [String.t]) :: String.t
  def do_emote_module(emote, player_name, args) do
    # TODO better name
    {:ok, player} = Exedra.Player.get player_name
    {:ok, room} = Exedra.Room.get player.room_id
    if length(args) > 0 do
      target = Enum.at(args, 0)
      msg = nil
      msg = with nil <- msg,
                 target_player when not is_nil(target_player) <- Exedra.Player.find_in(target, room.players) do
              emote_player emote, player, room, target_player
      end
      msg = with nil <- msg,
                 npc when not is_nil(npc) <- Exedra.NPC.find_in(target, room.npcs) do
              emote_npc emote, player, room, npc
      end
      msg = with nil <- msg,
                 item when not is_nil(item) <- Exedra.Item.find_in(target, room.items) do
              emote_item emote, player, room, item
            end
      msg = with nil <- msg do
              emote.target_missing player.name, target
            end
      msg
    else
      emote_none emote, player, room
    end
  end

  @spec emote_player(module, Exedra.Player, Exedra.Room, Exedra.Player) :: String.t
  def emote_player(emote, player, room, target_player) do
    others_msg = emote.target_third player.name, target_player.name
    target_msg = emote.target_second player.name, target_player.name
    self_msg = emote.target_first player.name, target_player.name
    Exedra.Room.message_players_except(room, others_msg, [player.name, target_player.name])
    Exedra.Player.message(target_player, target_msg)
    self_msg
  end

  @spec emote_npc(module, Exedra.Player, Exedra.Room, Exedra.NPC) :: String.t
  def emote_npc(emote, player, room, npc) do
    others_msg = emote.target_third player.name, npc.brief
    self_msg = emote.target_first player.name, npc.brief
    Exedra.Room.message_players_except(room, others_msg, [player.name])

    # we need to send the message to the player _before_ any event response
    # TODO make this less hacky?
    Exedra.Player.message player, self_msg
    Enum.each npc.events, fn(event) ->
      event.on_emote(npc.id, player.name, emote.name())
    end
    ""
  end

  @spec emote_item(module, Exedra.Player, Exedra.Room, Exedra.Item) :: String.t
  def emote_item(emote, player, room, item) do
    others_msg = emote.target_third player.name, item.brief
    self_msg = emote.target_first player.name, item.brief
    Exedra.Room.message_players_except(room, others_msg, [player.name])
    self_msg
  end

  @spec emote_none(module, Exedra.Player, Exedra.Room) :: String.t
  def emote_none(emote, player, room) do
    others_msg = emote.third player.name
    self_msg = emote.first player.name
    Exedra.Room.message_players_except(room, others_msg, [player.name])
    self_msg
  end
end
