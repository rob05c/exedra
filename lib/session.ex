defmodule Exedra.SessionManager do
  use GenServer

  defmodule Data do
    @enforce_keys [:user, :pid]
    defstruct user: "", pid: 0
  end

  @spec get(GenServer.server, String.t) :: {:ok, pid} | :error
  def get(server, user) do
    GenServer.call server, {:get, user}
  end

  @spec set(GenServer.server, String.t, pid) :: :ok
  def set(server, user, pid) do
    GenServer.cast server, {:set, user, pid}
  end

  @spec delete(GenServer.server, String.t) :: :ok
  def delete(server, user) do
    GenServer.cast server, {:delete, user}
  end


  @spec init([]) :: {:ok, %{}}
  def init([]) do
    {:ok,  %{}}
  end

  # @spec start_link(String.t) :: GenServer.on_start
  @spec start_link(atom | {:global, any} | {:via, atom, any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(name) do
    GenServer.start_link __MODULE__, [], name: name
  end

  @spec handle_call({:get, String.t}, any, %{}) :: {:reply, {:ok, pid} | :error, %{}}
  def handle_call({:get, user}, _from, data) do
    reply = Map.fetch(data, user)
    {:reply, reply, data}
  end

  @spec handle_cast({:set, String.t, pid}, %{}) :: {:noreply, %{}}
  def handle_cast({:set, user, pid}, data) do
    data = Map.put data, user, pid
    {:noreply, data}
  end

  @spec handle_cast({:delete, String.t}, %{}) :: {:noreply, %{}}
  def handle_cast({:delete, user}, data) do
    data = Map.delete(data, user)
    {:noreply, data}
  end
end
