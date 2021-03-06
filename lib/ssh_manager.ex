defmodule Exedra.SSHManager do
  use GenServer

  @port 42001
  @app_name :exedra

  defstruct [:port, :credentials, :pid, :priv_dir]

  @doc false
  def start_link() do
    GenServer.start_link __MODULE__, [], name: __MODULE__
  end

  @doc false
  def init([]) do
    port        = Application.get_env :exedra, :port, @port
    master_app  = Application.get_env :exedra, :app, @app_name

    app_dir     = Application.app_dir master_app
    priv_dir    = Path.join([app_dir, "priv", "exedra"])
                  |> String.to_charlist

    # credentials = Application.get_env(:exedra, :credentials, [])
                  # |> Enum.map(fn({u,p}) -> {String.to_charlist(u), String.to_charlist(p)} end)
    credentials = []

    GenServer.cast self(), :start

    {:ok, %__MODULE__{port: port, priv_dir: priv_dir, credentials: credentials}}
  end

  @doc false
  def handle_cast(:start, %__MODULE__{port: port, priv_dir: priv_dir, credentials: _credentials} = state) do
    {:ok, pid} = :ssh.daemon port,
      shell:          fn(player) -> Exedra.REPL.start(player) end,
      system_dir:     priv_dir,
      user_dir:       priv_dir,
      # password:       String.to_charlist(""),
      # player_passwords: credentials,
      auth_method_kb_interactive_data: fn(_ip_port, player_cl, _service) ->
        player = String.Chars.to_string(player_cl)
        if Exedra.Player.exists?(player) do
          {String.to_charlist("EXEDRA"),
           String.to_charlist("Enter Password for " <> player <> ":"),
           String.to_charlist("Password: "),
           false}
        else
          {String.to_charlist("EXEDRA"),
           String.to_charlist("Creating New Player " <> player <> ":"),
           String.to_charlist("Create a new password:"),
           false}
        end
      end,
      pwdfun: fn(player_name, pass, {_ip, _port}, _state) ->
        player_name = String.Chars.to_string(player_name)
        pass = String.Chars.to_string(pass)
        # # TODO: block repeated IP failures
        Exedra.Player.login(player_name, pass)
       end


    Process.link pid
    {:noreply, %__MODULE__{ state | pid: pid }, :hibernate}
  end

end
