defmodule AzuraJS.Interactions.Ticket do
  alias Nostrum.Api
  alias Nostrum.Struct.Embed

  @staff_role 1_459_235_650_652_868_630
  @log_channel 1_461_171_375_489_155_212
  @parent_category 1_461_171_167_019_663_401

  @spec handle(map()) ::
          {:ok} | {:error, %{response: binary() | map(), status_code: 1..1_114_111}}
  def handle(%{data: %{custom_id: "ticket_menu"}} = interaction) do
    [selected] = interaction.data.values
    member = interaction.member
    user_id = member.user_id
    guild_id = interaction.guild_id

    emoji =
      case selected do
        "support" -> "💬"
        "report" -> "📝"
        "billing" -> "💸"
        "other" -> "❓"
        x -> x
      end

    base =
      case selected do
        "support" -> "support"
        "report" -> "report"
        "billing" -> "billing"
        "other" -> "other"
        x -> x
      end

    channel_name = "#{emoji}-#{base}-#{user_id}"

    overwrites = [
      %{
        id: guild_id,
        type: 0,
        allow: 0,
        deny: 3072
      },
      %{
        id: user_id,
        type: 1,
        allow: 3072,
        deny: 0
      },
      %{
        id: @staff_role,
        type: 1,
        allow: 3072,
        deny: 0
      }
    ]

    params = %{
      "name" => channel_name,
      "type" => 0,
      "parent_id" => @parent_category,
      "permission_overwrites" => overwrites,
      "topic" => "Ticket (#{base}) for <@#{user_id}>"
    }

    case Api.Channel.create(guild_id, params) do
      {:ok, channel} ->
        AzuraJS.TicketManager.add(channel.id, %{
          owner_id: user_id,
          guild_id: guild_id,
          type: selected
        })

        embed =
          %Embed{}
          |> Embed.put_title("<:azurajs:1459747730028236922> | Support Session Started")
          |> Embed.put_description(
            "Hello <@#{user_id}>! Welcome to your support session.\nPlease leave all necessary information below so our team can help you as quickly as possible.\n\nSomeone from our support team will be with you shortly."
          )
          |> Embed.put_color(0x5865F2)
          |> Embed.put_footer("🔐 - Nexdev Social - Support System")

        components = [
          %{
            type: 1,
            components: [
              %{
                type: 2,
                style: 4,
                label: "Close Ticket",
                custom_id: "close_ticket",
                emoji: %{name: "🔐"}
              }
            ]
          }
        ]

        Api.Message.create(channel.id,
          content: "<@#{user_id}> welcome to your ticket!",
          embeds: [embed],
          components: components
        )

        Api.Interaction.create_response(interaction, %{
          type: 4,
          data: %{content: "Your ticket was created successfully at: <##{channel.id}>", flags: 64}
        })
    end
  end

  def handle(%{data: %{custom_id: "close_ticket"}} = interaction) do
    channel_id = interaction.channel_id
    requester = interaction.member.user_id

    case AzuraJS.TicketManager.get(channel_id) do
      nil ->
        Api.Interaction.create_response(interaction, %{
          type: 4,
          data: %{content: "This channel is not a ticket...", flags: 64}
        })

      %{owner_id: owner_id} ->
        staff_role = @staff_role
        is_creator = owner_id == requester
        is_staff = Enum.any?(interaction.member.roles, fn r -> r == staff_role end)

        if is_creator or is_staff do
          Api.Interaction.create_response(interaction, %{
            type: 4,
            data: %{content: "Closing the ticket and generating transcript...", flags: 64}
          })

          transcript_file = generate_transcript_html(channel_id, owner_id)

          embed =
            %Embed{}
            |> Embed.put_title("📋 Ticket Closed")
            |> Embed.put_description(
              "Ticket created by: <@#{owner_id}>\nClosed by: <@#{requester}>"
            )
            |> Embed.put_color(0xED4245)
            |> Embed.put_timestamp(DateTime.utc_now() |> DateTime.to_iso8601())

          Api.Message.create(@log_channel,
            content: "Transcript for ticket <##{channel_id}>:",
            embeds: [embed],
            files: [transcript_file]
          )

          File.rm(transcript_file)
          Api.Channel.delete(channel_id)
          AzuraJS.TicketManager.remove(channel_id)
        else
          Api.Interaction.create_response(interaction, %{
            type: 4,
            data: %{content: "You do not have permission to close this ticket.", flags: 64}
          })
        end
    end
  end

  defp generate_transcript_html(channel_id, owner_id) do
    {:ok, messages} = Api.Channel.messages(channel_id, 100)

    messages = Enum.reverse(messages)
    message_count = length(messages)
    created_at = DateTime.utc_now() |> format_timestamp()

    header_html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Transcript - ##{channel_id}</title>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700&display=swap');
            body { background-color: #313338; color: #dbdee1; font-family: 'Roboto', 'Helvetica Neue', Helvetica, Arial, sans-serif; margin: 0; padding: 0; line-height: 1.375rem; font-size: 16px; }
            .chat-container { display: flex; flex-direction: column; padding: 1rem; max-width: 100%; overflow-x: hidden; }
            .preamble { padding: 16px; border-bottom: 1px solid #26272D; margin-bottom: 20px; }
            .preamble h1 { color: #f2f3f5; font-size: 24px; font-weight: 700; margin: 0 0 8px 0; }
            .preamble p { color: #b5bac1; font-size: 14px; margin: 0; }
            .message-group { display: flex; margin-top: 1.0625rem; min-height: 2.75rem; padding: 2px 16px; position: relative; }
            .message-group:hover { background-color: #2e3035; }
            .avatar-wrapper { margin-top: 2px; width: 40px; height: 40px; border-radius: 50%; cursor: pointer; overflow: hidden; margin-right: 16px; flex-shrink: 0; }
            .avatar-wrapper img { width: 100%; height: 100%; object-fit: cover; }
            .content-wrapper { flex: 1; min-width: 0; }
            .header { display: flex; align-items: center; margin-bottom: 2px; }
            .username { font-size: 1rem; font-weight: 500; color: #f2f3f5; margin-right: 0.25rem; cursor: pointer; }
            .username:hover { text-decoration: underline; }
            .bot-tag { background-color: #5865f2; color: #fff; font-size: 0.625rem; font-weight: 500; padding: 0 0.275rem; border-radius: 0.1875rem; margin-left: 0.25rem; line-height: 0.9375rem; height: 0.9375rem; text-transform: uppercase; vertical-align: top; display: inline-flex; align-items: center; }
            .timestamp { font-size: 0.75rem; color: #949ba4; margin-left: 0.25rem; font-weight: 400; }
            .message-content { color: #dbdee1; font-size: 1rem; line-height: 1.375rem; white-space: pre-wrap; word-wrap: break-word; }
            .attachment { margin-top: 8px; max-width: 400px; border-radius: 8px; overflow: hidden; background-color: #2b2d31; border: 1px solid #1e1f22; padding: 10px; display: flex; align-items: center; }
            .attachment a { color: #00a8fc; text-decoration: none; font-size: 14px; font-weight: 500; }
            .embed-container { display: grid; grid-template-columns: auto; grid-gap: 8px; margin-top: 8px; max-width: 520px; }
            .embed { display: flex; background-color: #2b2d31; border-radius: 4px; border-left: 4px solid #1e1f22; overflow: hidden; max-width: 100%; }
            .embed-grid { padding: .5rem 1rem 1rem .75rem; display: inline-grid; grid-template-columns: auto; grid-template-rows: auto; width: 100%; }
            .embed-title { font-size: 1rem; font-weight: 600; color: #f2f3f5; margin-bottom: 8px; }
            .embed-desc { font-size: 0.875rem; line-height: 1.125rem; color: #dbdee1; white-space: pre-wrap; }
            .footer { margin-top: 50px; text-align: center; color: #585b61; font-size: 12px; padding-bottom: 20px; }
        </style>
    </head>
    <body>
        <div class="chat-container">
            <div class="preamble">
                <h1>Welcome to #ticket-transcript</h1>
                <p>This is the start of the transcript for ticket ID ##{channel_id}. Created by user ID #{owner_id}.</p>
                <p><strong>Total Messages:</strong> #{message_count} | <strong>Generated:</strong> #{created_at}</p>
            </div>
    """

    messages_html = Enum.map(messages, &format_message_html/1) |> Enum.join("")

    footer_html = """
            <div class="footer">End of transcript • Exported by AzuraJS System</div>
        </div>
    </body>
    </html>
    """

    html = header_html <> messages_html <> footer_html
    file_name = "transcript-#{channel_id}.html"
    File.write!(file_name, html)
    file_name
  end

  defp format_message_html(message) do
    author = message.author
    username = author.username
    avatar_url = get_avatar_url(author)
    timestamp = parse_timestamp_for_date(message.timestamp) |> format_timestamp()
    content = escape_html(get_message_content(message))

    bot_tag = if author.bot, do: "<span class=\"bot-tag\">BOT</span>", else: ""

    attachments_html = format_attachments(message.attachments || [])
    embeds_html = format_embeds(message.embeds || [])

    """
    <div class="message-group">
        <div class="avatar-wrapper">
            <img src="#{avatar_url}" alt="Avatar">
        </div>
        <div class="content-wrapper">
            <div class="header">
                <span class="username" style="color: #{get_role_color(message)}">#{escape_html(username)}</span>
                #{bot_tag}
                <span class="timestamp">#{timestamp}</span>
            </div>
            <div class="message-content">#{content}</div>
            #{attachments_html}
            #{embeds_html}
        </div>
    </div>
    """
  end

  defp get_avatar_url(%{id: id, avatar: nil}),
    do: "https://cdn.discordapp.com/embed/avatars/#{rem(id, 5)}.png"

  defp get_avatar_url(%{id: id, avatar: hash}),
    do: "https://cdn.discordapp.com/avatars/#{id}/#{hash}.png"

  defp get_role_color(_), do: "#f2f3f5"

  defp format_attachments([]), do: ""

  defp format_attachments(attachments) do
    Enum.map(attachments, fn att ->
      """
      <div class="attachment">
         <div style="margin-right:10px; font-size: 24px;">📁</div>
         <div>
            <a href="#{att.url}" target="_blank">#{escape_html(att.filename)}</a>
            <div style="font-size:12px; color:#949ba4;">#{format_bytes(att.size || 0)}</div>
         </div>
      </div>
      """
    end)
    |> Enum.join("")
  end

  defp format_embeds([]), do: ""

  defp format_embeds(embeds) do
    html =
      Enum.map(embeds, fn embed ->
        color_hex =
          if embed.color,
            do: "#" <> Base.encode16(<<embed.color::24>>, case: :lower),
            else: "#1e1f22"

        title_html =
          if embed.title,
            do: "<div class=\"embed-title\">#{escape_html(embed.title)}</div>",
            else: ""

        desc_html =
          if embed.description,
            do: "<div class=\"embed-desc\">#{escape_html(embed.description)}</div>",
            else: ""

        """
        <div class="embed" style="border-left-color: #{color_hex};">
           <div class="embed-grid">
              #{title_html}
              #{desc_html}
           </div>
        </div>
        """
      end)
      |> Enum.join("")

    "<div class=\"embed-container\">#{html}</div>"
  end

  defp get_message_content(%{content: content})
       when is_binary(content) and byte_size(content) > 0, do: content

  defp get_message_content(_), do: ""

  defp parse_timestamp_for_date(nil), do: DateTime.utc_now()
  defp parse_timestamp_for_date(%DateTime{} = dt), do: dt

  defp parse_timestamp_for_date(ts) when is_binary(ts) do
    case DateTime.from_iso8601(ts) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp format_timestamp(%DateTime{} = dt) do
    dt
    |> DateTime.add(-3, :hour)
    |> Calendar.strftime("%d/%m/%Y %H:%M")
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{(bytes / 1024) |> Float.round(2)} KB"
  defp format_bytes(bytes), do: "#{(bytes / 1_048_576) |> Float.round(2)} MB"

  defp escape_html(nil), do: ""

  defp escape_html(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
