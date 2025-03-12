defmodule Gchatdemo1Web.PageController do
  alias Gchatdemo1.Accounts
  use Gchatdemo1Web, :controller
  alias Gchatdemo1.Messaging

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  @spec dashboard(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def dashboard(conn, params) do
    current_user = conn.assigns.current_user
    friends = Accounts.list_friends(current_user.id)

    # Tạo danh sách bạn bè có thêm thông tin conversation
    friends_with_conversations =
      Enum.map(friends, fn friend ->
        # Lấy hoặc tạo conversation dựa trên current_user và friend.friend_id
        conversation = Messaging.get_or_create_conversation(current_user.id, friend.friend_id)
        # Nếu bạn muốn truyền toàn bộ conversation, dùng key :conversation
        Map.put(friend, :conversation, conversation)
        # Nếu chỉ cần conversation_id, có thể dùng:
        # Map.put(friend, :conversation_id, conversation.id)
      end)

    if conn.method == "POST" do
      case params do
        %{"email" => email} ->
          case Accounts.search_user_by_email(email) do
            nil ->
              conn
              |> put_flash(:error, "Không tìm thấy người dùng")
              |> render(:dashboard,
                current_user: current_user,
                searched_user: nil,
                status: nil,
                friends: friends_with_conversations
              )

            searched_user ->
              status =
                if Enum.any?(friends, fn friend -> friend.friend_id == searched_user.id end) do
                  "accepted"
                else
                  Accounts.get_friendship_status(current_user, searched_user)
                end

              render(conn, :dashboard,
                current_user: current_user,
                searched_user: searched_user,
                status: status,
                friends: friends_with_conversations
              )
          end

        _ ->
          redirect(conn, to: "/dashboard")
      end
    else
      render(conn, :dashboard,
        current_user: current_user,
        searched_user: nil,
        status: nil,
        friends: friends_with_conversations
      )
    end
  end

  # Hiển thị trang search
  def search_form(conn, _params) do
    # Truyền layout: false nếu không dùng layout chung
    render(conn, :search, layout: false)
  end

  def search(conn, %{"email" => email}) do
    current_user = conn.assigns.current_user

    case Accounts.search_user_by_email(email) do
      nil ->
        conn
        |> put_flash(:error, "Không tìm thấy người dùng")
        |> redirect(to: "/search")

      searched_user ->
        status = Accounts.get_friendship_status(current_user, searched_user)

        render(conn, :search,
          current_user: current_user,
searched_user: searched_user,
          # Thêm dòng này
          status: status
        )
    end
  end

  def send_friend_request(conn, %{"id" => friend_id}) do
    user_id = conn.assigns.current_user.id

    case Accounts.send_friend_request(user_id, friend_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Đã gửi yêu cầu kết bạn!")
        |> redirect(to: "/dashboard")

      {:error, _} ->
        conn
        |> put_flash(:error, "Không thể gửi yêu cầu")
        |> redirect(to: "/dashboard")
    end
  end

  def cancel_friend_request(conn, %{"id" => friend_id}) do
    user_id = conn.assigns.current_user.id

    case Accounts.cancel_friend_request(user_id, friend_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Đã hủy yêu cầu")
        |> redirect(to: "/dashboard")

      {:error, _} ->
        conn
        |> put_flash(:error, "Không thể hủy")
        |> redirect(to: "/dashboard")
    end
  end

  # Hiển thị danh sách lời mời kết bạn
  def friend_requests(conn, _params) do
    current_user = conn.assigns.current_user
    requests = Accounts.list_pending_friend_requests(current_user.id)

    render(conn, :friend_requests, requests: requests)
  end

  # Xử lý chấp nhận lời mời
  def accept_friend_request(conn, %{"id" => request_id}) do
    case Accounts.accept_friend_request(request_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Đã chấp nhận lời mời kết bạn")
        |> redirect(to: "/friend_requests")

      {:error, _} ->
        conn
        |> put_flash(:error, "Không thể chấp nhận lời mời")
        |> redirect(to: "/friend_requests")
    end
  end

  # Xử lý từ chối lời mời
  def decline_friend_request(conn, %{"id" => request_id}) do
    case Accounts.decline_friend_request(request_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Đã từ chối lời mời kết bạn")
        |> redirect(to: "/friend_requests")

      {:error, _} ->
        conn
        |> put_flash(:error, "Không thể từ chối lời mời")
        |> redirect(to: "/friend_requests")
    end
  end

  # Hiển thị danh sách bạn bè
  def friends(conn, _params) do
    current_user = conn.assigns.current_user
    friends = Accounts.list_friends(current_user.id)
    render(conn, :friends, friends: friends)
  end

  # Xử lý hủy kết bạn
  def unfriend(conn, %{"friend_id" => friend_id}) do
    current_user = conn.assigns.current_user
    friend_id = String.to_integer(friend_id)

    case Accounts.unfriend(current_user.id, friend_id) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Đã hủy kết bạn thành công")
        |> redirect(to: "/friends")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Không thể hủy kết bạn")
        |> redirect(to: "/friends")
    end
  end
end
