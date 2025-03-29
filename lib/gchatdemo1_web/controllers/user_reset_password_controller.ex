defmodule Gchatdemo1Web.UserResetPasswordController do
  use Gchatdemo1Web, :controller
  alias Gchatdemo1.Accounts

  def check_token(conn, %{"token" => token}) do
    if Accounts.get_user_by_reset_password_token(token) do
      json(conn, %{success: true})
    else
      json(conn, %{success: false, error: "Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn."})
    end
  end

  def reset_password(conn, %{"token" => token, "password" => password, "password_confirmation" => password_confirmation}) do
    with user when not is_nil(user) <- Accounts.get_user_by_reset_password_token(token),
         {:ok, _user} <- Accounts.reset_user_password(user, %{"password" => password, "password_confirmation" => password_confirmation}) do
      json(conn, %{success: true, message: "Mật khẩu đã được đặt lại thành công."})
    else
      nil ->
        json(conn, %{success: false, error: "Liên kết đặt lại mật khẩu không hợp lệ hoặc đã hết hạn."})

      {:error, _changeset} ->
        json(conn, %{success: false, error: "Mật khẩu không hợp lệ."})
    end
  end
end
