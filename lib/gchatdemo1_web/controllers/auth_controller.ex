defmodule Gchatdemo1Web.AuthController do
  use Gchatdemo1Web, :controller

  alias Gchatdemo1.Accounts

  def register(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &"http://localhost:5173/user-confirmation/#{&1}"
          )

        json(conn, %{success: true, message: "Đăng ký thành công! Kiểm tra email để xác nhận tài khoản."})

      {:error, %Ecto.Changeset{} = changeset} ->
        json(conn, %{success: false, errors: transform_errors(changeset.errors)})
      end
  end
  defp transform_errors(errors) do
    Enum.into(errors, %{}, fn
      {:email, {"has already been taken", _opts}} -> {:email, "Email này đã được sử dụng!"}
      {field, {message, _opts}} -> {field, message}
    end)
  end

end
