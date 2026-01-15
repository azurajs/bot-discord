defmodule AzuraJS.Consumer do
  use Nostrum.Consumer
  require Logger

  alias Nostrum.Api
  alias AzuraJS.Commands.Structure.Router

  @impl true
  def handle_event({:READY, _ready_event, _ws_state}) do
    Api.Self.update_status(:online, "AzuraJS | https://azura.js.org", 0)
    :ok
  end

  @impl true
  def handle_event({:MESSAGE_CREATE, %{author: %{bot: true}}, _ws_state}), do: :noop

  @impl true
  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    bot_id =
      case Api.Self.get() do
        {:ok, bot} when is_map(bot) -> Integer.to_string(bot.id)
        bot when is_map(bot) -> Integer.to_string(bot.id)
        _ -> nil
      end

    content = msg.content || ""
    mention1 = if bot_id, do: "<@" <> bot_id <> ">", else: ""
    mention2 = if bot_id, do: "<@!" <> bot_id <> ">", else: ""

    cond do
      bot_id && String.starts_with?(content, mention1) ->
        query =
          content
          |> String.replace_prefix(mention1, "")
          |> String.trim()

        Task.start(fn -> process_query(msg, query) end)

      bot_id && String.starts_with?(content, mention2) ->
        query =
          content
          |> String.replace_prefix(mention2, "")
          |> String.trim()

        Task.start(fn -> process_query(msg, query) end)

      true ->
        Router.dispatch(msg)
    end
  end

  @impl true
  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    case interaction.data do
      %{custom_id: id} when id in ["ticket_menu", "close_ticket"] ->
        Task.start(fn -> AzuraJS.Interactions.Ticket.handle(interaction) end)

      _ ->
        :noop
    end
  end

  @impl true
  def handle_event(_), do: :noop

  defp process_query(msg, "") do
    Api.Message.create(msg.channel_id, "Por favor envie uma pergunta.")
  end

  defp process_query(msg, query) do
    Logger.info("Processing query...")

    case AzuraJS.MnnIA.request(query) do
      {:ok, text} ->
        Api.Message.create(msg.channel_id, text)

      {:error, reason} ->
        Logger.error("MnnIA request failed: #{inspect(reason)}")
        Api.Message.create(msg.channel_id, "Desculpe, não consegui obter a resposta do modelo.")
    end
  end
end
