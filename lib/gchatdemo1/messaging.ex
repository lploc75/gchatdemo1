defmodule Gchatdemo1.Messaging do
  import Ecto.Query
  alias Gchatdemo1.Repo
  alias Gchatdemo1.Chat.{Message}
  alias Gchatdemo1.Chat.{Reaction}
  alias Gchatdemo1.Chat.{PinnedMessage}
  alias Gchatdemo1.Chat.CallHistory
  alias Gchatdemo1.Chat.MessageStatus
  # Gửi tin nhắn
  def send_message(user_id, conversation_id, content, opts \\ %{}) do
    Repo.transaction(fn ->
      # Tạo message như bình thường
      {:ok, message} =
        %Message{}
        |> Message.changeset(%{
          user_id: user_id,
          conversation_id: conversation_id,
          content: content,
          is_forwarded: opts[:is_forwarded] || false,
          original_sender_id: opts[:original_sender_id],
          reply_to_id: opts[:reply_to_id]
        })
        |> Repo.insert()

      # Chỉ tạo một bản ghi MessageStatus cho người gửi
      status = %{
        message_id: message.id,
        user_id: user_id,
        status: "sent",
        inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      }

      # Chèn bản ghi trạng thái duy nhất
      Repo.insert_all(MessageStatus, [status], on_conflict: :nothing)

      # Trả về message với các association đã preload
      message
      |> Repo.preload([:user, :conversation, :reactions, :original_sender, :message_statuses])
    end)
  end

  # Chỉnh sửa tin nhắn
  def edit_message(message_id, new_content) do
    Repo.get(Message, message_id)
    |> Message.changeset(%{content: new_content, is_edited: true})
    |> Repo.update()
    |> case do
      {:ok, message} ->
        message_with_assoc = Repo.preload(message, [:user, :conversation, :reactions])
        {:ok, message_with_assoc}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def recall_message(message_id) do
    # Lấy message từ database
    message = Repo.get(Message, message_id)

    # Kiểm tra message có tồn tại không
    if message do
      # Xóa các emoji (reactions) của tin nhắn đó trong DB
      Repo.delete_all(from r in Reaction, where: r.message_id == ^message_id)

      # Cập nhật trạng thái is_recalled
      case Message.changeset(message, %{is_recalled: true}) |> Repo.update() do
        {:ok, message} ->
          # Preload các associations để trả về dữ liệu đầy đủ
          message_with_assoc = Repo.preload(message, [:user, :conversation, :reactions])
          {:ok, message_with_assoc}

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      {:error, :message_not_found}
    end
  end

  # Lấy danh sách tin nhắn giữa 2 người dùng
  def list_messages(conversation_id) do
    Repo.all(
      from m in Message,
        where: m.conversation_id == ^conversation_id,
        # Thêm message_statuses
        preload: [:reactions, :user, :conversation, :message_statuses],
        order_by: [asc: m.inserted_at]
    )
  end

  # Hỗ trợ cập nhật trạng thái
  def mark_message_as_delivered(message_id, user_id) do
    case Repo.get_by(MessageStatus, message_id: message_id, user_id: user_id) do
      nil ->
        Repo.insert(%MessageStatus{
          message_id: message_id,
          user_id: user_id,
          status: "delivered",
          inserted_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          updated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
        })

      status ->
        Repo.update(MessageStatus.changeset(status, %{status: "delivered"}))
    end
  end

  # Hàm cập nhật tất cả tin nhắn chưa đọc
  def mark_messages_as_seen(conversation_id, reader_id) do
    # Lấy tất cả message IDs chưa seen của conversation
    message_ids =
      from(m in Message,
        join: ms in MessageStatus,
        on: ms.message_id == m.id,
        where:
          m.conversation_id == ^conversation_id and ms.user_id == ^reader_id and
            ms.status != "seen",
        select: m.id
      )
      |> Repo.all()

    # Cập nhật hàng loạt
    from(ms in MessageStatus,
      where: ms.message_id in ^message_ids and ms.user_id == ^reader_id
    )
    |> Repo.update_all(set: [status: "seen"])
  end

  def delete_message(message_id) do
    message = Repo.get(Message, message_id)
    Repo.delete(message)
  end

  def get_message(message_id) do
    Message
    |> Repo.get(message_id)
    |> Repo.preload([:user, :conversation, :original_sender, :reactions])
  end

  def add_reaction(message_id, user_id, emoji) do
    case Repo.get_by(Reaction, message_id: message_id, user_id: user_id) do
      nil ->
        %Reaction{}
        |> Reaction.changeset(%{
          message_id: message_id,
          user_id: user_id,
          emoji: emoji
        })
        |> Repo.insert()

      existing_reaction ->
        if existing_reaction.emoji == emoji do
          Repo.delete(existing_reaction)
        else
          existing_reaction
          |> Reaction.changeset(%{emoji: emoji})
          |> Repo.update()
        end
    end
  end

  def get_reactions(message_id) do
    Repo.all(
      from r in Reaction,
        where: r.message_id == ^message_id,
        preload: [:user]
    )
  end

  def get_conversation(conversation_id) do
    Gchatdemo1.Chat.Conversation
    |> Repo.get(conversation_id)
    # Preload các association nếu cần, chẳng hạn như group_members
    |> Repo.preload(:group_members)
  end

  def get_or_create_conversation(user1_id, user2_id) do
    # Tìm conversation_id nếu cả hai user cùng trong một nhóm
    conversation_id =
      from(gm1 in Gchatdemo1.Chat.GroupMember,
        join: gm2 in Gchatdemo1.Chat.GroupMember,
        on: gm1.conversation_id == gm2.conversation_id,
        where: gm1.user_id == ^user1_id and gm2.user_id == ^user2_id,
        select: gm1.conversation_id,
        limit: 1
      )
      |> Repo.one()

    case conversation_id do
      nil ->
        # Nếu chưa có, tạo mới conversation
        changeset =
          Gchatdemo1.Chat.Conversation.changeset(%Gchatdemo1.Chat.Conversation{}, %{
            name: "Private Chat",
            is_group: false,
            creator_id: user1_id
          })

        case Repo.insert(changeset) do
          {:ok, new_conversation} ->
            # Thêm user1 vào bảng `group_members`
            Repo.insert!(%Gchatdemo1.Chat.GroupMember{
              conversation_id: new_conversation.id,
              user_id: user1_id
            })

            # Thêm user2 vào bảng `group_members`
            Repo.insert!(%Gchatdemo1.Chat.GroupMember{
              conversation_id: new_conversation.id,
              user_id: user2_id
            })

            # Trả về ID thay vì {:ok, conversation}
            new_conversation.id

          {:error, _changeset} ->
            # Trả về nil nếu có lỗi
            nil
        end

      conversation_id ->
        # Nếu đã tồn tại, trả về ID của conversation
        conversation_id
    end
  end

  def get_or_create_conversation_forward(user1_id, user2_id) do
    # Tìm conversation_id nếu cả hai user cùng trong một nhóm
    conversation_id =
      from(gm1 in Gchatdemo1.Chat.GroupMember,
        join: gm2 in Gchatdemo1.Chat.GroupMember,
        on: gm1.conversation_id == gm2.conversation_id,
        where: gm1.user_id == ^user1_id and gm2.user_id == ^user2_id,
        select: gm1.conversation_id,
        limit: 1
      )
      |> Repo.one()

    case conversation_id do
      nil ->
        # Nếu chưa có, tạo mới conversation
        changeset =
          Gchatdemo1.Chat.Conversation.changeset(%Gchatdemo1.Chat.Conversation{}, %{
            name: "Private Chat",
            is_group: false,
            creator_id: user1_id
          })

        case Repo.insert(changeset) do
          {:ok, new_conversation} ->
            # Thêm user1 vào bảng `group_members`
            Repo.insert!(%Gchatdemo1.Chat.GroupMember{
              conversation_id: new_conversation.id,
              user_id: user1_id
            })

            # Thêm user2 vào bảng `group_members`
            Repo.insert!(%Gchatdemo1.Chat.GroupMember{
              conversation_id: new_conversation.id,
              user_id: user2_id
            })

            # Trả về {:ok, conversation_id}
            {:ok, new_conversation.id}

          {:error, changeset} ->
            # Trả về {:error, reason} nếu có lỗi
            {:error, changeset}
        end

      conversation_id ->
        # Nếu đã tồn tại, trả về {:ok, conversation_id}
        {:ok, conversation_id}
    end
  end

  @doc """
  Ghim tin nhắn nếu chưa được ghim.
  Trả về {:ok, pinned_message} nếu ghim thành công,
  hoặc {:error, :already_pinned} nếu tin nhắn đã được ghim,
  hoặc {:error, changeset} nếu có lỗi trong quá trình insert.
  """
  def pin_message(attrs) do
    %PinnedMessage{}
    |> PinnedMessage.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, pinned} ->
        {:ok, pinned}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Lỗi khi ghim tin nhắn")
        {:error, changeset}
    end
  end

  @doc """
  Gỡ ghim tin nhắn theo conversation_id và message_id.
  Trả về {:ok, pinned_message} nếu xóa thành công,
  hoặc {:error, :not_found} nếu không tìm thấy.
  """
  def unpin_message(conversation_id, message_id) do
    case Repo.get_by(PinnedMessage, conversation_id: conversation_id, message_id: message_id) do
      nil -> {:error, :not_found}
      pinned_message -> Repo.delete(pinned_message)
    end
  end

  def list_pinned_messages(conversation_id) do
    from(pm in PinnedMessage,
      join: m in assoc(pm, :message),
      where: pm.conversation_id == ^conversation_id and m.is_recalled == false,
      preload: [message: :user]
    )
    |> Repo.all()
    |> Enum.map(& &1.message)
  end

  def list_call_history(conversation_id) do
    Repo.all(
      from ch in Gchatdemo1.Chat.CallHistory,
        where: ch.conversation_id == ^conversation_id,
        order_by: [desc: ch.inserted_at],
        preload: [:caller, :callee]
    )
  end

  def create_call_history(
        conversation_id,
        caller_id,
        callee_id,
        status,
        started_at \\ nil,
        ended_at \\ nil
      ) do
    duration = if started_at && ended_at, do: NaiveDateTime.diff(ended_at, started_at), else: 0

    %CallHistory{}
    |> CallHistory.changeset(%{
      conversation_id: conversation_id,
      caller_id: caller_id,
      callee_id: callee_id,
      status: status,
      call_type: "video",
      started_at: started_at,
      ended_at: ended_at,
      duration: duration
    })
    |> Repo.insert()
  end
end
