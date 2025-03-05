defmodule Gchatdemo1Web.UserLoginLive do
  use Gchatdemo1Web, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">
        Đăng nhập vào tài khoản
        <:subtitle>
          Không có tài khoản?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Đăng ký
          </.link>
          tài khoản mới ngay.
        </:subtitle>
      </.header>
      
      <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:password]} type="password" label="Mật khẩu" required />
        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Giữ tôi đăng nhập" />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
            Quên mật khẩu?
          </.link>
        </:actions>
        
        <:actions>
          <.button phx-disable-with="Logging in..." class="w-full">
            Đăng nhập <span aria-hidden="true">→</span>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
