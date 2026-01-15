defmodule AzuraJS.Ping do
  def get do
    # Tenta pegar via websocket connection
    case get_websocket_latency() do
      nil -> get_api_latency()
      latency -> latency
    end
  end

  defp get_websocket_latency do
    # Procura o processo da conexão websocket
    ws_pid =
      Process.list()
      |> Enum.find(fn pid ->
        case Process.info(pid, :registered_name) do
          {:registered_name, name} ->
            name_str = to_string(name)
            String.contains?(name_str, "Websocket") ||
            String.contains?(name_str, "Gateway") ||
            String.contains?(name_str, "Conn")

          _ ->
            false
        end
      end)

    case ws_pid do
      nil ->
        nil

      pid ->
        try do
          state = :sys.get_state(pid)

          # Tenta diferentes estruturas de estado
          cond do
            is_map(state) && Map.has_key?(state, :heartbeat_ack) && Map.has_key?(state, :last_heartbeat) ->
              calculate_diff(state.heartbeat_ack, state.last_heartbeat)

            is_map(state) && Map.has_key?(state, :conn) && is_map(state.conn) ->
              conn = state.conn
              calculate_diff(Map.get(conn, :heartbeat_ack), Map.get(conn, :last_heartbeat))

            true ->
              nil
          end
        rescue
          _ -> nil
        end
    end
  end

  defp calculate_diff(%DateTime{} = ack, %DateTime{} = sent) do
    abs(DateTime.diff(ack, sent, :millisecond))
  end

  defp calculate_diff(_, _), do: nil

  defp get_api_latency do
    # Mede latência fazendo uma requisição leve à API
    start = System.monotonic_time(:millisecond)

    case Nostrum.Api.Self.get() do
      {:ok, _user} ->
        finish = System.monotonic_time(:millisecond)
        finish - start

      _ ->
        "N/A"
    end
  end
end
