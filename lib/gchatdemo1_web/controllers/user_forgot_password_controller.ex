defmodule Gchatdemo1Web.UserForgotPasswordController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Accounts

  def send_reset_email(conn, %{"email" => email}) do
    email_regex = ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/

    if !Regex.match?(email_regex, email) do
      json(conn, %{
        success: false,
        error: "Email không hợp lệ. Vui lòng nhập đúng định dạng."})
    else
      if user = Accounts.get_user_by_email(email) do
        Accounts.deliver_user_reset_password_instructions(
          user,
          &url(~p"/users/reset_password/#{&1}")
        )
      end

      json(conn, %{
        success: true,
        message: "Nếu email của bạn có trong hệ thống, bạn sẽ nhận được hướng dẫn đặt lại mật khẩu."
      })
    end
  end

end
