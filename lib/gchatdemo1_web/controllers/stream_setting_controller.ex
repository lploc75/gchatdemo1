defmodule Gchatdemo1Web.StreamSettingController do
  use Gchatdemo1Web, :controller

  import Phoenix.LiveView.Controller

  require Logger

  def index(conn, %{"streamer_name" => streamer_name}) do
    current_user = conn.assigns[:current_user]
    if current_user do
      if current_user.display_name == streamer_name do
        live_render(conn, Gchatdemo1Web.StreamSettingLive, session: %{"streamer_name" => streamer_name,
                                                                    "current_user" => current_user})
      else
        redirect(conn, to: "/")
      end
    else
      redirect(conn, to: "/")
    end
  end
end
