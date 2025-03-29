defmodule Gchatdemo1Web.UserConfirmationController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Accounts

  def confirm_account(conn, %{"token" => token}) do
    case Accounts.confirm_user(token) do
      {:ok, _} ->
        json(conn, %{status: "success", message: "Xác nhận tài khoản thành công."})

      :error ->
        json(conn, %{status: "error", message: "Liên kết xác nhận không hợp lệ hoặc đã hết hạn."})
    end
  end

  def send_instructions(conn, %{"email" => email}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    json(conn, %{
      message:
        "Nếu email của bạn có trong hệ thống và chưa được xác nhận, bạn sẽ nhận được email hướng dẫn trong giây lát."
    })
  end
end
