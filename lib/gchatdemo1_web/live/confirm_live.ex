defmodule Gchatdemo1Web.ConfirmLive do
  use Gchatdemo1Web, :live_view

  @topic "confirm_modal"

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(Gchatdemo1.PubSub, @topic)
    {:ok, assign(socket, show_modal: false, parent_pid: nil), layout: false}
  end

  def handle_info({:show_modal, parent_pid}, socket) do
    {:noreply, assign(socket, show_modal: true, parent_pid: parent_pid)}
  end

  def handle_event("confirm", _, socket) do
    send(socket.assigns.parent_pid, {:modal_result, true})
    {:noreply, assign(socket, show_modal: false)}
  end

  def handle_event("cancel", _, socket) do
    send(socket.assigns.parent_pid, {:modal_result, false})
    {:noreply, assign(socket, show_modal: false)}
  end

  def render(assigns) do
    ~H"""
    <%= if @show_modal do %>
      <div class="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50">
        <div class="bg-white p-4 rounded shadow">
          <p>Xác nhận stream nếu không hãy đợi 1 phút stream tự ngắt kết nối với OBS.<br>Nếu vẫn lỗi thì kiểm tra lại stream_key</p>
          <div class="flex justify-end space-x-2 mt-4">
            <button phx-click="confirm" class="bg-green-500 text-white px-4 py-2 rounded">Có</button>
            <button phx-click="cancel" class="bg-gray-500 text-white px-4 py-2 rounded">Hủy</button>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

end
