defmodule Exedra.Player do
  require Logger

  @data_file "data/players"


  # TODO: don't store pass in plaintext
  @enforce_keys [:name, :room_id, :password]
  defstruct [
    name:     "",
    password: "",
    room_id:  0,
    items:    MapSet.new,
    npcs:     MapSet.new,
    currency: 0,
    command_groups: []
  ]

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_charlist(@data_file)) do
      {:ok, :players} ->
        IO.puts "Players file loaded"
        :ok
      {:error, _} ->
        IO.puts "Players file didn't exist, creating new table"
        :players = :ets.new(:players, [:named_table, :set, :public])
    end
    :ok
  end

  # login authenticates the player and password.
  # If the player exists and the password is correct, true is returned.
  # If the player exists and the password is wrong, false is returned.
  # If the player doesn't exist, a new password is generated, the new player is inserted in ETS, and the generated pass is returned.
  def login(player_name, pass) do
    default_room = 0 # TODO: make customizable
    case :ets.lookup(:players, player_name) do
      [{^player_name, player_data}] ->
        player_data.password == pass
      [] ->
        new_player = %Exedra.Player{
          name:           player_name,
          password:       pass,
          room_id:        default_room,
          command_groups: [
            Exedra.CommandGroup.General,
            Exedra.CommandGroup.Emote,
            Exedra.CommandGroup.Admin
          ]
        }
        :ets.insert_new(:players, {player_name, new_player})
        # TODO: dump all object tables at once
        :ets.tab2file(:players,String.to_charlist(@data_file), sync: true)
        true
    end
  end

  def exists?(player_name) do
    length(:ets.lookup(:players, player_name)) == 1
  end

  def get(name) do
    case :ets.lookup(:players, name) do
      [{^name, player}] ->
        {:ok, player}
      [] ->
        :error
    end
  end

  # TODO lock
  def set(player) do
    :ets.insert(:players, {player.name, player})

    # debug - writing all players to disk every time someone moves doesn't scale.
    :ets.tab2file(:players, String.to_charlist(@data_file), sync: true)
  end

  #TODO deduplicate with Item.find_in

  @doc """
  Finds the player name in the given set of names.
  Returns the player, or nil.
  """
  @spec find_in(String.t, MapSet.t) :: Exedra.Player | nil
  def find_in(name, names) do
    # TODO fuzzy match, or remove this
    name = Enum.find names, fn(names_name) ->
      {:ok, player} = Exedra.Player.get(names_name) # TODO avoid multiple gets
      player.name == name # TODO fuzzy match?
    end
      if MapSet.member?(names, name) do
        {:ok, player} = Exedra.Player.get(name)
        player
      else
        nil
      end
  end

  @spec message(Exedra.Player, String.t) ::  nil
  def message(player, msg) do
    # Logger.info "message_players"
    # Logger.info inspect(room.players)
    case Exedra.SessionManager.get(Exedra.SessionManager, player.name) do
      {:ok, msg_pid} ->
          send msg_pid, {:message, msg} # TODO catch? rescue?
      :error ->
        Logger.error "Player.message for player that wasn't logged in!"
        # TODO lock. There's a race here, like every other data mutation
        # Exedra.Room.set(%{room | players: MapSet.delete(room.players, room_player_name)})
        nil
    end
  end
end
