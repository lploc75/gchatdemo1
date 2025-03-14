defmodule Gchatdemo1Web.VideoLive do
  use Phoenix.LiveView
  alias Gchatdemo1.Videos

  def mount(%{"id" => id}, _session, socket) do
    case Videos.get_video(id) do
      nil ->
        {:ok, socket |> put_flash(:error, "Video not found") |> redirect(to: "/")}

      video ->
        {:ok, assign(socket, :video, video)}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center p-6">
      <h2 class="text-3xl font-semibold text-center mb-4 text-gray-800">{@video.title}</h2>
      <p class="text-lg text-center mb-6 text-gray-600">{@video.description}</p>
      <div class="flex justify-center w-full">
        <video
          id="player"
          muted
          autoplay
          playsinline
          controls
          class="max-w-3/4 rounded-lg shadow-lg border-2 border-gray-200"
        >
          <source src={@video.url} type="video/mp4" />
        </video>
      </div>
    </div>
    """
  end
end
