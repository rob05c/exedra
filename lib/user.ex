defmodule Exedra.User do
  require Logger

  @data_file "data/users"

  defmodule Data do
    @enforce_keys [:name, :room_id, :password]
    # TODO: don't store pass in plaintext
    defstruct [
      name:     "",
      password: "",
      room_id:  0,
      items:    MapSet.new,
      npcs:     MapSet.new,
      currency: 0,
      command_groups: []
    ]
  end

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_charlist(@data_file)) do
      {:ok, :users} ->
        IO.puts "Users file loaded"
        :ok
      {:error, _} ->
        IO.puts "Users file didn't exist, creating new table"
        :users = :ets.new(:users, [:named_table, :set, :public])
    end
    :ok
  end

  # login authenticates the user and password.
  # If the user exists and the password is correct, true is returned.
  # If the user exists and the password is wrong, false is returned.
  # If the user doesn't exist, a new password is generated, the new user is inserted in ETS, and the generated pass is returned.
  def login(user_name, pass) do
    default_room = 0 # TODO: make customizable
    case :ets.lookup(:users, user_name) do
      [{^user_name, user_data}] ->
        user_data.password == pass
      [] ->
        new_user = %Exedra.User.Data{
          name:           user_name,
          password:       pass,
          room_id:        default_room,
          command_groups: [
            Exedra.CommandGroup.General,
            Exedra.CommandGroup.Emote,
            Exedra.CommandGroup.Admin
          ]
        }
        :ets.insert_new(:users, {user_name, new_user})
        # TODO: dump all object tables at once
        :ets.tab2file(:users,String.to_charlist(@data_file), sync: true)
        true
    end
  end

  def exists?(user_name) do
    length(:ets.lookup(:users, user_name)) == 1
  end

  def get(name) do
    case :ets.lookup(:users, name) do
      [{^name, user}] ->
        {:ok, user}
      [] ->
        :error
    end
  end

  # TODO lock
  def set(user) do
    :ets.insert(:users, {user.name, user})

    # debug - writing all users to disk every time someone moves doesn't scale.
    :ets.tab2file(:users, String.to_charlist(@data_file), sync: true)
  end

  #TODO deduplicate with Item.find_in

  @doc """
  Finds the player name in the given set of names.
  Returns the player, or nil.
  """
  @spec find_in(String.t, MapSet.t) :: Exedra.User.Data | nil
  def find_in(name, names) do
    # TODO fuzzy match, or remove this
    name = Enum.find names, fn(names_name) ->
      {:ok, player} = Exedra.User.get(names_name) # TODO avoid multiple gets
      player.name == name # TODO fuzzy match?
    end
      if MapSet.member?(names, name) do
        {:ok, player} = Exedra.User.get(name)
        player
      else
        nil
      end
  end

  @spec message(Exedra.User.Data, String.t) ::  nil
  def message(player, msg) do
    # Logger.info "message_players"
    # Logger.info inspect(room.players)
    case Exedra.SessionManager.get(Exedra.SessionManager, player.name) do
      {:ok, msg_pid} ->
          send msg_pid, {:message, msg} # TODO catch? rescue?
      :error ->
        Logger.error "User.message for player that wasn't logged in!"
        # TODO lock. There's a race here, like every other data mutation
        # Exedra.Room.set(%{room | players: MapSet.delete(room.players, room_player_name)})
        nil
    end
  end
end
