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

  def handle_in(
        "new_message",
        %{
          "content" => content,
          "user_id" => sender_id,
          "reply_to_id" => reply_to_id,
          "reply_to_message" => reply_to_message
        },
        socket
      ) do
    IO.puts("🔥 Received new message")

    group_id = socket.assigns.group_id
    user_email = Accounts.get_user!(sender_id).email
    avatar_url = Accounts.get_user!(sender_id).avatar_url

    case Chat.send_message(sender_id, group_id, content, reply_to_id) do
      {:ok, message} ->
        message =
          Gchatdemo1.Repo.preload(message, [
            :reactions,
            :message_statuses,
            :conversation,
            :user,
            :reply_to,
            :original_sender
          ])

        message_statuses = Chat.get_message_statuses(message.id)

        broadcast!(socket, "new_message", %{
          message: %{
            user_id: message.user_id,
            id: message.id,
            content: message.content,
            reply_to_message: reply_to_message,
            message_status: message_statuses
          },
          sender: "me",
          email: user_email,
          avatar_url: avatar_url
        })

        # Trả về message đã preload
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
        broadcast!(socket, "reaction_removed", %{
          "message_id" => message_id,
          "user_id" => user_id,
          "emoji" => emoji
        })

        {:noreply, socket}

      {:error, reason} ->
        IO.inspect(reason, label: "🔍 Error in remove_reaction")
        {:reply, {:error, reason}, socket}
    end
  end

  def handle_in(
        "pin_message",
        %{"message_id" => message_id, "conversation_id" => conversation_id},
        socket
      ) do
    user_id = socket.assigns.user_id

    case Chat.pin_message(%{
           message_id: message_id,
           conversation_id: conversation_id,
           pinned_by: user_id
         }) do
      {:ok, pinned_message} ->
        broadcast!(socket, "message_pinned", %{message: pinned_message})
        {:reply, {:ok, pinned_message}, socket}

      # Lỗi (quá 3 tin nhắn ghim)
      {:error, msg} ->
        {:reply, {:error, msg}, socket}
    end
  end

  def handle_in(
        "unpin_message",
        %{"message_id" => message_id, "conversation_id" => conversation_id},
        socket
      ) do
    case Chat.unpin_message(message_id, conversation_id) do
      {count, _} when count > 0 ->
        broadcast!(socket, "message_unpinned", %{
          message_id: message_id,
          conversation_id: conversation_id
        })

        {:reply, {:ok, %{message_id: message_id}}, socket}

      _ ->
        {:reply, {:error, "Không tìm thấy tin nhắn ghim hoặc đã bị xóa!"}, socket}
    end
  end

  # Nhận tin nhắn từ client
  def handle_in(
        "typing",
        %{
          "conversation_id" => conversation_id,
          "user_id" => user_id,
          "user_email" => user_email,
          "user_displayName" => display_name,
          "user_avatar_url" => avatar_url
        },
        socket
      ) do
    # Broadcast đến tất cả user trong phòng (ngoại trừ người gửi)
    broadcast!(socket, "user_typing", %{
      conversation_id: conversation_id,
      user_id: user_id,
      user_email: user_email,
      user_displayName: display_name,
      user_avatar_url: avatar_url
    })

    {:noreply, socket}
  end
end
