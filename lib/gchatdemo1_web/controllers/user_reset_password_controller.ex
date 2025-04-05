defmodule Gchatdemo1Web.UserResetPasswordController do
  use Gchatdemo1Web, :controller
  # Gọi module Accounts để xử lý các hành động liên quan đến người dùng
  alias Gchatdemo1.Accounts

  # API: Kiểm tra token reset password có hợp lệ không
  def check_token(conn, %{"token" => token}) do
    # Gọi hàm kiểm tra xem token có đúng và còn hạn không
    if Accounts.get_user_by_reset_password_token(token) do
      # Token hợp lệ => trả về JSON báo thành công
      json(conn, %{success: true})
    else
      # Token không hợp lệ hoặc đã hết hạn
      json(conn, %{
        success: false,
        error: "Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn."
      })
    end
  end

  # API: Đặt lại mật khẩu cho người dùng dựa vào token và mật khẩu mới
  def reset_password(conn, %{
        "token" => token,
        "password" => password,
        "password_confirmation" => password_confirmation
      }) do
    # Sử dụng pattern matching và `with` để xử lý nhiều bước:
    # B1: Tìm user từ token reset password
    # B2: Nếu tìm thấy, gọi hàm reset password với password mới và confirm
    with user when not is_nil(user) <- Accounts.get_user_by_reset_password_token(token),
         {:ok, _user} <-
           Accounts.reset_user_password(user, %{
             "password" => password,
             "password_confirmation" => password_confirmation
           }) do
      # Thành công => trả về thông báo đặt lại mật khẩu thành công
      json(conn, %{success: true, message: "Mật khẩu đã được đặt lại thành công."})
    else
      # Nếu không tìm thấy user theo token
      nil ->
        json(conn, %{
          success: false,
          error: "Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn."
        })

      # Nếu reset password thất bại do validation (mật khẩu yếu, không khớp...)
      {:error, _changeset} ->
        json(conn, %{success: false, error: "Mật khẩu không hợp lệ."})
    end
  end
end
