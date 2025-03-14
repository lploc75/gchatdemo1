defmodule Gchatdemo1Web.StreamController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Streams

  def stream(conn, %{"streamer_name" => stream_name}) do
    case Streams.get_streamer_id_by_name(stream_name) do
      nil ->
        conn
          |> put_status(:not_found)
          |> put_view(Gchatdemo1Web.ErrorHTML)
          |> render("not_user.html", streamer_name: stream_name)

      streamer_id ->
        if Streams.is_streamer(streamer_id) do
          IO.puts("lỗi")
          case Streams.get_stream_by_streamer_id(streamer_id) do
            nil -> render(conn, :stream, stream_infor: nil)
            stream_infor -> render(conn, :stream, stream_infor: stream_infor)
          end
        else
          conn
          |> put_status(:not_found)
          |> put_view(Gchatdemo1Web.ErrorHTML)
          |> render("error.html", streamer_name: stream_name)
        end
    end
  end

end
