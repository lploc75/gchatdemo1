defmodule Gchatdemo1Web.UserSessionController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Accounts
  alias Gchatdemo1Web.UserAuth

  # def me(conn, _params) do
  #   user = conn.assigns.current_user  # Lấy user từ session
  #   json(conn, %{id: user.id, email: user.email})
  # end
  def get_token(conn, _params) do
    user = conn.assigns[:current_user]

    if user do
      case Gchatdemo1.Accounts.UserToken.get_token_by_user_id(user.id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "Token not found"})

        token ->
          # In ra terminal
          IO.inspect(token, label: "🔥 Token lấy từ DB")
          token = if is_binary(token), do: Base.encode64(token), else: token
          # In ra terminal
          IO.inspect(token, label: "🔥 Token sang endcode64")
          # Trả về token và user_id
          json(conn, %{token: token, user_id: user.id})
      end
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Người dùng chưa được xác thực"})
    end
  end

  # API lấy thông tin user
  def get_user_info(conn, _params) do
    user = conn.assigns.current_user

    if user do
      json(conn, %{id: user.id, email: user.email, display_name: user.display_name ,avatar_url: user.avatar_url})
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Unauthorized"})
    end
  end

  # def create(conn, %{"_action" => "registered"} = params) do
  #   create(conn, params, "Tài khoản đã được tạo thành công!")
  # end

  # def create(conn, %{"_action" => "password_updated"} = params) do
  #   conn
  #   |> put_session(:user_return_to, ~p"/users/settings")
  #   |> create(params, "Đã cập nhật mật khẩu thành công!")
  # end

  # def create(conn, params) do
  #   create(conn, params, "Chào mừng trở lại!")
  # end

  # defp create(conn, %{"user" => user_params}, info) do
  #   %{"email" => email, "password" => password} = user_params

  #   if user = Accounts.get_user_by_email_and_password(email, password) do
  #     conn
  #     |> put_flash(:info, info)
  #     |> UserAuth.log_in_user(user, user_params)
  #   else
  #     # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
  #     conn
  #     |> put_flash(:error, "Email hoặc mật khẩu không hợp lệ")
  #     |> put_flash(:email, String.slice(email, 0, 160))
  #     |> redirect(to: ~p"/users/log_in")
  #   end
  # end

  # Login
  # Thông tin của json trả về được đặt ở bên kia
  def create(conn, %{"user" => user_params}) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      UserAuth.log_in_user(conn, user)
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{success: false, error: "Email hoặc mật khẩu không hợp lệ"})
    end
  end
  def delete(conn, _params) do
    conn
    |> UserAuth.log_out_user()
    |> json(%{success: true, message: "Đã đăng xuất thành công."})
  end

end
