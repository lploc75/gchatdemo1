defmodule Gchatdemo1Web.UserForgotPasswordLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Quên mật khẩu?
        <:subtitle>Chúng tôi sẽ gửi liên kết đặt lại mật khẩu đến hộp thư đến của bạn</:subtitle>
      </.header>
      
      <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Gửi hướng dẫn đặt lại mật khẩu
          </.button>
        </:actions>
      </.simple_form>
      
      <p class="text-center text-sm mt-4">
        <.link href={~p"/users/register"}>Đăng ký</.link>
        | <.link href={~p"/users/log_in"}>Đăng nhập</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset_password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
