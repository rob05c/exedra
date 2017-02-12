# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :elixir,
  ansi_enabled: false

config :exedra,
  app: :exedra,
  port: 42424,
  credentials: [{"bill", "thelizard"}]
