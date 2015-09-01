defmodule Pixie.Client do
  use GenServer
  require Logger

  defstruct id: nil, transport_pid: nil, transport_name: nil
  alias __MODULE__

  def start_link id do
    GenServer.start_link __MODULE__, id
  end

  def init id do
    Process.flag :trap_exit, true
    {:ok, %Client{id: id}, idle_timeout}
  end

  def terminate _reason, %Client{id: id} do
    Logger.debug "[#{id}]: Client terminating"
    :ok
  end

  @doc """
  Set the active transport to the connected client.
  """
  def set_transport client, transport_name do
    GenServer.call client, {:set_transport, transport_name}
  end

  @doc """
  Retrieve the active transport.
  """
  def transport client do
    GenServer.call client, :transport
  end

  @doc """
  Deliver some messages to the client in question.
  """
  def deliver client, messages do
    GenServer.cast client, {:deliver, messages}
  end

  @doc """
  Get create a process for the transport we're using, also dequeue any messages
  waiting for us in the backend.
  """
  def handle_call {:set_transport, transport_name}, _from, %{id: id, transport_pid: nil}=state do
    {:ok, transport} = Pixie.Transport.get transport_name, id
    Pixie.Transport.enqueue transport, Pixie.Backend.dequeue_for(id)
    Logger.debug "[#{id}]: Using transport #{transport_name}."
    {:reply, transport, %{state | transport_pid: transport, transport_name: transport_name}, idle_timeout}
  end

  def handle_call {:set_transport, transport_name}, from, %{id: id, transport_pid: transport, transport_name: old_transport_name}=state do
    if Process.alive? transport do
      if transport_name == old_transport_name do
        Pixie.Transport.enqueue transport, Pixie.Backend.dequeue_for(id)
        {:reply, transport, state, idle_timeout}
      else
        handle_call {:set_transport, transport_name}, from, %{state | transport_pid: nil}
      end
    else
      handle_call {:set_transport, transport_name}, from, %{state | transport_pid: nil}
    end
  end

  def handle_call :transport, _from, %{transport_pid: transport}=state do
    {:reply, transport, state, idle_timeout}
  end

  @doc """
  When we don't have an active transport we ask the backend to queue them
  for us until we do.
  """
  def handle_cast {:deliver, messages}, %{id: id, transport_pid: nil}=state do
    Pixie.Backend.queue_for id, messages
    {:noreply, state, idle_timeout}
  end

  @doc """
  When we have an active transport we ask the transport to deliver them
  to the client at it's leisure.
  """
  def handle_cast {:deliver, messages}, %{transport_pid: transport}=state do
    Pixie.Transport.enqueue transport, messages
    {:noreply, state, idle_timeout}
  end

  def handle_info :timeout, %{id: id}=state do
    Task.async Pixie.Backend, :destroy_client, [id, "Idle timeout."]
    {:noreply, state}
  end

  defp idle_timeout do
    Pixie.timeout * 4
  end

end
