defmodule Gchatdemo1Web.ConversationChannel do
  use Phoenix.Channel

  # Giả sử module Chat chứa logic tin nhắn
  alias Gchatdemo1.Messaging
  alias Gchatdemo1Web.UserActivityTracker
  alias Gchatdemo1Web.Presence
  # Khi client tham gia channel với topic "conversation:<conversation_id>"
  def join("conversation:" <> conversation_id, _params, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :conversation_id, conversation_id)}
  end

  # Xử lý khi client gửi tin nhắn qua sự kiện "new_message"
  def handle_in("new_message", payload, socket) do
    user_id = Map.get(socket.assigns, :user_id)
    conversation_id = Map.get(socket.assigns, :conversation_id)
    content = Map.get(payload, "content")
    reply_to_id = Map.get(payload, "reply_to_id")

    IO.inspect(payload, label: "📩 Received new_message payload")

    cond do
      !user_id ->
        IO.puts("❌ Không tìm thấy user_id trong socket.assigns!")
        {:reply, {:error, %{error: "User không hợp lệ"}}, socket}

      !content ->
        IO.puts("❌ Payload thiếu content: #{inspect(payload)}")
        {:reply, {:error, %{error: "Nội dung tin nhắn không được để trống"}}, socket}

      true ->
        opts = if reply_to_id, do: %{reply_to_id: reply_to_id}, else: %{}

        IO.puts(
          "📤 Gửi tin nhắn: user_id=#{user_id}, conversation_id=#{conversation_id}, content=#{content}, reply_to_id=#{reply_to_id || "nil"}"
        )

        case Messaging.send_message(user_id, conversation_id, content, opts) do
          {:ok, message} ->
            broadcast!(socket, "new_message", %{message: message})
            {:reply, {:ok, %{message: message}}, socket}

          {:error, :invalid_reply_to_id} ->
            IO.puts("❌ reply_to_id không hợp lệ: #{reply_to_id}")
            {:reply, {:error, %{error: "reply_to_id không hợp lệ"}}, socket}

          {:error, changeset} ->
            IO.inspect(changeset, label: "❌ Lỗi gửi tin nhắn")
            {:reply, {:error, %{error: "Không thể gửi tin nhắn", details: changeset}}, socket}
        end
    end
  end

  def handle_in("update_active", _params, socket) do
    user_id = Map.get(socket.assigns, :user_id)

    if user_id do
      # Cập nhật last_active_at khi nhận tín hiệu
      case UserActivityTracker.update_last_active(user_id) do
        {:ok, _user} ->
          {:reply, :ok, socket}

        {:error, reason} ->
          {:reply, {:error, %{error: "Không thể cập nhật trạng thái", details: reason}}, socket}
      end
    else
      IO.puts("❌ Không tìm thấy user_id trong socket.assigns!")
      {:reply, {:error, %{error: "User không hợp lệ"}}, socket}
    end
  end

  def handle_in(
        "mark_messages_as_seen",
        %{"conversation_id" => conv_id, "user_id" => user_id},
        socket
      ) do
    IO.puts("📩 Received mark_messages_as_seen for conversation #{conv_id} by user #{user_id}")

    case Messaging.mark_messages_as_seen(conv_id, user_id) do
      {:ok, count} when count > 0 ->
        IO.puts("✅ Updated #{count} messages as seen for conversation #{conv_id}")

        broadcast!(socket, "messages_seen", %{
          "conversation_id" => conv_id,
          "reader_id" => user_id
        })

        {:noreply, socket}

      {:ok, 0} ->
        IO.puts("ℹ️ No messages updated for conversation #{conv_id}")
        {:noreply, socket}

      {:error, reason} ->
        IO.puts("⚠️ Error marking messages as seen: #{inspect(reason)}")
        {:reply, {:error, %{reason: "Failed to mark messages as seen"}}, socket}
    end
  end

  def handle_in(
        "react_to_message",
        %{"message_id" => message_id, "emoji" => emoji},
        socket
      ) do
    user_id = get_in(socket.assigns, [:user_id])

    case Messaging.add_reaction(message_id, user_id, emoji) do
      {:ok, _reaction} ->
        updated_reactions = Messaging.get_reactions(message_id)

        broadcast(socket, "new_reaction", %{
          message_id: message_id,
          reactions: updated_reactions
        })

        {:noreply, socket}

      {:error, _reason} ->
        {:reply, {:error, %{error: "Failed to add reaction"}}, socket}
    end
  end

  def handle_in("mark_messages_as_seen", payload, socket) do
    IO.puts("⚠️ Invalid mark_messages_as_seen payload: #{inspect(payload)}")
    {:reply, {:error, %{message: "Invalid payload"}}, socket}
  end

  def handle_in("recall_message", %{"message_id" => message_id}, socket) do
    case Messaging.recall_message(message_id) do
      {:ok, recalled_message} ->
        broadcast(socket, "message_recalled", %{
          id: recalled_message.id,
          is_recalled: true,
          content: "Tin nhắn đã được thu hồi",
          # Thêm thông tin reactions rỗng
          reactions: []
        })

        {:noreply, socket}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "Không thể thu hồi tin nhắn"}}, socket}
    end
  end

  # Trong ConversationChannel
  def handle_in("pin_message", %{"message_id" => message_id}, socket) do
    user_id = socket.assigns[:user_id]
    conversation_id = socket.assigns[:conversation_id]

    case Messaging.pin_message(%{
           message_id: message_id,
           conversation_id: conversation_id,
           pinned_by: user_id
         }) do
      {:ok, pinned_message} ->
        broadcast!(socket, "message_pinned", %{message: pinned_message})
        {:reply, :ok, socket}

      {:error, :already_pinned} ->
        {:reply, {:error, %{reason: "Tin nhắn đã được ghim"}}, socket}
    end
  end

  def handle_in("unpin_message", %{"message_id" => message_id}, socket) do
    conversation_id = socket.assigns[:conversation_id]

    case Messaging.unpin_message(conversation_id, message_id) do
      {:ok, _} ->
        broadcast!(socket, "message_unpinned", %{message_id: message_id})
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: reason}}, socket}
    end
  end

  def handle_in("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    case Messaging.edit_message(message_id, content) do
      {:ok, edited_message} ->
        broadcast!(socket, "message_edited", edited_message)
        {:reply, {:ok, edited_message}, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{error: "Không thể chỉnh sửa tin nhắn"}}, socket}
    end
  end

  def handle_in("delete_message", %{"message_id" => message_id}, socket) do
    case Messaging.soft_delete_message(message_id) do
      {1, _} ->
        broadcast!(socket, "message_deleted", %{message_id: message_id})
        {:reply, :ok, socket}

      _ ->
        {:reply, {:error, %{reason: "Xóa tin nhắn thất bại"}}, socket}
    end
  end

  def handle_in("offer", %{"sdp" => sdp, "type" => type}, socket) do
    IO.puts("📤 Broadcast offer: #{sdp}")
    broadcast!(socket, "offer", %{sdp: sdp, type: type})
    {:noreply, socket}
  end

  def handle_in("answer", %{"sdp" => sdp, "type" => type}, socket) do
    IO.puts("📤 Broadcast answer: #{sdp}")
    broadcast!(socket, "answer", %{sdp: sdp, type: type})
    {:noreply, socket}
  end

  def handle_in("candidate", %{"candidate" => candidate}, socket) do
    IO.puts("📤 Broadcast candidate: #{inspect(candidate)}")
    broadcast!(socket, "candidate", %{candidate: candidate})
    {:noreply, socket}
  end

  def handle_in(
        "end_call",
        %{"status" => status, "started_at" => started_at, "ended_at" => ended_at},
        socket
      ) do
    user_id = socket.assigns[:user_id]
    conversation_id = socket.assigns[:conversation_id]
    callee_id = Messaging.get_conversation_friend(conversation_id, user_id)

    {:ok, started_at_dt, _} = DateTime.from_iso8601(started_at)
    {:ok, ended_at_dt, _} = DateTime.from_iso8601(ended_at)

    case Messaging.create_call_history(
           conversation_id,
           user_id,
           callee_id,
           status,
           started_at_dt,
           ended_at_dt
         ) do
      {:ok, call_history} ->
        # Broadcast lịch sử cuộc gọi
        broadcast!(socket, "new_call_history", %{call_history: call_history})
        # Broadcast sự kiện end_call để thông báo cho các client khác
        broadcast!(socket, "end_call", %{})
        IO.puts("Đã phát sự kiện end_call đến tất cả client")
        {:reply, :ok, socket}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "Không thể lưu lịch sử cuộc gọi"}}, socket}
    end
  end

  # Xử lý trường hợp payload rỗng
  def handle_in("end_call", %{}, socket) do
    IO.puts("Nhận sự kiện end_call nhưng không có dữ liệu, chỉ broadcast.")
    broadcast!(socket, "end_call", %{})
    {:noreply, socket}
  end

  def handle_in("call_rejected", %{"callee_id" => callee_id}, socket) do
    # ID của người gọi
    user_id = socket.assigns[:user_id]
    conversation_id = socket.assigns[:conversation_id]

    case Messaging.create_call_history(conversation_id, user_id, callee_id, "rejected") do
      {:ok, call_history} ->
        broadcast!(socket, "new_call_history", %{call_history: call_history})
        # Thông báo cuộc gọi bị từ chối
        broadcast!(socket, "call_rejected", %{})
        {:noreply, socket}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "Không thể lưu lịch sử cuộc gọi"}}, socket}
    end
  end

  def handle_info(:after_join, socket) do
    user_id = Map.get(socket.assigns, :user_id)

    if user_id do
      {:ok, _} =
        Presence.track(socket, to_string(user_id), %{
          online_at: DateTime.utc_now() |> DateTime.to_unix()
        })

      # 🔥 Đảm bảo gửi lại danh sách Presence
      push(socket, "presence_state", Presence.list(socket))
      IO.inspect(Presence.list(socket), label: "🔥 Presence list sent to client")
      IO.puts("✅ Tracked presence for user #{user_id} with online_at")
      UserActivityTracker.update_last_active(user_id)
    end

    {:noreply, socket}
  end
end
