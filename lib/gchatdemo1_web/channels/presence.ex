defmodule Gchatdemo1Web.Presence do
  use Phoenix.Presence,
    otp_app: :gchatdemo1,
    pubsub_server: Gchatdemo1.PubSub
end
