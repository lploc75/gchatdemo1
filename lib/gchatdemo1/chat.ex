defmodule Gchatdemo1.Chat do
  import Ecto.Query, warn: false
  alias Gchatdemo1.Repo
  alias Gchatdemo1.Chat.{Conversation, GroupMember, Message, Reaction, MessageEdit}

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
# def list_messages(conversation_id, user_id) do
#   from(m in Message,
#     join: u in assoc(m, :user),  # Join với bảng users qua association
#     where: m.conversation_id == ^conversation_id,
#     where: m.is_deleted == false or m.user_id != ^user_id,  # Bỏ qua tin nhắn bị xóa của user_id truyền vào
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
@doc "Lấy danh sách tin nhắn của một nhóm chat kèm emoji reactions"
# cần lấy thêm is_recalled để hiển thị tin nhắn đã thu hồi
def list_messages(conversation_id, user_id) do
  from(m in Message,
    join: u in assoc(m, :user),  # Join với users
    left_join: r in Reaction, on: r.message_id == m.id,  # Join với reactions
    where: m.conversation_id == ^conversation_id,
    where: m.is_deleted == false or m.user_id != ^user_id,  # Bỏ qua tin nhắn bị xóa của user_id
    order_by: [asc: m.inserted_at],
    group_by: [m.id, u.email, r.emoji],  # Nhóm theo tin nhắn
    select: %{
      id: m.id,
      user_id: m.user_id,
      content: m.content,
      inserted_at: m.inserted_at,
      is_recalled: m.is_recalled,
      user_email: u.email,
      reaction: r.emoji  # Chỉ lấy 1 emoji
    }
  )
  |> Repo.all()
end

  @doc "Xóa tin nhắn"
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

  @doc "Tạo hoặc cập nhật reaction"
  def create_or_update_reaction(user_id, message_id, emoji) do
    reaction_query = from(r in Reaction, where: r.user_id == ^user_id and r.message_id == ^message_id)

    case Repo.one(reaction_query) do
      nil ->
        IO.puts("✅ Thêm reaction mới")
        %Reaction{}
        |> Reaction.changeset(%{user_id: user_id, message_id: message_id, emoji: emoji})
        |> Repo.insert()

      reaction ->
        IO.puts("🔄 Cập nhật emoji mới cho reaction")
        reaction
        |> Reaction.changeset(%{emoji: emoji})
        |> Repo.update()
    end
  end
  def remove_reaction(message_id, user_id) do
  IO.inspect({user_id, message_id}, label: "🔍 Checking remove_reaction")

  case Repo.get_by(Reaction, message_id: message_id, user_id: user_id) do
    nil ->
      IO.inspect("Reaction not found for message_id: #{message_id} and user_id: #{user_id}")
      {:error, "Reaction not found"}
    reaction ->
      IO.inspect("Found reaction, deleting...")
      Repo.delete(reaction)
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

  # Thu hồi tin nhắn
  def recall_message(message_id, user_id) do
    case Repo.get(Message, message_id) do
      nil ->
        {:error, "Message not found"}

      %Message{user_id: ^user_id, conversation_id: conversation_id} = message ->
        Repo.transaction(fn ->
          # 🔥 **Xóa tất cả reaction liên quan đến tin nhắn**
          Repo.delete_all(from r in Reaction, where: r.message_id == ^message_id)

          # Cập nhật tin nhắn thành "thu hồi"
          changeset = Ecto.Changeset.change(message, is_recalled: true)
          {:ok, updated_message} = Repo.update(changeset)

          # 📢 Broadcast sự kiện để frontend cập nhật
          # Gchatdemo1Web.Endpoint.broadcast("conversation:#{conversation_id}", "message_recalled", %{
          #   id: message_id
          # })

          updated_message
        end)

      _ ->
        {:error, "You can only recall your own messages"}
    end
  end

 def edit_message(message_id, new_content) do
    Repo.transaction(fn ->
      message = Repo.get!(Message, message_id)

      # Lưu nội dung cũ vào message_edits
      %MessageEdit{}
      |> MessageEdit.changeset(%{previous_content: message.content, message_id: message.id})
      |> Repo.insert!()

      # Cập nhật tin nhắn
      message
      |> Message.changeset(%{content: new_content, is_edited: true})
      |> Repo.update!()
    end)
  end

end
