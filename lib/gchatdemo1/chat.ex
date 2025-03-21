defmodule Gchatdemo1.Chat do
  import Ecto.Query, warn: false
  alias Gchatdemo1.Repo

  alias Gchatdemo1.Chat.{
    Conversation,
    GroupMember,
    Message,
    MessageStatus,
    Reaction,
    MessageEdit,
    PinnedMessage
  }

  alias Gchatdemo1.Accounts.{User, Friendship}
  @doc "Lấy danh sách các nhóm chat mà user tham gia và user_id của admin"
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

  # # "Lấy danh sách tin nhắn của một nhóm chat và emoji reactions kèm email và avatar của user"
  # def list_messages(conversation_id, user_id) do
  #   reactions_query =
  #     from(r in Reaction,
  #       where:
  #         r.message_id in subquery(
  #           from(m in Message,
  #             where: m.conversation_id == ^conversation_id,
  #             select: m.id
  #           )
  #         ),
  #       group_by: [r.message_id, r.emoji],
  #       select: %{
  #         message_id: r.message_id,
  #         emoji: coalesce(r.emoji, "unknown"),
  #         count: count(r.emoji),
  #         user_ids: fragment("jsonb_agg(?)", r.user_id)
  #       }
  #     )

  #   from(m in Message,
  #     join: u in assoc(m, :user),
  #     left_join: r in subquery(reactions_query),
  #     on: r.message_id == m.id,
  #     # Join vào tin nhắn gốc (reply_to_message) nếu có reply_to_id
  #     left_join: rm in Message,
  #     on: m.reply_to_id == rm.id,
  #     left_join: ru in User,
  #     # Lấy thông tin người gửi của tin nhắn gốc
  #     on: rm.user_id == ru.id,
  #     where: m.conversation_id == ^conversation_id,
  #     where: m.is_deleted == false or m.user_id != ^user_id,
  #     order_by: [asc: m.inserted_at],
  #     group_by: [m.id, u.email, u.avatar_url, rm.content, ru.email],
  #     select: %{
  #       id: m.id,
  #       user_id: m.user_id,
  #       content: m.content,
  #       inserted_at: m.inserted_at,
  #       is_recalled: m.is_recalled,
  #       is_edited: m.is_edited,
  #       user_email: u.email,
  #       avatar_url: u.avatar_url,
  #       reactions:
  #         fragment(
  #           "COALESCE(jsonb_object_agg(COALESCE(?, 'unknown'), jsonb_build_object('count', ?, 'users', COALESCE(?, '[]'::jsonb))), '{}')",
  #           r.emoji,
  #           r.count,
  #           r.user_ids
  #         ),
  #       reply_to_message:
  #         fragment(
  #           "CASE WHEN ? IS NOT NULL THEN jsonb_build_object('email', COALESCE(?, 'Không xác định'), 'content', COALESCE(?, '[Tin nhắn không còn tồn tại]')) ELSE NULL END",
  #           m.reply_to_id,
  #           ru.email,
  #           rm.content
  #         )
  #     }
  #   )
  #   |> Repo.all()
  # end
  def list_messages(conversation_id, user_id) do
    # ✅ Query gom reactions lại đúng cách
    reactions_query =
      from(r in Reaction,
        where:
          r.message_id in subquery(
            from(m in Message,
              where: m.conversation_id == ^conversation_id,
              select: m.id
            )
          ),
        group_by: [r.message_id, r.emoji],
        select: %{
          message_id: r.message_id,
          emoji: coalesce(r.emoji, "unknown"),
          count: count(r.emoji),
          user_ids: fragment("jsonb_agg(DISTINCT ?)", r.user_id)
        }
      )

    # ✅ Query gom trạng thái tin nhắn
    message_status_query =
      from(ms in MessageStatus,
        join: u in User,
        on: ms.user_id == u.id,
        where:
          ms.message_id in subquery(
            from(m in Message,
              where: m.conversation_id == ^conversation_id,
              select: m.id
            )
          ),
        select: %{
          message_id: ms.message_id,
          user_id: ms.user_id,
          status: ms.status,
          avatar_url: u.avatar_url,
          display_name: coalesce(u.display_name, u.email)
        }
      )

    # ✅ Query lấy tin nhắn ghim
    pinned_messages_query =
      from(pm in PinnedMessage,
        where: pm.conversation_id == ^conversation_id,
        join: m in assoc(pm, :message),
        join: u in assoc(m, :user),
        select: %{
          id: m.id,
          user_id: m.user_id,
          content: m.content,
          inserted_at: m.inserted_at,
          user_email: u.email,
          avatar_url: u.avatar_url
        }
      )

    messages =
      from(m in Message,
        join: u in assoc(m, :user),
        left_join: r in subquery(reactions_query),
        on: r.message_id == m.id,
        left_join: ms in subquery(message_status_query),
        on: ms.message_id == m.id,
        left_join: rm in Message,
        on: m.reply_to_id == rm.id,
        left_join: ru in User,
        on: rm.user_id == ru.id,
        where: m.conversation_id == ^conversation_id,
        where: m.is_deleted == false or m.user_id != ^user_id,
        order_by: [asc: m.inserted_at],
        group_by: [m.id, u.email, u.avatar_url, rm.content, ru.email],
        select: %{
          id: m.id,
          user_id: m.user_id,
          content: m.content,
          inserted_at: m.inserted_at,
          is_recalled: m.is_recalled,
          is_edited: m.is_edited,
          user_email: u.email,
          avatar_url: u.avatar_url,
          # ✅ Fix reactions bị nhân bản
          reactions:
            fragment(
              "COALESCE(jsonb_object_agg(DISTINCT COALESCE(?, 'unknown'), jsonb_build_object('count', ?, 'users', COALESCE(?, '[]'::jsonb))) FILTER (WHERE ? IS NOT NULL), '{}')",
              r.emoji,
              r.count,
              r.user_ids,
              r.emoji
            ),
          # ✅ Fix trạng thái tin nhắn bị nhân bản
          message_status:
            fragment(
              "COALESCE(jsonb_agg(DISTINCT jsonb_build_object('user_id', ?, 'status', ?, 'avatar_url', ?, 'display_name', ?)) FILTER (WHERE ? IS NOT NULL), '[]'::jsonb)",
              ms.user_id,
              ms.status,
              ms.avatar_url,
              ms.display_name,
              ms.user_id
            ),
          reply_to_message:
            fragment(
              "CASE WHEN ? IS NOT NULL THEN jsonb_build_object('email', COALESCE(?, 'Không xác định'), 'content', COALESCE(?, '[Tin nhắn không còn tồn tại]')) ELSE NULL END",
              m.reply_to_id,
              ru.email,
              rm.content
            )
        }
      )
      |> Repo.all()

    pinned_messages = Repo.all(pinned_messages_query) # ✅ Lấy danh sách tin nhắn ghim

    %{messages: messages, pinned_messages: pinned_messages} # ✅ Trả về cả tin nhắn & tin nhắn ghim
  end


  @doc "Đánh dấu tất cả tin nhắn trong nhóm chat là 'seen' cho một user"
  def mark_messages_as_seen(conversation_id, user_id) do
    from(ms in MessageStatus,
      join: m in Message,
      on: ms.message_id == m.id,
      where:
        m.conversation_id == ^conversation_id and ms.user_id == ^user_id and ms.status != "seen",
      update: [set: [status: "seen"]]
    )
    |> Repo.update_all([])

    :ok
  end

  def mark_single_message_as_seen(message_id, user_id) do
    case Repo.get_by(MessageStatus, message_id: message_id, user_id: user_id) do
      nil ->
        {:error, "Không tìm thấy trạng thái tin nhắn!"}

      message_status ->
        changeset = Ecto.Changeset.change(message_status, status: "seen")

        case Repo.update(changeset) do
          {:ok, _updated_message} -> :ok
          {:error, changeset} -> {:error, changeset.errors |> Enum.into(%{})}
        end
    end
  end

  @doc "Lấy trạng thái tin nhắn của tất cả tin nhắn trong một nhóm chat"
  def list_message_statuses_by_conversation(conversation_id) do
    from(ms in MessageStatus,
      join: m in Message,
      on: ms.message_id == m.id,
      join: u in User,
      on: ms.user_id == u.id,
      where: m.conversation_id == ^conversation_id,
      select: %{
        message_id: ms.message_id,
        user_id: ms.user_id,
        status: ms.status,
        avatar_url: u.avatar_url,
        # Nếu display_name NULL thì lấy email
        display_name: coalesce(u.display_name, u.email)
      }
    )
    |> Repo.all()
  end

  # lấy trạng thái của 1 tin nhắn từ nhiều người dùng
  def get_message_statuses(message_id) do
    from(ms in MessageStatus,
      where: ms.message_id == ^message_id,
      join: u in assoc(ms, :user),
      select: %{
        user_id: ms.user_id,
        status: ms.status,
        display_name: fragment("COALESCE(?, ?)", u.display_name, u.email),
        avatar_url: u.avatar_url
      }
    )
    |> Repo.all()
  end

  @doc "Xóa tin nhắn (chỉ user gửi tin nhắn mới có quyền xóa)"
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

  # Ghim tin nhắn
    def pin_message(attrs) do
    conversation_id = attrs[:conversation_id]
    message_id = attrs[:message_id]

    count =
      from(p in PinnedMessage, where: p.conversation_id == ^conversation_id)
      |> Repo.aggregate(:count, :id)

    if count >= 3 do
      {:error, "Chỉ có thể ghim tối đa 3 tin nhắn!"}
    else
      Repo.transaction(fn ->
        # Ghim tin nhắn
        _ =
          %PinnedMessage{}
          |> PinnedMessage.changeset(attrs)
          |> Repo.insert!()

        # Lấy thông tin đầy đủ của tin nhắn vừa ghim để chuyển về client
        from(m in Message,
          where: m.id == ^message_id,
          join: u in User, on: m.user_id == u.id,
          select: %{
            id: m.id,
            content: m.content,
            inserted_at: m.inserted_at,
            user_id: u.id,
            user_email: u.email,
            avatar_url: u.avatar_url
          }
        )
        |> Repo.one()
      end)
    end
  end

  # Bỏ ghim tin nhắn
  def unpin_message(message_id, conversation_id) do
    PinnedMessage
    |> where([p], p.message_id == ^message_id and p.conversation_id == ^conversation_id)
    |> Repo.delete_all()
  end

  # # Lấy danh sách tin nhắn đã ghim của một cuộc trò chuyện (chưa dùng)
  # def list_pinned_messages(conversation_id) do
  #   PinnedMessage
  #   |> where([p], p.conversation_id == ^conversation_id)
  #   |> Repo.all()
  # end

  @doc "Tạo hoặc cập nhật reaction (emoji)"

  def create_reaction(user_id, message_id, emoji) do
    IO.puts("✅ Đang thêm reaction mới: user #{user_id} | message #{message_id} | emoji #{emoji}")

    %Reaction{}
    |> Reaction.changeset(%{user_id: user_id, message_id: message_id, emoji: emoji})
    |> Repo.insert()
    |> case do
      {:ok, reaction} ->
        IO.puts("🎉 Thêm reaction thành công!")
        {:ok, reaction}

      {:error, changeset} ->
        IO.puts("❌ Lỗi khi thêm reaction:")
        IO.inspect(changeset.errors)
        {:error, changeset}
    end
  end

  @doc "Xóa reaction"
  def remove_reaction(message_id, user_id, emoji) do
    IO.inspect({user_id, message_id, emoji}, label: "🔍 Checking remove_reaction")

    case Repo.get_by(Reaction, message_id: message_id, user_id: user_id, emoji: emoji) do
      nil ->
        IO.inspect(
          "Reaction not found for message_id: #{message_id}, user_id: #{user_id}, emoji: #{emoji}"
        )

        {:error, "Reaction not found"}

      reaction ->
        IO.inspect("Found reaction, deleting emoji: #{emoji}...")
        Repo.delete(reaction)
    end
  end

  @doc "Lấy danh sách bạn bè của user"
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

  @doc "Tạo nhóm chat mới"
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

  # Kiểm tra có phải là admin của nhóm hay không và
  # Xóa nhóm và xóa tất cả thành viên trong nhóm
  def delete_group(conversation_id, user_id) do
    Repo.transaction(fn ->
      # Kiểm tra nhóm tồn tại và lấy thông tin admin
      case Repo.get(Conversation, conversation_id) do
        %Conversation{is_group: true} = conversation ->
          admin =
            Repo.get_by(GroupMember,
              conversation_id: conversation.id,
              user_id: user_id,
              is_admin: true
            )

          if admin do
            # Xóa tất cả thành viên trong nhóm
            Repo.delete_all(from gm in GroupMember, where: gm.conversation_id == ^conversation.id)

            # # (Tùy chọn) Xóa tất cả tin nhắn trong nhóm
            # Repo.delete_all(from m in Message, where: m.conversation_id == ^conversation.id)

            # Xóa cuộc trò chuyện
            Repo.delete(conversation)
          else
            Repo.rollback(:not_admin)
          end

        _ ->
          Repo.rollback(:group_not_found)
      end
    end)
  end

  # Cập nhật thông tin conversation (nhóm)
  def update_conversation(%Conversation{} = conversation, attrs) do
    conversation
    |> Conversation.changeset(attrs)
    |> Repo.update()
  end

  defp delete_conversation(conversation_id) do
    Repo.get_by!(Conversation, id: conversation_id)
    |> Repo.delete!()
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

  @doc "Xóa thành viên khỏi nhóm"
  def remove_member(conversation_id, user_id, admin_id) do
    Repo.transaction(fn ->
      # Kiểm tra người xóa có phải là admin không
      case Repo.get_by(GroupMember,
             conversation_id: conversation_id,
             user_id: admin_id,
             is_admin: true
           ) do
        nil ->
          Repo.rollback(:not_admin)

        _admin ->
          # Không cho phép admin tự xóa mình nếu là admin duy nhất
          is_last_admin =
            from(gm in GroupMember,
              where: gm.conversation_id == ^conversation_id and gm.is_admin == true
            )
            |> Repo.all()
            |> length() == 1

          if is_last_admin and user_id == admin_id do
            Repo.rollback(:cannot_remove_last_admin)
          end

          # Xóa thành viên khỏi nhóm
          case Repo.get_by(GroupMember, conversation_id: conversation_id, user_id: user_id) do
            nil -> Repo.rollback(:user_not_found)
            member -> Repo.delete(member)
          end
      end
    end)
  end

  @doc "Rời nhóm, nếu là admin thì chuyển quyền admin cho người khác, nếu là người cuối cùng xóa nhóm"
  def leave_group(user_id, conversation_id) do
    group_member = Repo.get_by(GroupMember, user_id: user_id, conversation_id: conversation_id)

    if group_member do
      result =
        Repo.transaction(fn ->
          # Xóa user khỏi nhóm
          Repo.delete!(group_member)

          # Kiểm tra xem nhóm còn thành viên không
          remaining_members =
            GroupMember
            |> where([gm], gm.conversation_id == ^conversation_id)
            |> order_by([gm], asc: gm.inserted_at)
            |> Repo.all()

          case remaining_members do
            [] ->
              # Nếu không còn thành viên nào, xóa nhóm
              delete_conversation(conversation_id)
              {:ok, "Bạn đã rời nhóm và nhóm đã bị xóa"}

            [new_admin | _] when group_member.is_admin ->
              # Nếu user rời nhóm là admin, chuyển quyền admin cho người lâu nhất
              new_admin
              |> Ecto.Changeset.change(is_admin: true)
              |> Repo.update!()

              {:ok, "Bạn đã rời nhóm, admin mới đã được gán"}

            _ ->
              {:ok, "Bạn đã rời nhóm thành công"}
          end
        end)

      case result do
        # Đảm bảo chỉ trả về string
        {:ok, {:ok, message}} -> {:ok, message}
        {:error, _} -> {:error, "Có lỗi xảy ra khi rời nhóm"}
      end
    else
      {:error, :not_in_group}
    end
  end

  @doc "Gửi tin nhắn vào nhóm và tạo trạng thái tin nhắn"
  def send_message(user_id, conversation_id, content, reply_to_id \\ nil, message_type \\ "text") do
    IO.inspect(
      %{
        user_id: user_id,
        conversation_id: conversation_id,
        content: content,
        message_type: message_type,
        reply_to_id: reply_to_id
      },
      label: "📩 Dữ liệu gửi tin nhắn"
    )

    Repo.transaction(fn ->
      # 1. Tạo tin nhắn
      {:ok, message} =
        %Message{}
        |> Message.changeset(%{
          user_id: user_id,
          conversation_id: conversation_id,
          content: content,
          message_type: message_type,
          reply_to_id: reply_to_id
        })
        |> Repo.insert()

      # 2. Lấy danh sách thành viên trong nhóm
      members =
        Repo.all(
          from m in Gchatdemo1.Chat.GroupMember,
            where: m.conversation_id == ^conversation_id,
            select: m.user_id
        )

      # 3. Tạo danh sách trạng thái tin nhắn cho từng thành viên trừ người gửi
      status_records =
        members
        # Loại bỏ user_id hiện tại
        |> Enum.reject(fn member_id -> member_id == user_id end)
        |> Enum.map(fn member_id ->
          %{
            message_id: message.id,
            user_id: member_id,
            # Chỉ còn trạng thái "sent", không có "seen" cho người gửi
            status: "sent",
            inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
            updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
          }
        end)

      # 4. Chèn trạng thái tin nhắn vào bảng message_statuses
      Repo.insert_all(Gchatdemo1.Chat.MessageStatus, status_records)

      message
    end)
  end

  def get_message(message_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, "Tin nhắn không tồn tại"}
      message -> {:ok, message}
    end
  end

  def forward_message(%Message{} = original_message, conversation_id, user_id) do
    params = %{
      content: original_message.content,
      message_type: original_message.message_type,
      # Người gửi mới
      user_id: user_id,
      conversation_id: conversation_id,
      is_forwarded: true,
      # Lưu ID người gửi gốc
      original_sender_id: original_message.user_id
    }

    %Message{}
    |> Message.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Tìm kiếm tin nhắn
  """
  def search_messages(params) do
    query =
      from m in Message,
        join: u in User,
        on: m.user_id == u.id,
        where: m.is_deleted == false and m.is_recalled == false,
        select: %{id: m.id, content: m.content, user_id: m.user_id, email: u.email}

    query =
      if params["conversation_id"] do
        where(query, [m, _u], m.conversation_id == ^params["conversation_id"])
      else
        query
      end

    query =
      if params["content"] do
        where(
          query,
          [m, _u],
          ilike(m.content, ^"%#{params["content"]}%")
        )
      else
        query
      end

    query =
      if params["user_id"] do
        where(query, [m], m.user_id == ^params["user_id"])
      else
        query
      end

    # query =
    #   if params["from_date"] and params["to_date"] do
    #     where(query, [m], m.inserted_at >= ^params["from_date"] and m.inserted_at <= ^params["to_date"])
    #   else
    #     query
    #   end

    # query =
    #   if params["message_type"] do
    #     where(query, [m], m.message_type == ^params["message_type"])
    #   else
    #     query
    #   end

    query
    # Hiển thị tin nhắn mới nhất trước
    |> order_by([m], desc: m.inserted_at)
    |> Repo.all()
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
