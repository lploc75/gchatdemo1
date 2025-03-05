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
        IO.inspect(token, label: "🔥 Token lấy từ DB")  # In ra terminal
        token = if is_binary(token), do: Base.encode64(token), else: token
        IO.inspect(token, label: "🔥 Token sang endcode64")  # In ra terminal
        json(conn, %{token: token, user_id: user.id})  # Trả về token và user_id
    end
  else
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "User not authenticated"})
  end
end

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, %{"_action" => "password_updated"} = params) do
    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, "Password updated successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
