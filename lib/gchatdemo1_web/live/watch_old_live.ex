defmodule Gchatdemo1Web.WatchOldLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Streams

  def mount(%{"display_name" => display_name, "stream_id" => stream_id}, _session, socket) do
    stream_info = Streams.get_stream_infor!(stream_id)
    streamer_id = Streams.get_streamer_id_by_name(display_name)
    stream_setting = Streams.get_stream_setting_for_user(streamer_id)

    {:ok,
     assign(socket,
       display_name: display_name,
       stream_info: stream_info,
       stream_setting: stream_setting
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-2xl font-bold">Xem Re-Stream của {@display_name}</h1>
      <div class="flex flex-col items-center justify-center p-6">
        <h2 class="text-3xl font-semibold text-center mb-4 text-gray-800">
          {@stream_setting.title}
        </h2>

        <div class="w-full max-w-5xl aspect-video">
          <!-- 🔥 Video với HLS Hook -->
          <video
            id="player"
            phx-hook="HLSPlayer"
            data-src={"/watch_restream/#{@display_name}/#{@stream_info.output_path}"}
            controls
            autoplay
            muted
            playsinline
            class="w-full h-full">
          </video>
        </div>

        <!-- 🔥 Dropdown chọn chất lượng -->
        <div class="mt-4">
          <label for="quality-selector" class="mr-2">🔧 Chất lượng:</label>
          <select id="quality-selector" class="border p-2 rounded"></select>
        </div>

        <p class="text-lg text-center mb-6 text-gray-600">
          {@stream_setting.description}
        </p>
      </div>
    </div>
    """
  end

end
