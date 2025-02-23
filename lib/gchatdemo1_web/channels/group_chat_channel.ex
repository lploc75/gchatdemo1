defmodule Gchatdemo1Web.GroupChatChannel do
  use Phoenix.Channel
  alias Gchatdemo1.Chat
  alias Gchatdemo1.Accounts  # Giả sử mô hình người dùng của bạn nằm trong module Accounts

  def join("group_chat:" <> group_id, _params, socket) do
    user_id = socket.assigns[:user_id] # Lấy user_id từ socket

    if Chat.is_member?(group_id, user_id) do
      IO.puts("📢 User #{user_id} vào nhóm #{group_id}")
      {:ok, assign(socket, :group_id, group_id)}
    else
      {:error, %{reason: "not_allowed"}}
    end
  end

def handle_in("new_message", %{"content" => content}, socket) do
  IO.puts("🔥 Received new message")
  user_id = socket.assigns.user_id
  group_id = socket.assigns.group_id
  user_email = Accounts.get_user!(user_id).email

  # Xác định sender
  sender = if user_id == socket.assigns.user_id, do: "me", else: "other"

  case Chat.send_message(user_id, group_id, content) do
    {:ok, message} ->
      broadcast!(socket, "new_message", %{
        message: %{content: message.content},
        sender: sender,  # Gửi "me" hoặc "other" thay vì user_id
        email: user_email  # Gửi email cùng với tin nhắn
      })

      {:reply, {:ok, %{status: "sent", message: message}}, socket}

    {:error, reason} ->
      {:reply, {:error, %{status: "failed", reason: inspect(reason)}}, socket}
  end
end


end
