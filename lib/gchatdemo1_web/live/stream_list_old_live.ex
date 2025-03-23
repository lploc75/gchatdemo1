defmodule Gchatdemo1Web.StreamListOldLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.{Streams, Accounts}

  def mount(_params, session, socket) do
    streamer_name = Map.get(session, "streamer_name", "unknown")
    current_user = Map.get(session, "current_user", %{}) # ✅ Lấy `current_user` từ session

    stream_list = Streams.get_all_stream_old()

    enriched_streams =
      Enum.map(stream_list, fn stream ->
        setting = Streams.get_stream_setting_for_user(stream.streamer_id) || %{}
        user = Accounts.get_user(stream.streamer_id) || %{}

        Map.merge(stream, setting)
        |> Map.put(:display_name, user.display_name || "Unknown")
      end)

    {:ok, assign(socket,
      stream_list: enriched_streams,
      streamer_name: streamer_name,
      current_user: current_user
    ), layout: false}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-2xl font-bold mb-4">ReStream {@streamer_name}</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for stream <- @stream_list do %>
          <div class="bg-white rounded-lg shadow-lg p-4">
            <h2 class="text-xl font-semibold text-gray-800">
              {stream.stream_id || "No Stream Number"}: {stream.title || "No Title"}
            </h2>
            <p class="text-gray-600">
              {stream.description || "No Description"}
            </p>

            <a
              href={"/watch/#{stream.display_name}/#{stream.stream_id}"}
              class="mt-2 inline-block px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600"
            >
              Watch Now
            </a>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
