import Config

config :nostrum,
  gateway_intents: [:guilds, :guild_messages, :direct_messages, :message_content]

import_config "runtime.exs"
