defmodule Gchatdemo1Web.ChatController do
  use Gchatdemo1Web, :controller
  alias Gchatdemo1.Chat

  def get_groups(conn, _params) do
    user = conn.assigns[:current_user]  # Lấy thông tin user từ assigns
    groups = Chat.list_groups_for_user(user.id)  # Gọi hàm từ module Chat để lấy danh sách nhóm cho user
    json(conn, groups)  # Trả về JSON response
  end

  def get_messages(conn, %{"conversation_id" => conversation_id}) do
    user = conn.assigns[:current_user]  # Lấy thông tin user từ assigns
    messages = Chat.list_messages(conversation_id, user.id)
    json(conn, messages)
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

  def get_friends(conn, _params) do
      conn = assign(conn, :current_user, %{id: 2})

    current_user = conn.assigns[:current_user]
    friends = Chat.list_friends(current_user.id)
    json(conn, friends)
  end

  # chưa làm
  def add_member(conn, %{"conversation_id" => conversation_id, "user_id" => user_id}) do
    case Chat.add_member(conversation_id, user_id) do
      {:ok, member} -> json(conn, %{status: "ok", member: member})
      {:error, changeset} -> json(conn, %{status: "error", errors: changeset.errors})
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
