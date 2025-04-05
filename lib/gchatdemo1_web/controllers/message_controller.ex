defmodule Gchatdemo1Web.MessageController do
  use Gchatdemo1Web, :controller
  alias Gchatdemo1.Messaging
  alias Gchatdemo1.Accounts

  def create(conn, params) do
    user = conn.assigns.current_user
    content = Map.get(params, "content", "")
    conv_id = Map.get(params, "conversation_id")
    # Mặc định là nil nếu không có
    reply_to_id = Map.get(params, "reply_to_id", nil)

    max_length = 2000

    if String.length(content) > max_length do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "Tin nhắn quá dài (tối đa #{max_length} ký tự)"})
    else
      case Messaging.send_message(user.id, conv_id, content, %{reply_to_id: reply_to_id}) do
        {:ok, message} ->
          topic = "conversation:#{conv_id}"
          Gchatdemo1Web.Endpoint.broadcast!(topic, "new_message", message)
          json(conn, %{success: true, message: message})

        {:error, _} ->
          json(conn, %{success: false, error: "Không thể gửi tin nhắn"})
      end
    end
  end

  @spec forward_message(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def forward_message(conn, %{"message_id" => message_id, "recipient_id" => recipient_id}) do
    current_user = conn.assigns.current_user

    # Chuyển đổi message_id và recipient_id thành integer nếu cần
    with {message_id_int, ""} <- parse_to_integer(message_id),
         {recipient_id_int, ""} <- parse_to_integer(recipient_id),
         {:ok, original_message} <- Messaging.get_message(message_id_int),
         {:ok, conversation_id} <-
           Messaging.get_or_create_conversation_forward(current_user.id, recipient_id_int),
         {:ok, forwarded_message} <-
           Messaging.send_message(
             current_user.id,
             conversation_id,
             "[Chuyển tiếp] #{original_message.content}",
             %{is_forwarded: true, original_sender_id: original_message.user_id}
           ) do
      # Gửi sự kiện new_message đến conversation
      Gchatdemo1Web.Endpoint.broadcast(
        "conversation:#{conversation_id}",
        "new_message",
        %{message: forwarded_message}
      )

      # Trả về JSON trực tiếp mà không cần message.json
      json(conn, %{
        id: forwarded_message.id,
        sender_id: forwarded_message.original_sender_id,
        content: forwarded_message.content,
        inserted_at: forwarded_message.inserted_at
      })
    else
      :invalid_integer ->
        json(conn |> put_status(:bad_request), %{error: "Invalid message_id or recipient_id"})

      {:error, reason} ->
        json(conn |> put_status(:bad_request), %{error: inspect(reason)})
    end
  end

  def forward_message(conn, _params) do
    json(conn |> put_status(:bad_request), %{error: "Missing message_id or recipient_id"})
  end

  # Hàm hỗ trợ để parse integer an toàn
  defp parse_to_integer(value) when is_integer(value), do: {value, ""}
  defp parse_to_integer(value) when is_binary(value), do: Integer.parse(value)
  defp parse_to_integer(_), do: :invalid_integer

  def show(conn, %{"conversation_id" => conv_id}) do
    current_user = conn.assigns.current_user
    conversation = Messaging.get_conversation(conv_id)
    messages = Messaging.list_messages(conv_id)

    # Xác định friend
    friend =
      if conversation && !conversation.is_group do
        members = conversation.group_members

        case Enum.find(members, fn member -> member.user_id != current_user.id end) do
          nil ->
            IO.puts(
              "⚠️ Không tìm thấy thành viên khác trong conversation 1-1 (ID: #{conversation.id})"
            )

            nil

          member ->
            IO.puts("✅ Tìm thấy thành viên: #{inspect(member)}")

            case Accounts.get_user(member.user_id) do
              nil ->
                IO.puts("⚠️ Không tìm thấy user với ID #{member.user_id}")
                nil

              user ->
                # Chỉ lấy các trường cần thiết
                Map.take(user, [:id, :email, :display_name, :avatar_url])
            end
        end
      else
        nil
      end

    # Tính trạng thái friend_status
    friend_status =
      if friend do
        Accounts.get_user_status(friend.id)
      else
        "offline"
      end

    # Chuyển đổi struct User thành map với các trường cần thiết
    messages =
      Enum.map(messages, fn message ->
        user = Map.take(message.user, [:id, :email, :display_name, :avatar_url])
        Map.put(message, :user, user)
      end)

    # Lấy danh sách tin nhắn được ghim
    pinned_messages =
      if conversation do
        Messaging.list_pinned_messages(conv_id)
      else
        []
      end

    call_history =
      if conversation do
        Messaging.list_call_history(conv_id)
      else
        []
      end

    json(conn, %{
      conversation: conversation,
      messages: messages,
      # Thêm friend vào response
      friend: friend,
      friend_status: friend_status,
      status: :ok,
      current_user: current_user,
      pinned_messages: pinned_messages,
      call_history: call_history
    })
  end
end
