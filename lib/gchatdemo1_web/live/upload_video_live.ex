defmodule Gchatdemo1Web.UploadVideoLive do
  use Gchatdemo1Web, :live_view

  def render(assigns) do
    ~H"""
    <div class="max-w-lg mx-auto p-6 bg-white rounded-2xl shadow-lg space-y-6">
      <h1 class="text-3xl font-bold text-gray-900 text-center">Upload Video</h1>
      <form phx-submit="upload_video" class="mt-4 space-y-4">
        <input
          type="text"
          name="title"
          placeholder="Nhập tiêu đề"
          class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          required
        />

        <textarea
          name="description"
          placeholder="Nhập mô tả"
          class="w-full px-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:outline-none"
          required
        ></textarea>

        <input
          type="file"
          name="file"
          accept="video/*"
          class="w-full text-sm text-gray-900 border border-gray-300 rounded-lg cursor-pointer bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500"
          required
        />

        <button
          type="submit"
          class="w-full bg-blue-600 hover:bg-blue-700 text-white font-bold py-3 px-5 rounded-xl transition"
        >
          Upload & Lưu Video
        </button>
      </form>

      <div class="mt-6 text-center">
        <a
          href="/"
          class="w-full bg-gray-600 hover:bg-gray-700 text-white font-bold py-3 px-5 rounded-xl transition"
        >
          Quay lại trang chính
        </a>
      </div>
    </div>
    """
  end

  def handle_event("upload_video", %{"title" => title, "description" => description, "file" => _file}, socket) do
    IO.puts("Uploading video: #{title}")
    {:noreply, socket}
  end
end
