defmodule Gchatdemo1Web.UserSessionController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Accounts
  # Module xử lý đăng nhập/đăng xuất
  alias Gchatdemo1Web.UserAuth

  # API: Lấy token xác thực hiện tại của người dùng
  def get_token(conn, _params) do
    # Lấy người dùng hiện tại từ conn (qua plug đã gắn vào)
    user = conn.assigns[:current_user]

    if user do
      case Gchatdemo1.Accounts.UserToken.get_token_by_user_id(user.id) do
        nil ->
          # Không tìm thấy token trong DB
          conn
          |> put_status(:not_found)
          |> json(%{error: "Token not found"})

        token ->
          # In ra terminal
          IO.inspect(token, label: "🔥 Token lấy từ DB")
          # Nếu token là binary, encode sang base64 để frontend sử dụng
          token = if is_binary(token), do: Base.encode64(token), else: token
          # In ra terminal
          IO.inspect(token, label: "🔥 Token sang endcode64")
          # Trả về token và user_id
          json(conn, %{token: token, user_id: user.id})
      end
    else
      # Nếu chưa xác thực => 401 Unauthorized
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Người dùng chưa được xác thực"})
    end
  end

  # API: Lấy thông tin người dùng đang đăng nhập
  def get_user_info(conn, _params) do
    # Lấy user từ conn (gắn bởi plug)
    user = conn.assigns.current_user

    if user do
      # Trả về thông tin user
      json(conn, %{
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        avatar_url: user.avatar_url
      })
    else
      # Nếu không có user => trả lỗi 401
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized"})
    end
  end

  # API: Đăng nhập người dùng
  # Thông tin của json trả về được đặt ở bên kia
  def create(conn, %{"user" => user_params}) do
    # Lấy thông tin email và mật khẩu
    %{"email" => email, "password" => password} = user_params

    # Kiểm tra thông tin đăng nhập
    if user = Accounts.get_user_by_email_and_password(email, password) do
      # Nếu đúng, thực hiện login (set session / token)
      UserAuth.log_in_user(conn, user)
    else
      # Nếu sai thông tin => 401 Unauthorized
      conn
      |> put_status(:unauthorized)
      |> json(%{success: false, error: "Email hoặc mật khẩu không hợp lệ"})
    end
  end

  # API: Đăng xuất người dùng
  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> json(%{success: true, message: "Đã đăng xuất thành công."})
  end
end
