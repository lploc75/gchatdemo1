defmodule Gchatdemo1Web.MessageLive do
  use Gchatdemo1Web, :live_view
  alias Gchatdemo1.Messaging
  alias Gchatdemo1.Accounts

  # Hàm mount dùng cho action :chat
  def mount(params, session, socket) do
    current_user =
      case socket.assigns[:current_user] do
        nil ->
          if user_id = Map.get(session, "user_id") do
            Accounts.get_user(user_id)
          else
            nil
          end

        user ->
          user
      end

    if current_user do
      # Lấy conversation_id từ params và chuyển đổi thành số nguyên
      conversation_id =
        case Map.get(params, "conversation_id") || Map.get(params, "to") do
          "new" -> nil
          id when is_binary(id) -> String.to_integer(id)
          id -> id
        end

      socket = assign(socket, conversation_id: conversation_id)
      # Nếu có conversation_id, lấy conversation và preload thành viên (group_members)
      conversation =
        if conversation_id do
          Messaging.get_conversation(conversation_id)
        else
          nil
        end

      call_history =
        if conversation_id do
          Messaging.list_call_history(conversation_id)
        else
          []
        end

      # Nếu conversation là cuộc trò chuyện 1-1 (không group), lấy friend là thành viên khác
      # Trong hàm mount, phần xử lý friend
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
                  user
              end
          end
        else
          nil
        end

      friend_status =
        if friend do
          Accounts.get_user_status(friend.id)
        else
          "offline"
        end

      messages =
        if conversation_id do
          # Giả sử list_messages/1 được cập nhật để lấy tin nhắn theo conversation_id
          Messaging.list_messages(conversation_id)
        else
          []
        end

      # Gộp messages và call_history thành một danh sách chung
      combined_items =
        (messages ++ call_history)
        |> Enum.sort_by(& &1.inserted_at, :asc)

      if connected?(socket) and conversation_id do
        topic = chat_topic(conversation_id)
        # Thêm dòng này
        IO.puts("Subscribing to topic: #{topic}")
        # Subscribe vào topic chat
        Gchatdemo1Web.Endpoint.subscribe(topic)
        call_topic = "call:#{conversation_id}"
        # Thêm dòng này
        Gchatdemo1Web.Endpoint.subscribe(call_topic)

        # Debug log
        IO.puts("Subscribed to topics: #{topic} and #{call_topic}")

        # Sau đó gửi sự kiện đánh dấu tin nhắn là "đã xem" (để bên nhận gửi về bên gửi thông báo)
        send(self(), :mark_messages_as_seen)
      end

      Gchatdemo1Web.UserActivityTracker.update_last_active(current_user)

      pinned_messages =
        if conversation_id do
          Messaging.list_pinned_messages(conversation_id)
        else
          []
        end

      {:ok,
       assign(socket,
         current_user: current_user,
         messages: combined_items,
         conversation_id: conversation_id,
         friend: friend,
         friend_status: friend_status,
         # Thêm dòng này
         show_forward_modal: false,
         # Thêm cả friends nếu chưa có
         # Lấy danh sách bạn bè từ DB thay vì gán rỗng
         friends: Accounts.list_friends(current_user.id),
         show_emoji_picker: nil,
         forward_message: nil,
         show_search: false,
         filtered_messages: messages,
         search_query: "",
         # Thêm expanded_messages vào đây
         expanded_messages: %{},
         pinned_messages: pinned_messages,
         replying_to: nil,
         call_state: :idle,
         local_video: nil,
         remote_video: nil,
         call_started_at: nil,
         status: nil,
         search_items: messages
       )}
    else
      {:ok, redirect(socket, to: "/")}
    end
  end

  # Hàm xử lý sự kiện gửi tin nhắn
  def handle_event("send_message", %{"content" => content}, socket) do
    current_user = socket.assigns.current_user
    conversation_id = socket.assigns.conversation_id
    max_length = 2000

    if String.length(content) > max_length do
      {:noreply, put_flash(socket, :error, "Tin nhắn quá dài (tối đa #{max_length} ký tự)")}
    else
      reply_to_id = socket.assigns[:replying_to] && socket.assigns.replying_to.id

      case Messaging.send_message(current_user.id, conversation_id, content, %{
             reply_to_id: reply_to_id
           }) do
        {:ok, message} ->
          topic = chat_topic(conversation_id)
          Gchatdemo1Web.Endpoint.broadcast!(topic, "new_message", %{message: message})
          {:noreply, assign(socket, replying_to: nil)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Không thể gửi tin nhắn")}
      end
    end
  end

  def handle_event("recall_message", %{"message_id" => message_id}, socket) do
    case Messaging.recall_message(message_id) do
      {:ok, recalled_message} ->
        # Xóa luôn các emoji đã được thả
        recalled_message = %{recalled_message | reactions: []}

        updated_messages =
          Enum.map(socket.assigns.messages, fn msg ->
            if msg.id == recalled_message.id, do: recalled_message, else: msg
          end)

        # Debug: In ra tin nhắn vừa thu hồi
        IO.inspect(recalled_message, label: "Recalled message")

        # Debug: In ra danh sách pinned_messages trước khi cập nhật
        IO.inspect(socket.assigns.pinned_messages, label: "Pinned messages BEFORE recall")

        # Cập nhật danh sách tin nhắn ghim: loại bỏ tin nhắn thu hồi
        new_pinned_messages =
          Enum.reject(socket.assigns.pinned_messages, &(&1.id == message_id))

        # Debug: In ra danh sách pinned_messages sau khi cập nhật
        IO.inspect(new_pinned_messages, label: "Pinned messages AFTER recall")

        topic = chat_topic(socket.assigns.conversation_id)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_recalled", recalled_message)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_unpinned", %{message_id: message_id})

        {:noreply,
         socket
         |> assign(messages: updated_messages, pinned_messages: new_pinned_messages)
         |> put_flash(:info, "Tin nhắn đã được thu hồi thành công")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Không thể thu hồi tin nhắn")}
    end
  end

  # Xử lý sự kiện chỉnh sửa tin nhắn
  def handle_event("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    conversation_id = socket.assigns.conversation_id

    case Messaging.edit_message(message_id, content) do
      {:ok, edited_message} ->
        # Cập nhật danh sách tin nhắn đã chỉnh sửa
        updated_messages =
          Enum.map(socket.assigns.messages, fn msg ->
            if msg.id == edited_message.id, do: edited_message, else: msg
          end)

        # Kiểm tra nếu tin nhắn đã ghim bị chỉnh sửa thì cập nhật danh sách ghim
        updated_pinned_messages =
          if Enum.any?(socket.assigns.pinned_messages, &(&1.id == edited_message.id)) do
            Messaging.list_pinned_messages(socket.assigns.conversation_id)
          else
            socket.assigns.pinned_messages
          end

        # Phát sự kiện cập nhật tin nhắn
        Gchatdemo1Web.Endpoint.broadcast!(
          chat_topic(conversation_id),
          "message_edited",
          edited_message
        )

        {:noreply,
         socket
         |> assign(messages: updated_messages, pinned_messages: updated_pinned_messages)
         |> put_flash(:info, "Tin nhắn đã được chỉnh sửa thành công")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Không thể chỉnh sửa tin nhắn")}
    end
  end

  # Thêm xử lý sự kiện xóa tin nhắn
  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    case Messaging.delete_message(message_id) do
      {:ok, deleted_message} ->
        topic = chat_topic(socket.assigns.conversation_id)
        # Broadcast thông báo xóa tin nhắn
        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_deleted", %{message_id: message_id})

        updated_messages =
          Enum.reject(socket.assigns.messages, fn msg -> msg.id == deleted_message.id end)

        # Cập nhật danh sách tin nhắn ghim: loại bỏ tin nhắn vừa xóa
        new_pinned_messages =
          Enum.reject(socket.assigns.pinned_messages, &(&1.id == message_id))

        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_unpinned", %{message_id: message_id})

        {:noreply,
         socket
         |> assign(messages: updated_messages, pinned_messages: new_pinned_messages)
         |> put_flash(:info, "Tin nhắn đã được xóa thành công")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Không thể xóa tin nhắn")}
    end
  end

  def handle_event(
        "forward_message",
        %{"message_id" => message_id, "recipient_id" => recipient_id},
        socket
      ) do
    current_user = socket.assigns.current_user
    original_message = Messaging.get_message(message_id)
    recipient_id = String.to_integer(recipient_id)

    case Messaging.get_or_create_conversation_forward(current_user.id, recipient_id) do
      {:ok, conversation_id} ->
        # Sử dụng conversation_id ở đây (đã là integer)
        content = "[Chuyển tiếp] #{original_message.content}"

        case Messaging.send_message(current_user.id, conversation_id, content, %{
               is_forwarded: true,
               original_sender_id: original_message.user_id
             }) do
          {:ok, message} ->
            # Đã đúng vì conversation_id là integer
            topic = chat_topic(conversation_id)
            Gchatdemo1Web.Endpoint.broadcast!(topic, "new_message", %{message: message})

            {:noreply,
             socket
             |> assign(show_forward_modal: false)
             |> put_flash(:info, "Đã chuyển tiếp tin nhắn thành công")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Lỗi khi chuyển tiếp tin nhắn")}
        end

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Không thể tạo cuộc trò chuyện")}
    end
  end

  # Sửa hàm handle_event
  def handle_event("open_forward_modal", %{"message_id" => message_id}, socket) do
    IO.inspect(message_id, label: "🔍 message_id nhận được")
    forward_message = Messaging.get_message(message_id)
    friends = Accounts.list_friends(socket.assigns.current_user.id)
    IO.inspect(friends, label: "Danh sách bạn bè")

    {:noreply,
     socket
     |> assign(show_forward_modal: true, forward_message: forward_message, friends: friends)}
  end

  # Xư lí gửi emoji
  def handle_event(
        "react_to_message",
        %{"message_id" => message_id, "emoji" => emoji},
        socket
      ) do
    current_user = socket.assigns.current_user
    conversation_id = socket.assigns.conversation_id

    case Messaging.add_reaction(message_id, current_user.id, emoji) do
      {:ok, _reaction} ->
        topic = chat_topic(conversation_id)
        # LẤY LẠI REACTIONS TỪ DATABASE SAU KHI THÊM/XÓA
        updated_reactions = Messaging.get_reactions(message_id)

        Gchatdemo1Web.Endpoint.broadcast!(topic, "new_reaction", %{
          message_id: message_id,
          # GỬI REACTIONS MỚI NHẤT
          reactions: updated_reactions
        })

        {:noreply, assign(socket, show_emoji_picker: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Thao tác thất bại")}
    end
  end

  def handle_event("toggle_emoji_picker", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    IO.inspect(message_id, label: "Message ID received")
    new_state = if socket.assigns.show_emoji_picker == message_id, do: nil, else: message_id
    IO.inspect(new_state, label: "New state for emoji picker")
    {:noreply, assign(socket, show_emoji_picker: new_state)}
  end

  #
  def handle_event("toggle_search", _params, socket) do
    socket =
      if socket.assigns.show_search do
        # Khi tắt search, reset về danh sách đầy đủ
        assign(socket,
          show_search: false,
          filtered_messages: socket.assigns.search_items
        )
        |> clear_flash()
      else
        # Khi bật search, chỉ cần set show_search = true
        assign(socket, show_search: true)
      end

    {:noreply, socket}
  end

  def handle_event("search_message", %{"search_query" => search_text}, socket) do
    IO.inspect(search_text, label: "Search text received")

    filtered_messages =
      if search_text == "" do
        socket.assigns.search_items
      else
        Enum.filter(socket.assigns.search_items, fn msg ->
          IO.inspect(msg.is_recalled, label: "Search recall")

          String.contains?(String.downcase(msg.content), String.downcase(search_text)) and
            not msg.is_recalled
        end)
      end

    socket =
      if search_text != "" and Enum.empty?(filtered_messages) do
        socket
        |> put_flash(:error, "Không tìm thấy tin nhắn!")
        |> assign(:filtered_messages, socket.assigns.search_items)
      else
        socket
        |> clear_flash()
        |> assign(:filtered_messages, filtered_messages)
      end

    # Lưu giá trị tìm kiếm vào assigns để giữ lại khi render lại
    {:noreply, assign(socket, search_query: search_text)}
  end

  def handle_event("close_forward_modal", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_expand", %{"message_id" => message_id}, socket) do
    # Thêm dòng này để convert sang integer
    message_id = String.to_integer(message_id)
    expanded = Map.get(socket.assigns.expanded_messages, message_id, false)
    expanded_messages = Map.put(socket.assigns.expanded_messages, message_id, !expanded)
    {:noreply, assign(socket, expanded_messages: expanded_messages)}
  end

  def handle_event("pin_message", %{"message_id" => message_id}, socket) do
    message_id = String.to_integer(message_id)
    # Tìm tin nhắn trong danh sách messages đã load
    conversation_id = socket.assigns.conversation_id

    attrs = %{
      message_id: message_id,
      conversation_id: conversation_id,
      pinned_by: socket.assigns.current_user.id
    }

    case Gchatdemo1.Messaging.pin_message(attrs) do
      {:ok, _pinned_message} ->
        # Load lại từ database
        pinned_messages = Messaging.list_pinned_messages(conversation_id)
        topic = chat_topic(conversation_id)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_pinned", %{message_id: message_id})

        {:noreply, assign(socket, pinned_messages: pinned_messages)}

      {:error, :already_pinned} ->
        {:noreply, put_flash(socket, :info, "Tin nhắn đã được ghim trước đó")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Lỗi khi ghim tin nhắn")}
    end
  end

  def handle_event("unpin_message", %{"message_id" => message_id}, socket) do
    conversation_id = socket.assigns.conversation_id

    case Messaging.unpin_message(conversation_id, message_id) do
      {:ok, _} ->
        # Load lại từ database
        pinned_messages = Messaging.list_pinned_messages(conversation_id)
        topic = chat_topic(conversation_id)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_unpinned", %{message_id: message_id})

        {:noreply, assign(socket, pinned_messages: pinned_messages)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Tin nhắn chưa được ghim")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Lỗi khi gỡ ghim tin nhắn")}
    end
  end

  def handle_event("start_reply", %{"message_id" => message_id}, socket) do
    reply_to = Messaging.get_message(message_id)
    {:noreply, assign(socket, replying_to: reply_to)}
  end

  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, replying_to: nil)}
  end

  def handle_event("start_call", _, socket) do
    topic = "call:#{socket.assigns.conversation_id}"
    IO.puts("Subscribing to topic: #{topic}")
    IO.puts("Call state changed to: calling")
    Gchatdemo1Web.Endpoint.subscribe(topic)

    {:noreply,
     socket
     |> assign(call_state: :calling, is_caller: true)
     |> push_event("start_call", %{})}
  end

  def handle_event("user_answer", _params, socket) do
    now = NaiveDateTime.utc_now()

    updated_socket =
      socket
      |> assign(
        call_state: :in_call,
        call_started_at: now
      )
      |> push_event("accept_call", %{})

    {:noreply, updated_socket}
  end

  def handle_event("answer", %{"sdp" => sdp, "type" => type}, socket) do
    conversation_id = socket.assigns.conversation_id
    topic = "call:#{conversation_id}"
    Gchatdemo1Web.Endpoint.broadcast!(topic, "answer", %{sdp: sdp, type: type})
    {:noreply, socket}
  end

  def handle_event("reject_call", _, socket) do
    topic = "call:#{socket.assigns.conversation_id}"
    IO.puts("Call state changed to: idle (call rejected)")
    Gchatdemo1Web.Endpoint.broadcast!(topic, "call_rejected", %{})

    if socket.assigns.call_state == :awaiting_answer do
      # Tạo bản ghi lịch sử cuộc gọi
      {:ok, call_history} =
        Messaging.create_call_history(
          socket.assigns.conversation_id,
          socket.assigns.friend.id,
          socket.assigns.current_user.id,
          "rejected"
        )

      # Preload các mối quan hệ :caller và :callee
      call_history =
        Gchatdemo1.Repo.preload(call_history, [:caller, :callee])

      # Broadcast sự kiện new_call_history với dữ liệu đã preload
      Gchatdemo1Web.Endpoint.broadcast!(topic, "new_call_history", %{call_history: call_history})
    end

    {:noreply,
     socket
     |> assign(call_state: :idle)
     |> push_event("end_call", %{})}
  end

  # Xử lý sự kiện "end_call" từ client
  def handle_event("end_call", _, socket) do
    topic = "call:#{socket.assigns.conversation_id}"
    IO.puts("Broadcasting call_ended to topic: #{topic}")
    Gchatdemo1Web.Endpoint.broadcast!(topic, "call_ended", %{})

    # Ghi log cuộc gọi thành công
    if socket.assigns.call_state == :in_call do
      started_at = socket.assigns.call_started_at
      ended_at = NaiveDateTime.utc_now()

      # Tạo bản ghi lịch sử cuộc gọi
      {:ok, call_history} =
        Messaging.create_call_history(
          socket.assigns.conversation_id,
          socket.assigns.current_user.id,
          socket.assigns.friend.id,
          "answered",
          started_at,
          ended_at
        )

      # Preload các mối quan hệ :caller và :callee
      call_history =
        Gchatdemo1.Repo.preload(call_history, [:caller, :callee])

      # Broadcast sự kiện new_call_history với dữ liệu đã preload
      Gchatdemo1Web.Endpoint.broadcast!(topic, "new_call_history", %{call_history: call_history})
    end

    {:noreply,
     socket
     |> assign(call_state: :idle)
     |> push_event("end_call", %{})}
  end

  def handle_event("offer", %{"sdp" => sdp, "type" => type}, socket) do
    conversation_id = socket.assigns.conversation_id
    topic = "call:#{conversation_id}"
    IO.puts("Broadcasting offer to topic: #{topic}")
    IO.inspect(%{sdp: sdp, type: type}, label: "Offer payload")
    Gchatdemo1Web.Endpoint.broadcast!(topic, "offer", %{sdp: sdp, type: type})
    {:noreply, socket}
  end

  # Xử lý candidate
  def handle_event("candidate", %{"candidate" => candidate}, socket) do
    conversation_id = socket.assigns.conversation_id
    topic = "call:#{conversation_id}"

    Gchatdemo1Web.Endpoint.broadcast_from!(self(), topic, "candidate", %{candidate: candidate})

    {:noreply, socket}
  end

  # Xử lý sự kiện tin nhắn đã được nhận
  def handle_info(%{event: "message_delivered", payload: %{message_id: message_id}}, socket) do
    current_user_id = socket.assigns.current_user.id

    updated_messages =
      Enum.map(socket.assigns.messages, fn msg ->
        # Chỉ cập nhật nếu tin nhắn thuộc về current_user, chưa là "seen"
        if msg.id == message_id and msg.user_id == current_user_id and msg.status != "seen" do
          %{msg | status: "delivered"}
        else
          msg
        end
      end)

    {:noreply, assign(socket, messages: updated_messages)}
  end

  def handle_info(
        %{event: "new_reaction", payload: %{message_id: msg_id, reactions: reactions}},
        socket
      ) do
    IO.inspect(msg_id, label: "Message ID received in handle_info")
    IO.inspect(reactions, label: "Reactions received in handle_info")
    # Chuyển đổi msg_id sang integer nếu cần
    msg_id = if is_binary(msg_id), do: String.to_integer(msg_id), else: msg_id

    updated_messages =
      Enum.map(socket.assigns.messages, fn message ->
        if message.id == msg_id, do: %{message | reactions: reactions}, else: message
      end)

    updated_filtered_messages =
      Enum.map(socket.assigns.filtered_messages || [], fn message ->
        if message.id == msg_id, do: %{message | reactions: reactions}, else: message
      end)

    {:noreply,
     assign(socket,
       messages: updated_messages,
       filtered_messages:
         if(socket.assigns.show_search, do: updated_filtered_messages, else: updated_messages)
     )}
  end

  # Xử lý sự kiện tin nhắn đã được xem
  def handle_info(
        %{
          event: "messages_seen",
          payload: %{reader_id: reader_id, conversation_id: conversation_id}
        },
        socket
      ) do
    # Chỉ xử lý nếu conversation khớp và reader là người nhận (friend của current user)
    if conversation_id == socket.assigns.conversation_id && reader_id == socket.assigns.friend.id do
      updated_messages =
        socket.assigns.messages
        |> Enum.map(fn msg ->
          # Kiểm tra xem msg có phải là tin nhắn (có :user_id) hay không
          if Map.has_key?(msg, :user_id) do
            # Cập nhật trạng thái "seen" trong bảng message_statuses
            updated_statuses =
              Enum.map(msg.message_statuses, fn status ->
                if status.user_id == socket.assigns.current_user.id do
                  %{status | status: "seen"}
                else
                  status
                end
              end)

            # Cập nhật message với message_statuses mới
            %{msg | message_statuses: updated_statuses}
          else
            # Nếu là lịch sử cuộc gọi (CallHistory), giữ nguyên
            msg
          end
        end)

      {:noreply, assign(socket, messages: updated_messages)}
    else
      {:noreply, socket}
    end
  end

  # Xử lý sự kiện đánh dấu tin nhắn là "đã xem" khi người dùng mở chat
  def handle_info(:mark_messages_as_seen, socket) do
    current_user_id = socket.assigns.current_user.id
    conversation_id = socket.assigns.conversation_id

    if socket.assigns.friend do
      # Chỉ mark seen cho tin nhắn của friend (người gửi)
      {count, _} =
        Messaging.mark_messages_as_seen(
          conversation_id,
          socket.assigns.friend.id
        )

      if count > 0 do
        Gchatdemo1Web.Endpoint.broadcast!(
          chat_topic(conversation_id),
          "messages_seen",
          %{
            conversation_id: conversation_id,
            reader_id: current_user_id
          }
        )
      end
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "new_message", payload: %{message: new_message}}, socket) do
    if new_message.conversation_id == socket.assigns.conversation_id do
      # Nếu tin nhắn có reply_to_id, load thêm thông tin của tin nhắn gốc
      updated_message =
        if new_message.reply_to_id do
          %{new_message | reply_to: Messaging.get_message(new_message.reply_to_id)}
        else
          new_message
        end

      updated_messages =
        socket.assigns.messages
        |> Enum.reject(&(&1.id == updated_message.id))
        |> Kernel.++([updated_message])

      current_user_id = socket.assigns.current_user.id
      friend_id = socket.assigns.friend.id

      # Nếu tin nhắn được gửi từ bạn bè, đánh dấu là "seen" và broadcast event
      if new_message.user_id == friend_id do
        case Messaging.mark_messages_as_seen(new_message.conversation_id, current_user_id) do
          {count, _} -> {:ok, count}
        end

        Gchatdemo1Web.Endpoint.broadcast!(
          chat_topic(new_message.conversation_id),
          "messages_seen",
          %{
            conversation_id: new_message.conversation_id,
            reader_id: current_user_id
          }
        )
      end

      {:noreply, assign(socket, messages: updated_messages)}
    else
      {:noreply, socket}
    end
  end

  # Xử lý broadcast event "message_edited"
  def handle_info(%{event: "message_edited", payload: edited_message}, socket) do
    updated_messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == edited_message.id, do: edited_message, else: msg
      end)

    {:noreply, assign(socket, messages: updated_messages)}
  end

  # Xử lý broadcast event "message_recalled"
  def handle_info(%{event: "message_recalled", payload: recalled_message}, socket) do
    updated_messages =
      Enum.map(socket.assigns.messages, fn msg ->
        if msg.id == recalled_message.id, do: recalled_message, else: msg
      end)

    {:noreply, assign(socket, messages: updated_messages)}
  end

  # Xử lý broadcast event "message_deleted"
  def handle_info(%{event: "message_deleted", payload: %{message_id: message_id}}, socket) do
    updated_messages =
      Enum.reject(socket.assigns.messages, fn msg ->
        to_string(msg.id) == to_string(message_id)
      end)

    {:noreply, assign(socket, messages: updated_messages)}
  end

  def handle_info(%{event: "message_pinned"}, socket) do
    pinned_messages = Messaging.list_pinned_messages(socket.assigns.conversation_id)
    {:noreply, assign(socket, pinned_messages: pinned_messages)}
  end

  def handle_info(%{event: "message_unpinned"}, socket) do
    pinned_messages = Messaging.list_pinned_messages(socket.assigns.conversation_id)
    {:noreply, assign(socket, pinned_messages: pinned_messages)}
  end

  def handle_info(%{event: "offer", payload: offer}, socket) do
    IO.inspect(offer, label: "Offer received")

    if socket.assigns.call_state == :idle do
      {:noreply,
       socket
       |> assign(call_state: :awaiting_answer, is_caller: false)
       |> push_event("handle_offer", offer)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%{event: "call_rejected"}, socket) do
    {:noreply,
     socket
     |> assign(call_state: :idle)
     |> put_flash(:info, "Cuộc gọi đã bị từ chối")
     |> push_event("end_call", %{})}
  end

  def handle_info(%{event: "answer", payload: answer}, socket) do
    IO.puts(
      "Received answer broadcast, current call_state: #{socket.assigns.call_state}, socket: #{socket.id}"
    )

    if socket.assigns.call_state == :calling do
      IO.puts("Pushing handle_answer to client #{socket.id} with payload: #{inspect(answer)}")

      {:noreply,
       socket
       |> assign(call_state: :in_call)
       |> push_event("handle_answer", answer)}
    else
      IO.puts("Ignoring answer, call_state is not :calling for socket: #{socket.id}")
      {:noreply, socket}
    end
  end

  # Xử lý broadcast "call_ended" cho tất cả socket trong topic
  def handle_info(%{event: "call_ended", payload: _payload}, socket) do
    IO.puts("Received call_ended broadcast, socket: #{socket.id}")

    {:noreply,
     socket
     |> assign(call_state: :idle)
     |> push_event("end_call", %{})}
  end

  # Sửa lại phần handle candidate trong Phoenix LiveView
  def handle_info(%{event: "candidate", payload: candidate}, socket) do
    # Thêm debug log để kiểm tra candidate nhận được
    IO.inspect(candidate, label: "Nhận candidate từ channel")
    {:noreply, push_event(socket, "handle_candidate", candidate)}
  end

  def handle_info(%{event: "new_call_history", payload: %{call_history: call_history}}, socket) do
    # Kiểm tra xem call_history đã tồn tại trong messages chưa dựa trên id
    already_exists? =
      Enum.any?(socket.assigns.messages, fn item ->
        # Chỉ kiểm tra với các bản ghi CallHistory (có field :call_type)
        Map.get(item, :id) == call_history.id and Map.has_key?(item, :call_type)
      end)

    # Chỉ cập nhật messages nếu bản ghi chưa tồn tại
    socket =
      if already_exists? do
        # Không làm gì nếu đã tồn tại
        socket
      else
        updated_messages =
          (socket.assigns.messages ++ [call_history])
          |> Enum.sort_by(& &1.inserted_at, :asc)

        assign(socket, messages: updated_messages)
      end

    {:noreply, socket}
  end

  # Hàm render hiển thị giao diện chat
  def render(assigns) do
    ~H"""
    <div id="chat-container">
      <div id="chat-header">
        <h2>Chat với {if @friend, do: @friend.email, else: "Người dùng không xác định"}</h2>
         <% css_class =
          cond do
            @friend_status == "online" or @friend_status == "Đang hoạt động" ->
              "active"

            String.starts_with?(@friend_status, "Hoạt động") ->
              "away"

            true ->
              "offline"
          end %>
        <p class={"status " <> css_class}>
          Trạng thái: {@friend_status}
        </p>
         <button type="button" phx-click="toggle_search" class="search-button">🔍</button>
        <%= if @show_search do %>
          <div class="search-container">
            <div class="search-container">
              <form phx-submit="search_message">
                <input
                  type="text"
                  name="search_query"
                  placeholder="Tìm kiếm tin nhắn..."
                  value={@search_query}
                /> <button type="submit">🔍</button>
              </form>
            </div>
          </div>
        <% end %>
      </div>

      <div id="video-container" phx-hook="WebRTC">
        <!-- Trong template của cả caller và receiver -->
        <!-- Thêm muted và playsinline -->
        <video id="remote-video" autoplay playsinline></video>
        <video id="local-video" autoplay playsinline muted></video>
      </div>

      <div class="call-controls">
        <%= case @call_state do %>
          <% :idle -> %>
            <button phx-click="start_call">Gọi video</button>
          <% :calling -> %>
            <div class="calling-overlay">
              <p>Đang gọi...</p>
               <button phx-click="end_call">Hủy</button>
            </div>
          <% :awaiting_answer -> %>
            <div class="incoming-call-overlay">
              <p>Cuộc gọi đến từ {@friend.email}</p>
               <button phx-click="user_answer">Trả lời</button>
              <button phx-click="reject_call">Từ chối</button>
            </div>
          <% :in_call -> %>
            <button phx-click="end_call">Kết thúc</button>
        <% end %>
      </div>
      <!-- Phần hiển thị tin nhắn đã ghim -->
      <div class="pinned-messages-section">
        <h3>📌 Tin nhắn đã ghim</h3>

        <%= if Enum.empty?(@pinned_messages) do %>
          <p class="no-pinned-messages">Chưa có tin nhắn nào được ghim</p>
        <% else %>
          <%= for pinned <- @pinned_messages do %>
            <div class="pinned-message" id={"pinned-message-#{pinned.id}"}>
              <div class="pinned-content">
                <strong>{pinned.user.email}:</strong>
                <p>{pinned.content}</p>
              </div>

              <button phx-click="unpin_message" phx-value-message_id={pinned.id} class="unpin-button">
                Gỡ ghim
              </button>
            </div>
          <% end %>
        <% end %>
      </div>

      <div id="chat-messages">
        <%= for item <- (if @search_query != "" do
    Enum.filter(@search_items, fn item ->
      if Map.has_key?(item, :content) do
        # Lọc tin nhắn dựa trên nội dung và không bị thu hồi
        String.contains?(String.downcase(item.content), String.downcase(@search_query)) and not item.is_recalled
      else
        # Không lọc cuộc gọi (hoặc có thể thêm logic lọc cuộc gọi nếu muốn)
        false
      end
    end)
    else
    @messages
    end) do %>
          <%= if Map.has_key?(item, :content) do %>
            <!-- Hiển thị tin nhắn -->
            <% message = item %> <% message_class =
              if message.user_id == @current_user.id, do: "message-right", else: "message-left" %>
            <!-- Nếu tin nhắn đến từ người khác, hiển thị avatar -->
            <%= if message.user_id != @current_user.id and message.user.avatar_url do %>
              <div class="message-avatar-container">
                <img src={message.user.avatar_url} alt="avatar" class="message-avatar" />
              </div>
            <% end %>
            <!-- Container cho tin nhắn -->
            <div class="message-container" id={"message-#{message.id}"}>
              <!-- Menu "..." bên trái tin nhắn (chỉ cho tin nhắn của người gửi) -->
              <%= if message.user_id == @current_user.id do %>
                <div class="message-actions">
                  <div class="dropdown">
                    <button class="dropdown-toggle" type="button">...</button>
                    <div class="dropdown-menu">
                      <%= if message.is_recalled do %>
                        <button
                          type="button"
                          phx-click="delete_message"
                          phx-value-message_id={message.id}
                        >
                          Xóa tin nhắn
                        </button>
                      <% else %>
                        <%= if message.is_forwarded do %>
                          <!-- Nếu tin nhắn đã chuyển tiếp -->
                          <button
                            type="button"
                            phx-click="delete_message"
                            phx-value-message_id={message.id}
                          >
                            Xóa tin nhắn
                          </button>

                          <button
                            type="button"
                            phx-click="open_forward_modal"
                            phx-value-message_id={message.id}
                          >
                            Chuyển tiếp
                          </button>

                          <button
                            type="button"
                            phx-click="start_reply"
                            phx-value-message_id={message.id}
                          >
                            Trả lời
                          </button>
                        <% else %>
                          <!-- Nếu tin nhắn chưa chuyển tiếp -->
                          <button
                            type="button"
                            phx-click="recall_message"
                            phx-value-message_id={message.id}
                          >
                            Thu hồi
                          </button>

                          <button
                            type="button"
                            phx-click={show_modal("edit-message-modal-#{message.id}")}
                          >
                            Chỉnh sửa
                          </button>

                          <button
                            type="button"
                            phx-click="delete_message"
                            phx-value-message_id={message.id}
                          >
                            Xóa tin nhắn
                          </button>

                          <button
                            type="button"
                            phx-click="open_forward_modal"
                            phx-value-message_id={message.id}
                          >
                            Chuyển tiếp
                          </button>

                          <button
                            type="button"
                            phx-click="start_reply"
                            phx-value-message_id={message.id}
                          >
                            Trả lời
                          </button>
                        <% end %>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>

    <!-- Menu "..." cho tin nhắn của người nhận -->
              <%= if message.user_id != @current_user.id do %>
                <div class="message-actions">
                  <div class="dropdown">
                    <button class="dropdown-toggle" type="button">...</button>
                    <div class="dropdown-menu">
                      <button
                        type="button"
                        phx-click="open_forward_modal"
                        phx-value-message_id={message.id}
                      >
                        Chuyển tiếp
                      </button>

                      <button type="button" phx-click="start_reply" phx-value-message_id={message.id}>
                        Trả lời
                      </button>
                    </div>
                  </div>
                </div>
              <% end %>

    <!-- Nội dung tin nhắn -->
              <div class={"message #{message_class}"} title={format_time(message.inserted_at)}>
                <!-- Hiển thị thông tin chuyển tiếp -->
                <%= if message.is_forwarded do %>
                  <div class="forwarded-message-header">
                    {Accounts.get_user(message.user_id).email} đã chuyển tiếp một tin nhắn
                  </div>
                <% end %>
                <!-- Nếu tin nhắn là trả lời -->
                <%= if message.reply_to_id do %>
                  <% reply_to = Messaging.get_message(message.reply_to_id) %>
                  <div class="reply-content">
                    <strong>Trả lời {reply_to.user.email}:</strong>
                    <p>{truncate(reply_to.content, length: 100)}</p>
                  </div>
                <% end %>

                <div class="message-content">
                  <strong>{message.user.email}:</strong>
                  <p class={"truncate-message #{if @expanded_messages[message.id], do: "expanded"}"}>
                    <%= if message.is_recalled do %>
                      <em>Tin nhắn đã được thu hồi</em>
                    <% else %>
                      {message.content}
                      <%= if message.is_edited do %>
                        <span class="edited-label">(đã chỉnh sửa)</span>
                      <% end %>
                    <% end %>
                  </p>

                  <%= if String.length(message.content) > 150 do %>
                    <button
                      phx-click="toggle_expand"
                      phx-value-message_id={message.id}
                      class="expand-button"
                    >
                      {if @expanded_messages[message.id], do: "Thu gọn", else: "Xem thêm"}
                    </button>
                  <% end %>
                </div>

    <!-- Nút Ghim/Gỡ ghim -->
                <%= if not message.is_recalled do %>
                  <%= if Enum.any?(@pinned_messages, fn m -> m.id == message.id end) do %>
                    <button
                      phx-click="unpin_message"
                      phx-value-message_id={message.id}
                      class="unpin-btn"
                    >
                      🗑️ Gỡ ghim
                    </button>
                  <% else %>
                    <button phx-click="pin_message" phx-value-message_id={message.id} class="pin-btn">
                      📌 Ghim
                    </button>
                  <% end %>
                <% end %>

    <!-- Hiển thị reactions -->
                <div class="message-reactions">
                  <%= for reaction <- message.reactions do %>
                    <span class="emoji-reaction">
                      <%= case reaction.emoji do %>
                        <% "👍" -> %>
                          👍
                        <% "❤️" -> %>
                          ❤️
                        <% "😄" -> %>
                          😄
                        <% "😠" -> %>
                          😠
                        <% "😲" -> %>
                          😲
                      <% end %>
                    </span>
                  <% end %>
                </div>

    <!-- Emoji picker -->
                <div class="emoji-actions">
                  <button
                    phx-click="toggle_emoji_picker"
                    phx-value-message_id={message.id}
                    class="emoji-trigger"
                  >
                    😀
                  </button>

                  <%= if @show_emoji_picker == message.id do %>
                    <div class="emoji-picker">
                      <button
                        phx-click="react_to_message"
                        phx-value-message_id={message.id}
                        phx-value-emoji="👍"
                      >
                        👍
                      </button>

                      <button
                        phx-click="react_to_message"
                        phx-value-message_id={message.id}
                        phx-value-emoji="❤️"
                      >
                        ❤️
                      </button>

                      <button
                        phx-click="react_to_message"
                        phx-value-message_id={message.id}
                        phx-value-emoji="😄"
                      >
                        😄
                      </button>

                      <button
                        phx-click="react_to_message"
                        phx-value-message_id={message.id}
                        phx-value-emoji="😠"
                      >
                        😠
                      </button>

                      <button
                        phx-click="react_to_message"
                        phx-value-message_id={message.id}
                        phx-value-emoji="😲"
                      >
                        😲
                      </button>
                    </div>
                  <% end %>
                </div>

    <!-- Hiển thị trạng thái tin nhắn (chỉ cho tin nhắn cuối cùng) -->
                <%= if message.user_id == @current_user.id and is_last_message?(message, @messages) do %>
                  <div class="message-status">
                    <% status =
                      Enum.find(message.message_statuses, &(&1.user_id == @current_user.id)).status %>
                    <%= if status == "sent" do %>
                      📤 đã gửi
                    <% end %>

                    <%= if status == "delivered" do %>
                      📬 đã nhận
                    <% end %>

                    <%= if status == "seen" do %>
                      👀 đã xem
                    <% end %>
                  </div>
                <% end %>
              </div>

    <!-- Modal chỉnh sửa tin nhắn -->
              <.modal id={"edit-message-modal-#{message.id}"}>
                <h2>Chỉnh sửa tin nhắn</h2>

                <form phx-submit="edit_message">
                  <input type="hidden" name="message_id" value={message.id} /> <textarea name="content"><%= message.content %></textarea>
                  <button type="submit">Lưu</button>
                </form>
              </.modal>
            </div>
          <% else %>
            <!-- Hiển thị lịch sử cuộc gọi -->
            <% call = item %>
            <div class="system-message">
              <%= case call.status do %>
                <% "rejected" -> %>
                  <p>
                    📞 {call.callee.email} đã từ chối cuộc gọi video - {format_time(call.inserted_at)}
                  </p>
                <% "answered" -> %>
                  <p>
                    📞 Cuộc gọi video đã kết thúc ({div(call.duration, 60)}:{rem(call.duration, 60)
                    |> Integer.to_string()
                    |> String.pad_leading(2, "0")}) - {format_time(call.inserted_at)}
                  </p>
                <% "missed" -> %>
                  <p>📞 Cuộc gọi nhỡ - {format_time(call.inserted_at)}</p>
              <% end %>
            </div>
          <% end %>
        <% end %>
      </div>
      <!-- Modal chuyển tiếp tin nhắn -->

      <%= if @show_forward_modal do %>
        <.modal id="forward-modal" show={true}>
          <h2 class="text-xl font-bold mb-4">Chuyển tiếp tin nhắn</h2>

          <form phx-submit="forward_message" class="space-y-4">
            <input
              type="hidden"
              name="message_id"
              value={if @forward_message, do: @forward_message.id, else: ""}
            />
            <div class="friends-list space-y-2">
              <!-- Trong phần render friends list -->
              <%= for friend <- @friends do %>
                <label class="friend-item">
                  <input type="radio" name="recipient_id" value={to_string(friend.friend_id)} />
                  <span class="friend-name">{friend.email}</span>
                </label>
              <% end %>
            </div>

            <div class="modal-actions flex justify-end space-x-2">
              <button
                type="button"
                phx-click="close_forward_modal"
                class="btn-cancel px-4 py-2 bg-gray-300 rounded"
              >
                Hủy
              </button>

              <button type="submit" class="btn-submit px-4 py-2 bg-blue-500 text-white rounded">
                Gửi
              </button>
            </div>
          </form>
        </.modal>
      <% end %>
      <!-- Phần preview khi đang trả lời: hiển thị ở trên ô nhập tin nhắn -->
      <%= if @replying_to do %>
        <div class="reply-preview">
          Đang trả lời {@replying_to.user.email}: {truncate(@replying_to.content, length: 50)}
          <button phx-click="cancel_reply">Hủy</button>
        </div>
      <% end %>
      <!-- Ô nhập tin nhắn -->
      <form phx-submit="send_message">
        <div class="chat-input">
          <input type="text" name="content" placeholder="Nhập tin nhắn..." required />
          <button type="submit">Gửi</button>
        </div>
      </form>
    </div>
    """
  end

  # Hàm kiểm tra xem tin nhắn có phải là tin nhắn cuối cùng không
  defp is_last_message?(message, messages) do
    last_message = List.last(messages)
    message.id == last_message.id
  end

  # Hàm định dạng thời gian
  defp format_time(nil), do: "Không rõ thời gian"

  defp format_time(%NaiveDateTime{} = naive) do
    naive
    # Chuyển sang DateTime với múi giờ UTC
    |> DateTime.from_naive!("Etc/UTC")
    # Chuyển sang múi giờ Việt Nam
    |> Timex.Timezone.convert("Asia/Ho_Chi_Minh")
    |> Timex.format!("{YYYY}-{0M}-{0D} {h12}:{m} {AM}")
  end

  defp format_time(%DateTime{} = datetime) do
    datetime
    |> Timex.Timezone.convert("Asia/Ho_Chi_Minh")
    |> Timex.format!("{YYYY}-{0M}-{0D} {h12}:{m} {AM}")
  end

  # Hàm tạo topic cho phòng chat
  defp chat_topic(conversation_id) do
    "conversation:#{conversation_id}"
  end

  def truncate(text, length) when is_binary(text) and length > 0 do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end
end
