defmodule Gchatdemo1Web.StreamController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Accounts
  alias Gchatdemo1.Streams

  def stream(conn, %{"streamer_name" => stream_name}) do
    case Streams.get_streamer_id_by_name(stream_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Streamer not found"})

      streamer_id ->
        if Streams.is_streamer(streamer_id) do
          case Streams.get_stream_by_streamer_id(streamer_id) do
            nil ->
              json(conn, %{stream: nil})

            stream_info ->
              # Convert struct -> Map
              stream_map = Map.from_struct(stream_info) |> Map.drop([:__meta__])
              settings = Streams.get_stream_setting_for_user(streamer_id) || %{}

              json(conn, %{
                # Merge dữ liệu stream + settings
                stream: Map.merge(stream_map, settings)
              })
          end
        else
          conn
          |> put_status(:not_found)
          |> json(%{error: "Not a streamer"})
        end
    end
  end

  # Lấy stream key
  def show(conn, %{"streamer_name" => streamer_name}) do
    case Streams.get_streamer_id_by_name(streamer_name) do
      nil ->
        json(conn, %{error: "Streamer không tồn tại"})

      streamer_id ->
        case Streams.get_stream_key_by_streamer_id(streamer_id) do
          nil -> json(conn, %{error: "Chưa có stream key"})
          stream_key -> json(conn, %{stream_key: stream_key})
        end
    end
  end

  # Tạo/Cập nhật stream key
  def create(conn, %{"streamer_name" => streamer_name}) do
    case Streams.get_streamer_id_by_name(streamer_name) do
      nil ->
        json(conn, %{error: "Streamer không tồn tại"})

      streamer_id ->
        case Streams.save_stream_key(streamer_id) do
          {:ok, stream_key} -> json(conn, %{stream_key: stream_key})
          {:error, message} -> json(conn, %{error: message})
        end
    end
  end

  def check_stream_mode(conn, %{"streamer_name" => streamer_name}) do
    case Streams.get_streamer_id_by_name(streamer_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Streamer not found"})

      streamer_id ->
        is_streamer = Streams.turn_on_stream_mode?(streamer_id)
        json(conn, %{streamer_id: streamer_id, is_streamer: is_streamer})
    end
  end

  def toggle_role(conn, %{"user_id" => user_id}) do
    case Streams.toggle_role(user_id) do
      {:ok, user} -> json(conn, %{message: "Role updated", role: user.role})
      {:error, _changeset} -> json(conn, %{error: "Failed to update role"})
    end
  end

  # Lấy all stream hiện tại
  def list_active_streams(conn, _params) do
    streams = Streams.get_all_stream_now()
    streamers = Streams.get_all_streamer_name()

    # Ghép dữ liệu streamer_name vào streams dựa trên streamer_id
    enriched_streams =
      Enum.map(streams, fn stream ->
        streamer =
          Enum.find(streamers, fn s -> s.streamer_id == stream.streamer_id end) ||
            %{
              streamer_name: "Unknown",
              avatar_url: nil
            }

        Map.merge(stream, %{
          streamer_name: streamer.streamer_name,
          avatar_url: streamer.avatar_url
        })
      end)

    json(conn, %{streams: enriched_streams})
  end

  # API lấy danh sách tất cả các streamer có role = 2
  def list_streamers(conn, _params) do
    streamers = Streams.get_all_streamer_name()
    json(conn, %{streamers: streamers})
  end

  # API lấy danh sách stream cũ theo streamer_name
  def get_old_streams(conn, %{"streamer_name" => streamer_name}) do
    case Streams.get_streamer_id_by_name(streamer_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Streamer not found"})

      streamer_id ->
        streams = Streams.get_all_stream_old()
        |> Enum.filter(fn stream -> stream.streamer_id == streamer_id end)

        json(conn, %{streams: streams})
    end
  end

  def update_stream_setting(conn, %{"streamer_name" => streamer_name, "title" => title, "description" => description}) do
    case Streams.get_streamer_id_by_name(streamer_name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Streamer not found"})

      streamer_id ->
        case Streams.update_stream_setting_for_user(streamer_id, %{title: title, description: description}) do
          {:ok, _stream_setting} ->
            json(conn, %{message: "Cập nhật thành công"})

          {:error, reason} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: reason})
        end
    end
  end

  def get_video_info(conn, %{"stream_id" => stream_id}) do
    case Streams.get_stream_infor!(stream_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Stream không tồn tại"})

      stream ->
        case Accounts.get_user(stream.streamer_id) do
          nil ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "Streamer không tồn tại"})

          streamer ->
            stream_setting = Streams.get_stream_setting_for_user(stream.streamer_id) || %{}

            json(conn, %{
              streamer_id: stream.streamer_id,
              streamer_name: streamer.display_name,
              title: stream_setting.title || "Không có tiêu đề",
              description: stream_setting.description || "Không có mô tả",
              source: stream.output_path
            })
        end
    end
  end

  def get_streamer_id(conn, %{"name" => streamer_name}) do
    case Streams.get_streamer_id_by_name(streamer_name) do
      nil -> json(conn, %{error: "Streamer not found"})
      streamer_id -> json(conn, %{id: streamer_id})
    end
  end

end
