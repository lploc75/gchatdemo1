defmodule Gchatdemo1Web.StreamerListLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Streams

  def mount(_params, _session, socket) do
    streamers = Streams.get_all_streamer_name()
    {:ok, assign(socket, streamers: streamers)}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-6">
      <h1 class="text-2xl font-bold mb-4 text-center">Danh sách Streamer</h1>
      <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-6">
        <%= for streamer <- @streamers do %>
          <a href={"/watch/#{streamer.streamer_name}"}
             class="flex flex-col items-center p-4 bg-white shadow-lg rounded-lg hover:bg-gray-100 transition">
            <img src={streamer.avatar_url} alt={streamer.streamer_name}
                 class="w-24 h-24 rounded-full object-cover border-4 border-blue-500 shadow-md" />
            <span class="mt-3 text-lg font-semibold text-blue-600 text-center">
              <%= streamer.streamer_name %>
            </span>
          </a>
        <% end %>
      </div>
    </div>
    """
  end
end
