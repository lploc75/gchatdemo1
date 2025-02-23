# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :gchatdemo1,
  ecto_repos: [Gchatdemo1.Repo],
  generators: [timestamp_type: :utc_datetime]

# config :cloudex,
  # api_key: System.fetch_env!("CLOUDINARY_API_KEY"),
  # api_secret: System.fetch_env!("CLOUDINARY_API_SECRET"),
  # cloud_name: System.fetch_env!("CLOUDINARY_CLOUD_NAME")
# Configures the cloudinary
config :cloudex,
  api_key: "335681169415731",
  secret: "wARMUj_KXlpHmJp9b7gczCpfFmg",
  cloud_name: "djyr2tc78"
# set CLOUDINARY_CLOUD_NAME=djyr2tc78
# set CLOUDINARY_API_SECRET=wARMUj_KXlpHmJp9b7gczCpfFmg
# set CLOUDINARY_API_KEY=335681169415731

# $env:CLOUDINARY_API_KEY="335681169415731"
# $env:CLOUDINARY_API_SECRET="wARMUj_KXlpHmJp9b7gczCpfFmg"
# $env:CLOUDINARY_CLOUD_NAME="djyr2tc78"

# Configures the endpoint
config :gchatdemo1, Gchatdemo1Web.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: Gchatdemo1Web.ErrorHTML, json: Gchatdemo1Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: Gchatdemo1.PubSub,
  live_view: [signing_salt: "E80wFUjN"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :gchatdemo1, Gchatdemo1.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  gchatdemo1: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  gchatdemo1: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
