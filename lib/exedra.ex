defmodule Exedra do
  use Application
  alias Exedra.User, as: User
  alias Exedra.Room, as: Room
  alias Exedra.Item, as: Item
  alias Exedra.SSHManager, as: SSHManager
  alias Exedra.SessionManager, as: SessionManager

  @spec start(any, any) :: Supervisor.on_start
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(SSHManager, []),
      worker(SessionManager, [SessionManager])
    ]

    :ok = User.load()
    :ok = Room.load() # TODO remove room players on startup
    :ok = Item.load()

    opts = [strategy: :one_for_one, name: Exedra.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
