defmodule Gchatdemo1Web.StreamNowListLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Streams

  def mount(_params, _session, socket) do
    stream_list = Streams.get_all_stream_now()

    enriched_streams =
      Enum.map(stream_list, fn stream ->
        setting = Streams.get_stream_setting_for_user(stream.streamer_id) || %{}
        user = Gchatdemo1.Accounts.get_user(stream.streamer_id) || %{}

        Map.merge(stream, setting)
        |> Map.put(:display_name, user.display_name || "Unknown")
      end)

    IO.inspect(enriched_streams, label: "Stream list information")

    {:ok, assign(socket, stream_list: enriched_streams)}
  end


  def render(assigns) do
    ~H"""
    <div class="container mx-auto p-4">
      <h1 class="text-2xl font-bold mb-4">Live Streams</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for stream <- @stream_list do %>
          <div class="bg-white rounded-lg shadow-lg p-4">
            <h2 class="text-xl font-semibold text-gray-800">
              {stream.title || "No Title"}
            </h2>
            <p class="text-gray-600">
              {stream.description || "No Description"}
            </p>
            <a
              href={"/stream/#{stream.display_name}"}
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
