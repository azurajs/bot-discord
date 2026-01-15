defmodule AzuraJS.Commands.Ticket do
  alias Nostrum.Struct.Embed
  alias Nostrum.Api.Message

  @behaviour AzuraJS.Command

  @impl true
  def name, do: "ticket"

  @impl true
  def description, do: "[Ticket] send the ticket panel to the desired channel."

  @impl true
  def execute(%Nostrum.Struct.Message{} = msg) do
    channel_id = extract_channel_id(msg.content)

    case channel_id do
      nil ->
        Message.create(
          msg.channel_id,
          "You must mention the channel where you want the ticket panel."
        )

      id ->
        embed =
          %Embed{}
          |> Embed.put_title("<:azurajs:1459747730028236922> | Support Panel")
          |> Embed.put_description("Welcome to the AzuraJS support section. Here you can open a ticket and communicate directly with the official AzuraJS support team.\n\nPlease use this system only when you genuinely need assistance, so we can provide help efficiently to everyone.")
          |> Embed.put_color(0x5865F2)
          |> Embed.put_image("https://raw.githubusercontent.com/azurajs/website/refs/heads/main/public/azurajs-banner.png")

        components = [
          %{
            type: 1,
            components: [
              %{
                type: 3,
                custom_id: "ticket_menu",
                placeholder: "Select a category",
                min_values: 1,
                max_values: 1,
                options: [
                  %{
                    label: "Support",
                    value: "support",
                    description: "Talk with support",
                    emoji: %{name: "💬"}
                  },
                  %{
                    label: "Report",
                    value: "report",
                    description: "Report a member",
                    emoji: %{name: "📝"}
                  },
                  %{
                    label: "Billing",
                    value: "billing",
                    description: "Billing support",
                    emoji: %{name: "💸"}
                  },
                  %{
                    label: "Other",
                    value: "others",
                    description: "Other requests",
                    emoji: %{name: "❓"}
                  }
                ]
              }
            ]
          }
        ]

        Message.create(id, embeds: [embed], components: components)
    end
  end

  defp extract_channel_id(content) do
    case Regex.run(~r/<#(\d+)>/, content) do
      [_, id] -> String.to_integer(id)
      _ -> nil
    end
  end
end
