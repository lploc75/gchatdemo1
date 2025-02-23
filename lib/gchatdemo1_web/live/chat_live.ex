defmodule Gchatdemo1Web.ChatLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Chat
  # alias Gchatdemo1.Accounts  # Thêm module này để lấy thông tin user

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id  # Lấy user ID từ assigns
    groups = Chat.list_groups_for_user(user_id)        # Lọc nhóm theo user
    {:ok, assign(socket, user_id: user_id, groups: groups, selected_group: nil)}
  end

  def handle_event("select_group", %{"group_id" => group_id}, socket) do
    messages = Chat.list_messages(group_id)
    formatted_messages = format_messages(messages, socket.assigns.user_id)
    {:noreply, assign(socket, selected_group: group_id, messages: formatted_messages)}
  end

 defp format_messages(messages, current_user_id) do
    Enum.map(messages, fn msg ->
      sender = if msg.user_id == current_user_id do
                 "me"
               else
                 "other"
               end
      %{
        content: msg.content,
        sender: sender,
        inserted_at: msg.inserted_at
      }
    end)
  end
end
