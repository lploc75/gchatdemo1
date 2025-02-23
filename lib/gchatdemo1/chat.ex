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
def list_messages(conversation_id) do
  from(m in Message,
    join: u in assoc(m, :user),  # Join với bảng users qua association
    where: m.conversation_id == ^conversation_id,
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

end
