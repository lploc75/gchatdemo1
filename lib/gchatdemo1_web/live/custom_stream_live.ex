defmodule Gchatdemo1Web.CustomStreamLive do
  use Gchatdemo1Web, :live_view

  @topic "video_status"
  require Logger

  def mount(_params, session, socket) do
    Phoenix.PubSub.subscribe(Gchatdemo1.PubSub, @topic)

    current_user = Map.get(session, "current_user", "unknown")
    streamer_name = current_user.display_name

    case Gchatdemo1.Streams.get_streamer_id_by_name(streamer_name) do
      nil ->
        Logger.error("Không tìm thấy streamer")
        {:ok, push_navigate(socket, to: "/")}

      streamer_id ->
        Logger.info("Streamer ID: #{streamer_id}")

        if Gchatdemo1.Streams.turn_on_stream_mode?(streamer_id) do
          Logger.info("Streamer hợp lệ")

          {:ok,
           assign(socket,
             loading: false,
             layout: false,
             invalid_streamer: false,
             streamer_id: streamer_id,
             streamer_name: streamer_name
           )}
        else
          Logger.error("Streamer không hợp lệ - cần đổi sang Streamer Mode")
          {:ok, assign(socket, invalid_streamer: true, streamer_id: streamer_id, layout: false)}
        end
    end
  end

  def handle_event("toggle_streamer_mode", _, socket) do
    streamer_id = socket.assigns.streamer_id

    case Gchatdemo1.Streams.toggle_role(streamer_id) do
      :ok ->
        Logger.info("Chuyển đổi thành công")

        {:noreply,
         assign(socket, invalid_streamer: false, loading: false, download_url: nil, layout: false)}

      :error ->
        Logger.error("Chuyển đổi thất bại")
        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto p-6 bg-white rounded-2xl shadow-lg space-y-6">
      <%= if @invalid_streamer do %>
        <div class="text-center">
          <p class="text-red-600 font-bold text-lg">Bạn chưa có quyền stream!</p>
          <button
            phx-click="toggle_streamer_mode"
            class="mt-4 w-full bg-red-600 hover:bg-red-700 text-white font-semibold py-3 px-6 rounded-xl transition"
          >
            Đổi sang Streamer Mode
          </button>
        </div>
      <% else %>
        <h1 class="text-3xl font-bold text-gray-900 text-center">Quản lý Stream</h1>

        <div class="flex justify-center gap-4">
          <a
            href={"/stream_key/#{@streamer_name}"}
            target="_blank"
            class="px-5 py-2 bg-blue-500 text-white font-semibold rounded-lg shadow-md hover:bg-blue-700 transition"
          >
            Cài đặt Stream Key
          </a>
        </div>

        <div class="mt-6 text-center space-y-3">
          <a
            href={"/watch/#{@streamer_name}"}
            class="w-full px-5 py-3 bg-yellow-500 text-white font-semibold rounded-lg shadow-md hover:bg-blue-600 transition"
          >
            Danh sách Stream của bạn
          </a>
        </div>

        <div class="mt-6 text-center">
          <button
            phx-click="toggle_streamer_mode"
            class="w-full bg-red-600 hover:bg-red-700 text-white font-bold py-3 px-5 rounded-xl transition"
          >
            Tắt Streamer Mode
          </button>
        </div>
      <% end %>
    </div>

    {live_render(@socket, Gchatdemo1Web.ConfirmLive, id: "confirm-modal")}

    <script>
      window.addEventListener("show_confirm_modal", () => {
      document.getElementById("confirm-modal").style.display = "block";
      });

      window.addEventListener("hide_confirm_modal", () => {
      document.getElementById("confirm-modal").style.display = "none";
      });
    </script>
    """
  end
end
