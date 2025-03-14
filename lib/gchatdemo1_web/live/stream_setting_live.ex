defmodule Gchatdemo1Web.StreamSettingLive do
  require Logger
  use Gchatdemo1Web, :live_view
  alias Gchatdemo1.{Repo, StreamSetting}

  def mount(_params, session, socket) do
    current_user = Map.get(session, "current_user", %{})
    streamer_id = current_user.id

    {:ok, assign(socket, streamer_id: streamer_id, stream_key: nil), layout: false}
  end

  def handle_event("generate_stream_key", _params, socket) do
    stream_key = generate_stream_key()

    stream_setting =
      case get_stream_key_by_streamer_id(socket.assigns.streamer_id) do
        nil -> create_stream_setting(socket.assigns.streamer_id, stream_key)
        stream_setting -> update_stream_key(stream_setting, stream_key)
      end

    {:noreply, assign(socket, stream_key: stream_setting.stream_key)}
  end

  def handle_event("view_stream_key", _params, socket) do
    stream_setting = get_stream_key_by_streamer_id(socket.assigns.streamer_id)
    stream_key = if stream_setting, do: stream_setting.stream_key, else: "Not Found"

    {:noreply, assign(socket, stream_key: stream_key)}
  end

  def handle_event("copy_stream_key", _, socket) do
    {:noreply, push_event(socket, "copy_stream_key", %{stream_key: socket.assigns.stream_key})}
  end

  defp generate_stream_key do
    :crypto.strong_rand_bytes(12) |> Base.encode16() |> binary_part(0, 16)
  end

  defp get_stream_key_by_streamer_id(streamer_id) do
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

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto bg-white shadow-lg rounded-lg p-6">
      <h2 class="text-2xl font-bold text-gray-800 mb-4 text-center">Stream Key Management</h2>

      <button
        phx-click="generate_stream_key"
        class="w-full mt-3 bg-blue-500 text-white py-2 rounded hover:bg-blue-600 transition"
      >
        Generate Stream Key
      </button>

      <button
        phx-click="view_stream_key"
        class="w-full mt-3 bg-green-500 text-white py-2 rounded hover:bg-green-600 transition"
      >
        View Stream Key
      </button>

      <%= if @stream_key do %>
        <div class="p-4 bg-gray-100 rounded-lg text-center">
          <p class="text-gray-800 font-semibold">Your Stream Key:</p>
          <p id="stream-key" class="text-lg font-mono bg-gray-200 p-2 rounded mt-2">{@stream_key}</p>
          <button
            phx-click="copy_stream_key"
            class="mt-3 bg-yellow-500 text-white py-2 px-4 rounded hover:bg-yellow-600 transition"
          >
            Copy
          </button>
        </div>
      <% end %>
    </div>

    <script>
      window.addEventListener("phx:copy_stream_key", (e) => {
        navigator.clipboard.writeText(e.detail.stream_key).then(() => {
          alert("Stream Key copied!");
        });
      });
    </script>
    """
  end
end
