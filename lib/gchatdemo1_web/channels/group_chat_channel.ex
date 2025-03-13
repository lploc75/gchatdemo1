defmodule Gchatdemo1Web.GroupChatChannel do
  use Phoenix.Channel
  alias Gchatdemo1.Chat
  alias Gchatdemo1.Accounts

  def join("group_chat:" <> group_id, _params, socket) do
    # Lấy user_id từ socket
    user_id = socket.assigns[:user_id]

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
          message: %{
            # Thêm id vào trong message
            id: message.id,
            content: message.content
          },
          # Gửi "me" hoặc "other"
          sender: sender,
          # Gửi email cùng với tin nhắn
          email: user_email
        })

        {:reply, {:ok, %{status: "sent", message: message}}, socket}

      {:error, reason} ->
        {:reply, {:error, %{status: "failed", reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("recall_message", %{"message_id" => message_id}, socket) do
    user_id = socket.assigns.user_id
    IO.puts("📢 User #{user_id} yêu cầu thu hồi tin nhắn #{message_id}")

    case Chat.recall_message(message_id, user_id) do
      {:ok, message} ->
        IO.puts("✅ Tin nhắn #{message_id} đã được thu hồi")
        # Gửi sự kiện về tất cả client trong nhóm chat
        broadcast!(socket, "message_recalled", %{message_id: message.id})
        {:reply, {:ok, %{status: "recalled"}}, socket}

      {:error, reason} ->
        IO.puts("❌ Không thể thu hồi tin nhắn #{message_id}: #{inspect(reason)}")
        {:reply, {:error, %{status: "failed", reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    user_id = socket.assigns.user_id
    IO.puts("User #{user_id} yêu cầu xóa tin nhắn #{message_id}")

    case Chat.delete_message(message_id, user_id) do
      {:ok, message} ->
        IO.puts("✅ Tin nhắn #{message_id} đã được xóa")
        # Gửi sự kiện về tất cả client trong nhóm chat
        broadcast!(socket, "message_deleted", %{message_id: message.id})
        {:reply, {:ok, %{status: "deleted"}}, socket}

      {:error, reason} ->
        IO.puts("❌ Không thể xóa tin nhắn #{message_id}: #{inspect(reason)}")
        {:reply, {:error, %{status: "failed", reason: inspect(reason)}}, socket}
    end
  end

  def handle_in("edit_message", %{"id" => message_id, "content" => new_content}, socket) do
    user_id = socket.assigns.user_id

    case Chat.edit_message(user_id, message_id, new_content) do
      # Xử lý đúng cấu trúc giá trị trả về
      {:ok, {:ok, message}} ->
        broadcast!(socket, "message_edited", %{
          message_id: message.id,
          new_content: message.content
        })

        {:reply, {:ok, %{message: message}}, socket}

      {:error, reason} ->
        {:reply, {:error, reason}, socket}
    end
  end
  def handle_in("add_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.user_id

    case Chat.create_reaction(user_id, message_id, emoji) do
      {:ok, _reaction} ->
        broadcast!(socket, "reaction_added", %{
          message_id: message_id,
          user_id: user_id,
          emoji: emoji
        })

        {:reply, :ok, socket}

      {:error, _reason} ->
        {:reply, {:error, "Failed to add reaction"}, socket}
    end
  end


  def handle_in("remove_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.user_id

    case Chat.remove_reaction(message_id, user_id, emoji) do
      {:ok, _} ->
        broadcast!(socket, "reaction_removed", %{"message_id" => message_id, "user_id" => user_id, "emoji" => emoji})
        {:noreply, socket}

      {:error, reason} ->
        IO.inspect(reason, label: "🔍 Error in remove_reaction")
        {:reply, {:error, reason}, socket}
    end
  end
end
