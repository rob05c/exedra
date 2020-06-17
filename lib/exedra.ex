defmodule Exedra do
  use Application
  alias Exedra.User, as: User
  alias Exedra.Room, as: Room
  alias Exedra.Item, as: Item
  alias Exedra.NPC, as: NPC
  alias Exedra.SSHManager, as: SSHManager
  alias Exedra.SessionManager, as: SessionManager
  alias Exedra.WorldManager, as: WorldManager

  # @spec start(any, any) :: Supervisor.on_start
  @spec start(any, any) :: {:error, any} | {:ok, pid} | {:ok, pid, any}
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(SSHManager, []),
      worker(SessionManager, [SessionManager]),
      worker(WorldManager, [WorldManager])
    ]

    :ok = User.load()
    :ok = Room.load() # TODO remove room players on startup
    :ok = Item.load()
    :ok = NPC.load()

    opts = [strategy: :one_for_one, name: Exedra.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
