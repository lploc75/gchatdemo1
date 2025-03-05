defmodule Gchatdemo1Web.UserConfirmationInstructionsLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Accounts

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Không nhận được hướng dẫn xác nhận?
        <:subtitle>Chúng tôi sẽ gửi liên kết xác nhận mới đến hộp thư đến của bạn</:subtitle>
      </.header>
      
      <.simple_form for={@form} id="resend_confirmation_form" phx-submit="send_instructions">
        <.input field={@form[:email]} type="email" placeholder="Email" required />
        <:actions>
          <.button phx-disable-with="Sending..." class="w-full">
            Gửi lại hướng dẫn xác nhận
          </.button>
        </:actions>
      </.simple_form>
      
      <p class="text-center mt-4">
        <.link href={~p"/users/register"}>Đăng ký</.link>
        | <.link href={~p"/users/log_in"}>Đăng nhập</.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_confirmation_instructions(
        user,
        &url(~p"/users/confirm/#{&1}")
      )
    end

    info =
      "If your email is in our system and it has not been confirmed yet, you will receive an email with instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
