defmodule Gchatdemo1Web.UserForgotPasswordController do
  use Gchatdemo1Web, :controller

  # Gọi module Accounts để xử lý các chức năng liên quan đến người dùng
  alias Gchatdemo1.Accounts

  # API: Gửi email đặt lại mật khẩu
  def send_reset_email(conn, %{"email" => email}) do
    # Regex kiểm tra định dạng email có hợp lệ không
    email_regex = ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/

    # Nếu email không đúng định dạng thì trả lỗi luôn
    if !Regex.match?(email_regex, email) do
      json(conn, %{
        success: false,
        error: "Email không hợp lệ. Vui lòng nhập đúng định dạng."
      })
    else
      # Nếu tìm thấy người dùng với email đó thì gửi email reset password
      if user = Accounts.get_user_by_email(email) do
        Accounts.deliver_user_reset_password_instructions(
          user,
          &url(~p"/users/reset_password/#{&1}")
        )
      end

      # Luôn trả về thông báo thành công (kể cả khi email không tồn tại),
      # để tránh tiết lộ hệ thống có user đó hay không (bảo mật)
      json(conn, %{
        success: true,
        message:
          "Nếu email của bạn có trong hệ thống, bạn sẽ nhận được hướng dẫn đặt lại mật khẩu."
      })
    end
  end
end
