defmodule Gchatdemo1.Chat do
  import Ecto.Query, warn: false
  alias Gchatdemo1.Repo
  alias Gchatdemo1.Chat.{Conversation, GroupMember, Message}

  @doc "Lấy danh sách các nhóm chat"
  def list_groups_for_user(user_id) do
    from(c in Gchatdemo1.Chat.Conversation,
      join: gm in Gchatdemo1.Chat.GroupMember,
      on: c.id == gm.conversation_id,
      where: gm.user_id == ^user_id,
      select: c
    )
    |> Repo.all()
  end

  # def list_groups do
  #   from(c in Conversation,
  #     where: c.is_group == true,
  #     order_by: [desc: c.inserted_at],
  #     select: %{id: c.id, name: c.name, creator_id: c.creator_id}
  #   )
  #   |> Repo.all()
  # end

  @doc "Lấy danh sách tin nhắn của một nhóm chat"
# def list_messages(conversation_id) do
#   from(m in Message,
#     join: u in assoc(m, :user),  # Join với bảng users qua association
#     where: m.conversation_id == ^conversation_id,
#     order_by: [asc: m.inserted_at],
#     select: %{
#       id: m.id,
#       user_id: m.user_id,
#       content: m.content,
#       inserted_at: m.inserted_at,
#       user_email: u.email  # Thêm email người dùng từ bảng users
#     }
#   )
#   |> Repo.all()
# end
@doc "Lấy danh sách tin nhắn của một nhóm chat"
def list_messages(conversation_id, user_id) do
  from(m in Message,
    join: u in assoc(m, :user),  # Join với bảng users qua association
    where: m.conversation_id == ^conversation_id,
    where: m.is_deleted == false or m.user_id != ^user_id,  # Bỏ qua tin nhắn bị xóa của user_id truyền vào
    order_by: [asc: m.inserted_at],
    select: %{
      id: m.id,
      user_id: m.user_id,
      content: m.content,
      inserted_at: m.inserted_at,
      user_email: u.email  # Thêm email người dùng từ bảng users
    }
  )
  |> Repo.all()
end

 def delete_message(message_id, user_id) do
    message = Repo.get(Message, message_id)

    if message && message.user_id == user_id do
      message
      |> Ecto.Changeset.change(is_deleted: true)
      |> Repo.update()
    else
      {:error, "Bạn không có quyền xóa tin nhắn này!"}
    end
  end

  @doc "Tạo nhóm chat mới"
  def create_group(attrs \\ %{}) do
    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Thêm thành viên vào nhóm"
  def add_member(conversation_id, user_id, is_admin \\ false) do
    %GroupMember{}
    |> GroupMember.changeset(%{conversation_id: conversation_id, user_id: user_id, is_admin: is_admin})
    |> Repo.insert()
  end

  @doc "Gửi tin nhắn vào nhóm"
  def send_message(user_id, conversation_id, content, message_type \\ "text") do
  IO.inspect(%{user_id: user_id, conversation_id: conversation_id, content: content, message_type: message_type}, label: "📩 Dữ liệu gửi tin nhắn")

    %Message{}
    |> Message.changeset(%{user_id: user_id, conversation_id: conversation_id, content: content, message_type: message_type})
    |> Repo.insert()
  end

  @doc "Kiểm tra xem user có trong nhóm không"
  def is_member?(conversation_id, user_id) do
    query =
      from gm in GroupMember,
        where: gm.conversation_id == ^conversation_id and gm.user_id == ^user_id,
        select: count(gm.id)

    Repo.one(query) > 0
  end

  def recall_message(message_id, user_id) do
      case Repo.get(Message, message_id) do
        nil ->
          {:error, "Message not found"}

        %Message{user_id: ^user_id, conversation_id: conversation_id} = message ->
          changeset =
            message
            |> Ecto.Changeset.change(is_recalled: true)

          case Repo.update(changeset) do
            {:ok, updated_message} ->
              Gchatdemo1Web.Endpoint.broadcast("conversation:#{conversation_id}", "message_recalled", %{id: message_id})
              {:ok, updated_message}

            error ->
              error
          end

        _ ->
          {:error, "You can only recall your own messages"}
      end
    end

end
