defmodule Gchatdemo1Web.StreamListOldController do
  use Gchatdemo1Web, :controller

  import Phoenix.LiveView.Controller

  require Logger

  def index(conn, %{"streamer_name" => streamer_name}) do
    current_user = conn.assigns[:current_user]
    Logger.info("Current user setting: #{inspect(current_user)}")
    live_render(conn, Gchatdemo1Web.StreamListOldLive, session: %{"streamer_name" => streamer_name, "current_user" => current_user})
  end
end
