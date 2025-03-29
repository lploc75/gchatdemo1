defmodule Gchatdemo1Web.PageController do
  alias Gchatdemo1.Accounts
  use Gchatdemo1Web, :controller
  alias Gchatdemo1.Messaging

  # Điểm vào SPA
  def home(conn, _params) do
    # Trang home thường dùng layout riêng, nên render với layout: false
    render(conn, :home, layout: false)
  end

  def index(conn, _params) do
    render(conn, :dashboard, layout: false)
  end

  def register(conn, _params) do
    render(conn, :register, layout: false)
  end

  def log_in(conn, _params) do
    render(conn, :log_in, layout: false)
  end

  # Trang gửi yêu cầu quên mật khẩu
  def forgot_password(conn, _params) do
    render(conn, :forgot_password, layout: false)
  end
  # Trang reset mật khẩu
  def reset_password(conn, %{"token" => token}) do
    render(conn, :reset_password, layout: false, token: token)
  end
  # Trang xác nhận email
  def confirm_email(conn, %{"token" => token}) do
    render(conn, :confirm_email, layout: false, token: token)
  end
  # Trang gửi lại hướng dẫn xác nhận email
  def confirm_email_instructions(conn, _params) do
    render(conn, :confirm_email_instructions, layout: false)
  end

  def user_setting(conn, _params) do
    render(conn, :user_setting, layout: false)
  end
  def user_setting_confirm_email(conn, %{"token" => token}) do
    render(conn, :user_setting, layout: false, token: token)
  end

  def list_friends(conn, _params) do
    render(conn, :list_friends, layout: false)
  end

  def friend_requests_page(conn, _params) do
    render(conn, :friend_requests, layout: false)
  end

  # Dashboard chỉ hiển thị thông tin chung (không còn chứa form tìm kiếm bạn bè)
  def dashboard(conn, _params) do
    # Lấy trực tiếp struct User từ conn.assigns
    current_user = conn.assigns.current_user

    # Lấy danh sách bạn bè dựa trên ID của current_user
    friends =
      current_user.id
      |> Accounts.list_friends()
      # Để debug nếu cần
      |> IO.inspect(label: "friends")
      |> Enum.map(fn friend ->
        # Lấy hoặc tạo cuộc hội thoại
        conversation_id = Messaging.get_or_create_conversation(current_user.id, friend.friend_id)
        # Để debug nếu cần
        IO.inspect(conversation_id, label: "conversation")

        %{
          id: friend.friend_id,
          email: friend.email,
          avatar_url: friend.avatar_url,
          conversation_id: conversation_id
        }
      end)

    # Trả về JSON response
    json(conn, %{
      current_user: %{
        id: current_user.id,
        email: current_user.email,
        avatar_url: current_user.avatar_url
      },
      friends: friends
    })
  end

  # Action friends dùng để hiển thị danh sách bạn bè và xử lý tìm kiếm bạn bè
  def friends(conn, params) do
    current_user = conn.assigns.current_user

    friends =
      current_user.id
      |> Accounts.list_friends()
      |> Enum.map(fn friend ->
        conversation_id = Messaging.get_or_create_conversation(current_user.id, friend.friend_id)

        %{
          id: friend.friend_id,
          email: friend.email,
          avatar_url: friend.avatar_url,
          conversation_id: conversation_id
        }
      end)

    if conn.method == "POST" do
      case params do
        %{"email" => email} ->
          case Accounts.search_user_by_email(email) do
            nil ->
              json(conn, %{error: "Không tìm thấy người dùng haha", friends: friends})

            searched_user ->
              status =
                if Enum.any?(friends, fn friend -> friend.id == searched_user.id end) do
                  "accepted"
                else
                  Accounts.get_friendship_status(current_user, searched_user)
                end

              json(conn, %{
                searched_user: %{
                  id: searched_user.id,
                  email: searched_user.email,
                  avatar_url: searched_user.avatar_url
},
                status: status,
                # Thêm friends vào response
                friends: friends
              })
          end

        _ ->
          json(conn, %{error: "Thiếu email", friends: friends})
      end
    else
      json(conn, %{
        current_user: %{
          id: current_user.id,
          email: current_user.email,
          avatar_url: current_user.avatar_url
        },
        friends: friends
      })
    end
  end

  def send_friend_request(conn, %{"id" => friend_id}) do
    user_id = conn.assigns.current_user.id

    case Accounts.send_friend_request(user_id, friend_id) do
      {:ok, _} ->
        json(conn, %{success: true, message: "Đã gửi yêu cầu kết bạn!"})

      {:error, reason} ->
        json(conn, %{success: false, message: "Không thể gửi yêu cầu: #{reason}"})
    end
  end

  def cancel_friend_request(conn, %{"id" => friend_id}) do
    user_id = conn.assigns.current_user.id

    case Accounts.cancel_friend_request(user_id, friend_id) do
      {:ok, _} ->
        json(conn, %{success: true, message: "Đã hủy yêu cầu"})

      {:error, reason} ->
        json(conn, %{success: false, message: "Không thể hủy: #{reason}"})
    end
  end

  def friend_requests(conn, _params) do
    current_user = conn.assigns.current_user

    requests =
      Accounts.list_pending_friend_requests(current_user.id)
      |> Enum.map(fn req ->
        %{
          id: req.id,
          sender_id: req.sender_id,
          sender_email: Accounts.get_user!(req.sender_id).email,
          sender_avatar: Accounts.get_user!(req.sender_id).avatar_url
        }
      end)

    json(conn, %{requests: requests})
  end

  def accept_friend_request(conn, %{"id" => request_id}) do
    case Accounts.accept_friend_request(request_id) do
      {:ok, _} ->
        json(conn, %{success: true, message: "Đã chấp nhận lời mời kết bạn"})

      {:error, reason} ->
        json(conn, %{success: false, message: "Không thể chấp nhận: #{reason}"})
    end
  end

  def decline_friend_request(conn, %{"id" => request_id}) do
    case Accounts.decline_friend_request(request_id) do
      {:ok, _} ->
        json(conn, %{success: true, message: "Đã từ chối lời mời kết bạn"})

      {:error, reason} ->
        json(conn, %{success: false, message: "Không thể từ chối: #{reason}"})
    end
  end

  def unfriend(conn, %{"friend_id" => friend_id}) do
    current_user = conn.assigns.current_user
    friend_id = String.to_integer(friend_id)

    case Accounts.unfriend(current_user.id, friend_id) do
      {:ok, _} ->
        json(conn, %{success: true, message: "Đã hủy kết bạn thành công"})

      {:error, reason} ->
        json(conn, %{success: false, message: "Không thể hủy kết bạn: #{reason}"})
    end
  end

  def convert_stream(conn, %{"streamer_name" => streamer_name, "stream_id" => stream_id}) do
    render(conn, :convert_stream, streamer_name: streamer_name, stream_id: stream_id)
  end
end
