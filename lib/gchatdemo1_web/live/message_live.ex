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
      # Lấy conversation_id từ params (có thể qua key "conversation_id" hoặc "to")
      conversation_id = Map.get(params, "conversation_id") || Map.get(params, "to")
      conversation_id = if conversation_id == "new", do: nil, else: conversation_id

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

      # Nếu tin nhắn cuối cùng là của current_user, chỉ đánh dấu là "delivered" nếu chưa "seen"
      last_message = List.last(messages)

      if last_message && last_message.user_id == current_user.id && last_message.status != "seen" do
        Messaging.mark_message_as_delivered(last_message.id)
      end

      if connected?(socket) and conversation_id do
        # Subscribe vào topic chat
        Gchatdemo1Web.Endpoint.subscribe(chat_topic(current_user.id, conversation_id))

        # Sau đó gửi sự kiện đánh dấu tin nhắn là "đã xem" (để bên nhận gửi về bên gửi thông báo)
        send(self(), :mark_messages_as_seen)
      end

      Gchatdemo1Web.UserActivityTracker.update_last_active(current_user)

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
         search_query: ""
       )}
    else
      {:ok, redirect(socket, to: "/users/log_in")}
    end
  end

  # Hàm xử lý sự kiện gửi tin nhắn
  def handle_event("send_message", %{"content" => content}, socket) do
    current_user = socket.assigns.current_user
    conversation_id = socket.assigns.conversation_id

    case Messaging.send_message(current_user.id, conversation_id, content) do
      {:ok, message} ->
        topic = chat_topic(current_user.id, conversation_id)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "new_message", %{message: message})

        # Đánh dấu tin nhắn là "đã gửi" và "đã nhận" nếu người nhận online
        if connected?(socket) do
          Messaging.mark_message_as_delivered(message.id)
          Gchatdemo1Web.Endpoint.broadcast!(topic, "message_delivered", %{message_id: message.id})
        end

        {:noreply, assign(socket, messages: socket.assigns.messages ++ [message])}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Không thể gửi tin nhắn")}
    end
  end

  # Xử lý sự kiện thu hồi tin nhắn
  def handle_event("recall_message", %{"message_id" => message_id}, socket) do
    case Messaging.recall_message(message_id) do
      {:ok, recalled_message} ->
        # Xóa luôn các emoji đã được thả
        recalled_message = %{recalled_message | reactions: []}

        updated_messages =
          Enum.map(socket.assigns.messages, fn msg ->
            if msg.id == recalled_message.id, do: recalled_message, else: msg
          end)

        Gchatdemo1Web.Endpoint.broadcast!(
          chat_topic(socket.assigns.current_user.id, socket.assigns.conversation_id),
          "message_recalled",
          recalled_message
        )

        {:noreply,
         socket
         |> assign(messages: updated_messages)
         |> put_flash(:info, "Tin nhắn đã được thu hồi thành công")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Không thể thu hồi tin nhắn")}
    end
  end

  # Xử lý sự kiện chỉnh sửa tin nhắn
  def handle_event("edit_message", %{"message_id" => message_id, "content" => content}, socket) do
    current_user = socket.assigns.current_user
    conversation_id = socket.assigns.conversation_id

    case Messaging.edit_message(message_id, content) do
      {:ok, edited_message} ->
        updated_messages =
          Enum.map(socket.assigns.messages, fn msg ->
            if msg.id == edited_message.id, do: edited_message, else: msg
          end)

        Gchatdemo1Web.Endpoint.broadcast!(
          chat_topic(current_user.id, conversation_id),
          "message_edited",
          edited_message
        )

        {:noreply,
         socket
         |> assign(messages: updated_messages)
         |> put_flash(:info, "Tin nhắn đã được chỉnh sửa thành công")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Không thể chỉnh sửa tin nhắn")}
    end
  end

  # Thêm xử lý sự kiện xóa tin nhắn
  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    case Messaging.delete_message(message_id) do
      {:ok, deleted_message} ->
        topic = chat_topic(socket.assigns.current_user.id, socket.assigns.conversation_id)
        # Broadcast thông báo xóa tin nhắn (nếu cần)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "message_deleted", %{message_id: message_id})

        updated_messages =
          Enum.reject(socket.assigns.messages, fn msg -> msg.id == deleted_message.id end)

        {:noreply,
         socket
         |> assign(messages: updated_messages)
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
    # Chuyển đổi recipient_id từ chuỗi sang số nguyên
    recipient_id = String.to_integer(recipient_id)

    content = "[Chuyển tiếp] #{original_message.content}"

    # Sử dụng original_sender_id nếu có, ngược lại dùng user_id của tin nhắn gốc
    original_sender_id = current_user.id
    IO.inspect(current_user.id, label: "Người chuyển tiếp")
    IO.inspect(recipient_id, label: "Người được chuyển tiếp")
    IO.inspect(original_sender_id, label: "Người được nhận id:")

    case Messaging.send_message(current_user.id, recipient_id, content, %{
           is_forwarded: true,
           original_sender_id: original_sender_id
         }) do
      {:ok, message} ->
        topic = chat_topic(current_user.id, recipient_id)
        Gchatdemo1Web.Endpoint.broadcast!(topic, "new_message", %{message: message})

        {:noreply,
         socket
         |> assign(show_forward_modal: false)
         |> put_flash(:info, "Đã chuyển tiếp tin nhắn thành công")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Lỗi khi chuyển tiếp tin nhắn")}
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
        topic = chat_topic(current_user.id, conversation_id)
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
        %{event: "messages_seen", payload: %{sender_id: sender_id, receiver_id: receiver_id}},
        socket
      ) do
    current_user_id = socket.assigns.current_user.id
    conversation_id = socket.assigns.conversation_id
    # sender_id == conversation_id và receiver_id == current_user_id
    if to_string(sender_id) == to_string(conversation_id) and
         to_string(receiver_id) == to_string(current_user_id) do
      updated_messages =
        Enum.map(socket.assigns.messages, fn msg ->
          if msg.user_id == current_user_id and msg.status in ["sent", "delivered"] do
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

    # Đánh dấu tin nhắn từ friend (có sender = friend) gửi đến current_user thành "seen" trong DB nếu có,
    # tuy nhiên, nếu bạn muốn hiển thị trạng thái "đã xem" cho tin nhắn của current_user (tin nhắn gửi đi),
    # thì bạn cần update DB và broadcast cho các tin nhắn của current_user.
    # Giả sử bạn muốn cập nhật tin nhắn của current_user khi friend đã xem:
    {count, _} = Messaging.mark_messages_as_seen(current_user_id, conversation_id)

    if count > 0 do
      IO.inspect("Cập nhật trạng thái tin nhắn thành đã xem")
      # Sửa payload: sender_id là current_user_id, receiver_id là conversation_id
      Gchatdemo1Web.Endpoint.broadcast!(
        chat_topic(current_user_id, conversation_id),
        "messages_seen",
        %{sender_id: conversation_id, receiver_id: current_user_id}
      )
    end

    {:noreply, socket}
  end

  def handle_info(%{event: "new_message", payload: %{message: new_message}}, socket) do
    if new_message.user_id != socket.assigns.current_user.id do
      send(self(), :mark_messages_as_seen)
      {:noreply, update(socket, :messages, &(&1 ++ [new_message]))}
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
          <div class="message-container">
            <!-- Menu "..." bên trái tin nhắn (chỉ cho tin nhắn của người gửi) -->
            <%= if message.user_id == @current_user.id do %>
              <div class="message-actions">
                <div class="dropdown">
                  <button class="dropdown-toggle" type="button">...</button>
                  <div class="dropdown-menu">
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
                    <% else %>
                      <!-- Nếu tin nhắn chưa chuyển tiếp, cho phép thu hồi, chỉnh sửa, xóa và chuyển tiếp -->
                      <button
                        type="button"
                        phx-click="recall_message"
                        phx-value-message_id={message.id}
                      >
                        Thu hồi
                      </button>
                      
                      <button type="button" phx-click={show_modal("edit-message-modal-#{message.id}")}>
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
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
            
    <!-- Nội dung tin nhắn -->
            <div class={"message #{message_class}"} title={format_time(message.inserted_at)}>
              <!-- Hiển thị thông tin chuyển tiếp -->
              <%= if message.is_forwarded do %>
                <div class="forwarded-message-header">
                  Chuyển tiếp từ {Accounts.get_user(message.original_sender_id).email}
                </div>
              <% end %>
              
              <div class="message-content">
                <strong>{message.user.email}:</strong>
                <p>
                  <%= if message.is_recalled do %>
                    <em>Tin nhắn đã được thu hồi</em>
                  <% else %>
                    {message.content}
                    <%= if message.is_edited do %>
                      <span class="edited-label">(đã chỉnh sửa)</span>
                    <% end %>
                  <% end %>
                </p>
              </div>
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
      
    <!-- Ô nhập tin nhắn -->
      <form phx-submit="send_message">
        <div class="chat-input">
          <input type="text" name="content" placeholder="Nhập tin nhắn..." required />
          <label for="file-upload">
            📎 <input type="file" id="file-upload" hidden phx-change="upload_file" />
          </label>
          
          <label for="image-upload">
            🖼️
            <input type="file" id="image-upload" accept="image/*" hidden phx-change="upload_image" />
          </label>
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
  defp chat_topic(user_id, friend_id) do
    [id1, id2] = Enum.sort([user_id, friend_id])
    "chat:#{id1}-#{id2}"
  end
end
