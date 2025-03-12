defmodule Gchatdemo1Web.ChatController do
  use Gchatdemo1Web, :controller
  alias Gchatdemo1.Chat
  alias Gchatdemo1.Repo

  def get_groups(conn, _params) do
    # Lấy thông tin user từ assigns
    user = conn.assigns[:current_user]
    # Gọi hàm từ module Chat để lấy danh sách nhóm cho user
    groups = Chat.list_groups_for_user(user.id)
    # Trả về JSON response
    json(conn, groups)
  end

  def get_messages(conn, %{"conversation_id" => conversation_id}) do
    # Lấy thông tin user từ assigns
    user = conn.assigns[:current_user]
    messages = Chat.list_messages(conversation_id, user.id)
    json(conn, messages)
  end

  def forward_message(conn, %{"message_id" => message_id, "conversation_id" => conversation_id}) do
    user_id = conn.assigns[:current_user].id

    with {:ok, original_message} <- Chat.get_message(message_id),
         {:ok, new_message} <- Chat.forward_message(original_message, conversation_id, user_id),
         new_message <- Repo.preload(new_message, [:user]) do
      conn
      |> put_status(:created)
      |> json(%{
        status: "ok",
        message: %{
          id: new_message.id,
          content: new_message.content,
          sender: "me",  # Vì user hiện tại đang forward
          email: new_message.user.email,
          reaction: nil  # Giữ nguyên format như danh sách tin nhắn hiện tại
        }
      })
    else
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "Không thể forward tin nhắn"})
    end
  end


  def search_messages(conn, params) do
    messages = Chat.search_messages(params)
    json(conn, %{messages: messages})
  end

  # Lấy danh sách bạn bè
  def get_friends(conn, _params) do
    current_user = conn.assigns[:current_user]
    friends = Chat.list_friends(current_user.id)
    json(conn, friends)
  end

  # Lấy danh sách bạn bè chưa ở trong nhóm
  def available_friends(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns[:current_user]
    friends = Chat.list_friends_not_in_group(user.id, conversation_id)
    json(conn, %{friends: friends})
  end

  def create_group(conn, %{"name" => name, "member_ids" => member_ids}) do
    with %{id: creator_id} <- conn.assigns[:current_user] do
      member_ids = Enum.uniq(member_ids)

      case Chat.create_group(%{name: name, creator_id: creator_id, member_ids: member_ids}) do
        {:ok, group} ->
          conn
          |> put_status(:ok)
          |> json(%{status: "ok", group: group})

        {:error, :not_enough_members} ->
          conn
          |> put_status(:bad_request)
          |> json(%{status: "error", message: "Cần ít nhất 3 thành viên để tạo nhóm"})

        {:error, :member_insert_failed} ->
          conn
          |> put_status(:internal_server_error)
          |> json(%{status: "error", message: "Lỗi khi thêm thành viên"})

        {:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{status: "error", errors: changeset.errors})
      end
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{status: "error", message: "Unauthorized"})
    end
  end

  def update_group(conn, %{"id" => id, "conversation" => conversation_params}) do
    # Lấy conversation từ database dựa trên ID
    # Repo.get!/2 sẽ ném lỗi nếu không tìm thấy, có thể thay bằng Repo.get/2 để xử lý lỗi mềm
    conversation = Repo.get!(Gchatdemo1.Chat.Conversation, id)

    # Gọi hàm update_conversation để cập nhật thông tin nhóm
    case Chat.update_conversation(conversation, conversation_params) do
      {:ok, updated_conversation} ->
        # Nếu cập nhật thành công, trả về JSON với status "ok"
        json(conn, %{status: "ok", conversation: updated_conversation})

      {:error, changeset} ->
        # Nếu có lỗi validate, trả về HTTP 422 với danh sách lỗi
        conn
        |> put_status(:unprocessable_entity)
        # Cần xử lý lỗi rõ ràng hơn
        |> json(%{errors: changeset.errors})
    end
  end

  def delete_group(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns[:current_user]

    case Chat.delete_group(conversation_id, user.id) do
      {:ok, _} ->
        json(conn, %{message: "Nhóm đã được xóa thành công"})

      {:error, :not_admin} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Bạn không có quyền xóa nhóm này"})

      {:error, :group_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Nhóm không tồn tại"})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Có lỗi xảy ra khi xóa nhóm"})
    end
  end

  def list_members(conn, %{"conversation_id" => conversation_id}) do
    members = Chat.get_group_members(conversation_id)

    json(conn, %{status: "ok", members: members})
  end

  def add_member(conn, %{"conversation_id" => conversation_id, "user_id" => user_id}) do
    case Chat.add_member(conversation_id, user_id) do
      {:ok, member} -> json(conn, %{status: "ok", member: member})
      {:error, changeset} -> json(conn, %{status: "error", errors: changeset.errors})
    end
  end

  def remove_member(conn, %{"conversation_id" => conversation_id, "user_id" => user_id}) do
    admin = conn.assigns[:current_user]

    case Chat.remove_member(conversation_id, user_id, admin.id) do
      {:ok, _} ->
        json(conn, %{message: "Thành viên đã bị xóa khỏi nhóm"})

      {:error, :not_admin} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Bạn không có quyền xóa thành viên"})

      {:error, :cannot_remove_last_admin} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Không thể xóa admin duy nhất khỏi nhóm"})

      {:error, :user_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Thành viên không tồn tại trong nhóm"})

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Có lỗi xảy ra khi xóa thành viên"})
    end
  end

  def leave_group(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns[:current_user]

    case Chat.leave_group(user.id, conversation_id) do
      {:ok, msg} ->
        json(conn, %{status: "ok", message: msg})

      {:error, :not_in_group} ->
        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Bạn không ở trong nhóm này!"})

        # {:error, _} ->
        #   conn
        #   |> put_status(:internal_server_error)
        #   |> json(%{status: "error", message: "Có lỗi xảy ra, vui lòng thử lại!"})
    end
  end

  #  def send_message(conn, %{"user_id" => user_id, "conversation_id" => conversation_id, "content" => content}) do
  #   case Chat.send_message(user_id, conversation_id, content) do
  #     {:ok, message} ->
  #       json(conn, %{status: "ok", message: message})

  #     {:error, changeset} ->
  #       # Xử lý lỗi từ changeset
  #       errors = changeset.errors
  #       |> Enum.map(fn {field, {message, _}} -> {Atom.to_string(field), message} end)
  #       |> Enum.into(%{})

  #       json(conn, %{status: "error", errors: errors})
  #   end
  # end
end
