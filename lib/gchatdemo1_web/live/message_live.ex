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

      if connected?(socket) and conversation_id do
        topic = chat_topic(conversation_id)
        # Thêm dòng này
        IO.puts("Subscribing to topic: #{topic}")
        # Subscribe vào topic chat
        Gchatdemo1Web.Endpoint.subscribe(topic)

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
         messages: messages,
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
         replying_to: nil
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
          filtered_messages: socket.assigns.messages
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
        socket.assigns.messages
      else
        Enum.filter(socket.assigns.messages, fn msg ->
          IO.inspect(msg.is_recalled, label: "Search recall")

          String.contains?(String.downcase(msg.content), String.downcase(search_text)) and
            not msg.is_recalled
        end)
      end

    socket =
      if search_text != "" and Enum.empty?(filtered_messages) do
        socket
        |> put_flash(:error, "Không tìm thấy tin nhắn!")
        |> assign(:filtered_messages, socket.assigns.messages)
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
          # Cập nhật trạng thái "seen" cho tin nhắn của current user
          if msg.user_id == socket.assigns.current_user.id do
            %{msg | status: "seen"}
          else
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
        <%= for message <- (if @search_query != "" do
      Enum.filter(@messages, fn msg ->
        String.contains?(String.downcase(msg.content), String.downcase(@search_query)) and not msg.is_recalled
      end)
    else
      @messages
    end) do %>
          <% message_class =
            if message.user_id == @current_user.id, do: "message-right", else: "message-left" %>
          <!-- Nếu tin nhắn đến từ người khác, hiển thị avatar -->
          <%= if message.user_id != @current_user.id and message.user.avatar_url do %>
            <div class="message-avatar-container">
              <img src={message.user.avatar_url} alt="avatar" class="message-avatar" />
            </div>
          <% end %>

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
                        <!-- Nếu tin nhắn đã chuyển tiếp, chỉ cho phép xóa và chuyển tiếp -->
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
                        <!-- Nếu tin nhắn chưa chuyển tiếp, cho phép thu hồi, chỉnh sửa, xóa và chuyển tiếp -->
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
              <!-- Nếu tin nhắn là trả lời, hiển thị thông tin của tin nhắn gốc -->
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
              <!-- Nút Ghim/Gỡ ghim của từng tin nhắn -->
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
                  <%= case message.status do %>
                    <% "sent" -> %>
                      <span class="status">📤 Đã gửi</span>
                    <% "delivered" -> %>
                      <span class="status">📬 Đã nhận</span>
                    <% "seen" -> %>
                      <span class="status">👀 Đã xem</span>
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
