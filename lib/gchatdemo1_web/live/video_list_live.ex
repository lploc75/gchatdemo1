defmodule Gchatdemo1Web.VideoListLive do
  use Phoenix.LiveView
  alias Gchatdemo1.Videos

  def render(assigns) do
    ~H"""
    <%= for video <- @videos do %>
      <a
        href={"/watch_video/#{video.id}"}
        class="block p-4 mb-6 bg-white rounded-lg shadow-lg hover:bg-gray-100 mx-auto text-center"
      >
        <h2 class="text-xl font-semibold text-gray-800 mb-2">{video.title}</h2>
        <p class="text-gray-600 mb-4">{video.description}</p>
        <video controls class="w-full max-w-xs rounded-lg border-2 border-gray-200 mx-auto">
          <source src={video.url} type="video/mp4" />
        </video>
      </a>
    <% end %>
    """
  end

  def mount(_params, _session, socket) do
    # Giả sử bạn có hàm này lấy dữ liệu video
    videos = Videos.all_videos()
    {:ok, assign(socket, videos: videos)}
  end
end
