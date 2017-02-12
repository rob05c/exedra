defmodule Exedra do
  use Application

  @spec start(any, any) :: Supervisor.on_start
  def start(_type, _args) do
    IO.puts "start"
    import Supervisor.Spec, warn: false

    children = [
      worker(Exedra.SSHManager, [])
    ]

    opts = [strategy: :one_for_one, name: Exedra.Supervisor]
    Supervisor.start_link(children, opts)
  end
end