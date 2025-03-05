defmodule Gchatdemo1.Chat do
  import Ecto.Query, warn: false
  alias Gchatdemo1.Repo
  alias Gchatdemo1.Chat.{Conversation, GroupMember, Message, Reaction, MessageEdit}
  alias Gchatdemo1.Accounts.{User, Friendship}
  @doc "Lấy danh sách các nhóm chat và user_id của admin"
  def list_groups_for_user(user_id) do
    from(c in Gchatdemo1.Chat.Conversation,
      join: gm in Gchatdemo1.Chat.GroupMember,
      on: c.id == gm.conversation_id,
      where: gm.user_id == ^user_id and c.is_group == true,
      left_join: admin in Gchatdemo1.Chat.GroupMember,
      on: admin.conversation_id == c.id and admin.is_admin == true,
      select: %{conversation: c, admin_user_id: admin.user_id}
    )
    |> Repo.all()
  end

  @doc "Lấy danh sách tin nhắn của một nhóm chat kèm emoji reactions"
  # cần lấy thêm is_recalled để hiển thị tin nhắn đã thu hồi
  def list_messages(conversation_id, user_id) do
    from(m in Message,
      # Join với users
      join: u in assoc(m, :user),
      # Join với reactions
      left_join: r in Reaction,
      on: r.message_id == m.id,
      where: m.conversation_id == ^conversation_id,
      # Bỏ qua tin nhắn bị xóa của user_id
      where: m.is_deleted == false or m.user_id != ^user_id,
      order_by: [asc: m.inserted_at],
      # Nhóm theo tin nhắn
      group_by: [m.id, u.email, r.emoji],
      select: %{
        id: m.id,
        user_id: m.user_id,
        content: m.content,
        inserted_at: m.inserted_at,
        is_recalled: m.is_recalled,
        is_edited: m.is_edited,
        user_email: u.email,
        # Chỉ lấy 1 emoji
        reaction: r.emoji
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
    reaction_query =
      from(r in Reaction, where: r.user_id == ^user_id and r.message_id == ^message_id)

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

  def list_friends(current_user_id) do
    query =
      from f in Friendship,
        join: u in User,
        on:
          u.id ==
            fragment(
              "CASE WHEN ? = ? THEN ? WHEN ? = ? THEN ? END",
              f.user_id,
              ^current_user_id,
              f.friend_id,
              f.friend_id,
              ^current_user_id,
              f.user_id
            ),
        where:
          (f.user_id == ^current_user_id or f.friend_id == ^current_user_id) and
            f.status == "accepted",
        select: %{id: u.id, email: u.email}

    Repo.all(query)
  end

  def list_friends_not_in_group(current_user_id, conversation_id) do
    query =
      from f in Friendship,
        join: u in User,
        on:
          u.id ==
            fragment(
              "CASE WHEN ? = ? THEN ? WHEN ? = ? THEN ? END",
              f.user_id,
              ^current_user_id,
              f.friend_id,
              f.friend_id,
              ^current_user_id,
              f.user_id
            ),
        left_join: gm in GroupMember,
        on: gm.user_id == u.id and gm.conversation_id == ^conversation_id,
        # Chỉ lấy những người không có trong nhóm
        where:
          (f.user_id == ^current_user_id or f.friend_id == ^current_user_id) and
            f.status == "accepted" and
            is_nil(gm.id),
        select: %{id: u.id, email: u.email}

    Repo.all(query)
  end

  def create_group(attrs \\ %{}) do
    Repo.transaction(fn ->
      # Đảm bảo không trùng
      member_ids = Enum.uniq([attrs.creator_id | attrs.member_ids || []])

      if length(member_ids) < 3 do
        Repo.rollback(:not_enough_members)
      end

      # Tạo nhóm
      {:ok, conversation} =
        %Conversation{}
        |> Conversation.changeset(Map.put(attrs, :is_group, true))
        |> Repo.insert()

      # Thêm thành viên vào nhóm
      members =
        for user_id <- member_ids do
          %GroupMember{}
          |> GroupMember.changeset(%{
            conversation_id: conversation.id,
            user_id: user_id,
            is_admin: user_id == attrs.creator_id
          })
          |> Repo.insert()
        end

      if Enum.any?(members, &match?({:error, _}, &1)) do
        Repo.rollback(:member_insert_failed)
      end

      conversation
    end)
  end

  # Cập nhật thông tin conversation (nhóm)
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  @doc "Lấy danh sách thành viên của nhóm"
  def get_group_members(conversation_id) do
    from(gm in GroupMember,
      where: gm.conversation_id == ^conversation_id,
      join: u in assoc(gm, :user),
      select: %{id: u.id, email: u.email}
    )
    |> Repo.all()
  end

  @doc "Thêm thành viên vào nhóm"
  def add_member(conversation_id, user_id, is_admin \\ false) do
    %GroupMember{}
    |> GroupMember.changeset(%{
      conversation_id: conversation_id,
      user_id: user_id,
      is_admin: is_admin
    })
    |> Repo.insert()
  end

  @doc "Gửi tin nhắn vào nhóm"
  def send_message(user_id, conversation_id, content, message_type \\ "text") do
    IO.inspect(
      %{
        user_id: user_id,
        conversation_id: conversation_id,
        content: content,
        message_type: message_type
      },
      label: "📩 Dữ liệu gửi tin nhắn"
    )

    %Message{}
    |> Message.changeset(%{
      user_id: user_id,
      conversation_id: conversation_id,
      content: content,
      message_type: message_type
    })
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

      %Message{user_id: ^user_id} = message ->
        Repo.transaction(fn ->
          # 🔥 **Xóa tất cả reaction liên quan đến tin nhắn**
          Repo.delete_all(from r in Reaction, where: r.message_id == ^message_id)

          # Cập nhật tin nhắn thành "thu hồi"
          changeset = Ecto.Changeset.change(message, is_recalled: true)
          {:ok, updated_message} = Repo.update(changeset)

          updated_message
        end)

      _ ->
        {:error, "You can only recall your own messages"}
    end
  end

  def edit_message(user_id, message_id, new_content) do
    Repo.transaction(fn ->
      # Lấy tin nhắn
      message = Repo.get(Message, message_id)

      # Kiểm tra nếu tin nhắn không tồn tại
      if is_nil(message) do
        Repo.rollback(:not_found)
      end

      # Kiểm tra quyền (chỉ chủ tin nhắn được sửa)
      if message.user_id != user_id do
        Repo.rollback(:unauthorized)
      end

      # Lưu nội dung cũ vào bảng message_edits
      %MessageEdit{}
      |> MessageEdit.changeset(%{previous_content: message.content, message_id: message.id})
      |> Repo.insert!()

      # Cập nhật nội dung mới
      updated_message =
        message
        |> Message.changeset(%{content: new_content, is_edited: true})
        |> Repo.update!()

      {:ok, updated_message}
    end)
  end
end
