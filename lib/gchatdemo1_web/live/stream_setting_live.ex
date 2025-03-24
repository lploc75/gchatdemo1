defmodule Gchatdemo1Web.StreamSettingLive do
  require Logger
  use Gchatdemo1Web, :live_view
  alias Gchatdemo1.{Repo, StreamSetting}

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", %{})
    streamer_id = current_user.id

    stream_setting = get_stream_setting_by_streamer_id(streamer_id)

    {:ok,
     assign(socket,
       streamer_id: streamer_id,
       stream_key: stream_setting && stream_setting.stream_key,
       title: stream_setting && stream_setting.title,
       description: stream_setting && stream_setting.description,
       update_success: nil,
       show_stream_key: false
     ), layout: false}
  end

  def handle_event("generate_stream_key", _params, socket) do
    stream_key = generate_stream_key()

    stream_setting =
      case get_stream_setting_by_streamer_id(socket.assigns.streamer_id) do
        nil -> create_stream_setting(socket.assigns.streamer_id, stream_key)
        stream_setting -> update_stream_key(stream_setting, stream_key)
      end

    {:noreply, assign(socket, stream_key: stream_setting.stream_key)}
  end

  def handle_event("view_stream_key", _params, socket) do
    if socket.assigns.show_stream_key do
      # Đang hiển thị -> Ẩn đi
      {:noreply, assign(socket, show_stream_key: false)}
    else
      # Đang ẩn -> Hiển thị Stream Key
      stream_setting = get_stream_setting_by_streamer_id(socket.assigns.streamer_id)
      stream_key = if stream_setting, do: stream_setting.stream_key, else: "Not Found"

      {:noreply, assign(socket, stream_key: stream_key, show_stream_key: true)}
    end
  end



  def handle_event(
        "update_stream_info",
        %{"title" => title, "description" => description},
        socket
      ) do
    case update_stream_info(socket.assigns.streamer_id, %{title: title, description: description}) do
      {:ok, updated_setting} ->
        socket =
          socket
          |> assign(title: updated_setting.title, description: updated_setting.description)
          # Gán trạng thái cập nhật thành công
          |> assign(:update_success, true)

        {:noreply, push_event(socket, "hide_notification", %{})}

      {:error, _} ->
        {:noreply, assign(socket, :update_success, false)}
    end
  end

  defp generate_stream_key do
    :crypto.strong_rand_bytes(12) |> Base.encode16() |> binary_part(0, 16)
  end

  defp get_stream_setting_by_streamer_id(streamer_id) do
    Repo.get_by(StreamSetting, streamer_id: streamer_id)
  end

  defp create_stream_setting(streamer_id, stream_key) do
    changeset =
      StreamSetting.changeset(%StreamSetting{}, %{
        streamer_id: streamer_id,
        stream_key: stream_key
      })

    case Repo.insert(changeset) do
      {:ok, stream_setting} -> stream_setting
      {:error, _} -> nil
    end
  end

  defp update_stream_key(stream_setting, stream_key) do
    changeset = StreamSetting.changeset(stream_setting, %{stream_key: stream_key})

    case Repo.update(changeset) do
      {:ok, updated_stream_setting} -> updated_stream_setting
      {:error, _} -> nil
    end
  end

  defp update_stream_info(streamer_id, attrs) do
    case get_stream_setting_by_streamer_id(streamer_id) do
      nil ->
        {:error, "Stream setting not found"}

      stream_setting ->
        stream_setting
        |> Ecto.Changeset.change(attrs)
        |> Repo.update()
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto bg-white shadow-lg rounded-lg p-6">
      <h2 class="text-2xl font-bold text-gray-800 mb-4 text-center">Stream Key Management</h2>

      <button
        phx-click="generate_stream_key"
        class="w-full mt-3 bg-blue-500 text-white py-2 rounded hover:bg-blue-600 transition"
      >
        Tạo Stream Key
      </button>

      <button
        phx-click="view_stream_key"
        class="w-full mt-3 bg-green-500 text-white py-2 rounded hover:bg-green-600 transition"
      >
        Xem Stream Key
      </button>

      <%= if @show_stream_key do %>
        <div class="p-4 bg-gray-100 rounded-lg text-center">
          <p class="text-gray-800 font-semibold">Stream Key của bạn:</p>
          <p id="stream-key" class="text-lg font-mono bg-gray-200 p-2 rounded mt-2">{@stream_key}</p>
        </div>
      <% end %>
    </div>
    """
  end

end
