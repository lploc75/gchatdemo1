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

  def get_friends(conn, _params) do
    current_user = conn.assigns[:current_user]
    friends = Chat.list_friends(current_user.id)
    json(conn, friends)
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

  def available_friends(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns[:current_user]
    friends = Chat.list_friends_not_in_group(user.id, conversation_id)
    json(conn, %{friends: friends})
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
