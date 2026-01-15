defmodule AzuraJS.Commands.Ping do
  alias Nostrum.Api.Message
  @behaviour AzuraJS.Command

  @impl true
  def name, do: "ping"

  @impl true
  def description, do: "[Geral] Retorna o tempo de resposta do bot com a Gateway do Discord."

  @impl true
  def execute(%{channel_id: channel_id}) do
    ping = AzuraJS.Ping.get()
    Message.create(channel_id, "Pong! respondi essa mensagem em: `#{ping}ms`")
  end
end
