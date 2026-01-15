defmodule AzuraJS.TicketManager do
  use Agent

  def start_link(_), do: Agent.start_link(fn -> %{} end, name: __MODULE__)

  def add(channel_id, info),
    do: Agent.update(__MODULE__, &Map.put(&1, to_string(channel_id), info))

  def get(channel_id),
    do: Agent.get(__MODULE__, &Map.get(&1, to_string(channel_id)))

  def remove(channel_id), do: Agent.update(__MODULE__, &Map.delete(&1, channel_id))
  def list(), do: Agent.get(__MODULE__, & &1)
end
