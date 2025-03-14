defmodule Gchatdemo1Web.HlsController do
  use Gchatdemo1Web, :controller

  alias Plug
  require Logger

  def index(conn, %{"filename" => filename_parts}) do
    filename = Path.join(filename_parts)

    path = Path.join(["output", filename])

    if File.exists?(path) do
      conn |> Plug.Conn.send_file(200, path)
    else
      conn |> Plug.Conn.send_resp(404, "File not found")
    end
  end

  def watch(conn, %{"streamer_name" => _streamer_name, "stream_id" => stream_id, "filename" => filename}) do

    path = Path.join(["output", stream_id, filename])
    IO.puts(path)
    if File.exists?(path) do
      conn |> Plug.Conn.send_file(200, path)
    else
      conn |> Plug.Conn.send_resp(404, "File not found")
    end
  end


end
