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
                  |> String.to_char_list

    credentials = Application.get_env(:exedra, :credentials, [])
                  |> Enum.map(fn({u,p}) -> {String.to_char_list(u), String.to_char_list(p)} end)

    GenServer.cast self(), :start

    {:ok, %__MODULE__{port: port, priv_dir: priv_dir, credentials: credentials}}
  end

  @doc false
  def handle_cast(:start, %__MODULE__{port: port, priv_dir: priv_dir, credentials: credentials} = state) do
    {:ok, pid} = :ssh.daemon port,  shell:          fn(user) -> Exedra.REPL.start(user) end,
                                    system_dir:     priv_dir,
                                    user_dir:       priv_dir,
                                    user_passwords: credentials
    Process.link pid
    {:noreply, %__MODULE__{ state | pid: pid }, :hibernate}
  end

end
