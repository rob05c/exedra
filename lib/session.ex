defmodule Exedra.SessionManager do
  use GenServer

  @spec get(GenServer.server, String.t) :: {:ok, pid} | :error
  def get(server, player) do
    GenServer.call server, {:get, player}
  end

  @spec set(GenServer.server, String.t, pid) :: :ok
  def set(server, player, pid) do
    GenServer.cast server, {:set, player, pid}
  end

  @spec delete(GenServer.server, String.t) :: :ok
  def delete(server, player) do
    GenServer.cast server, {:delete, player}
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
  def handle_call({:get, player}, _from, data) do
    reply = Map.fetch(data, player)
    {:reply, reply, data}
  end

  @spec handle_cast({:set, String.t, pid}, %{}) :: {:noreply, %{}}
  def handle_cast({:set, player, pid}, data) do
    data = Map.put data, player, pid
    {:noreply, data}
  end

  @spec handle_cast({:delete, String.t}, %{}) :: {:noreply, %{}}
  def handle_cast({:delete, player}, data) do
    data = Map.delete(data, player)
    {:noreply, data}
  end
end
