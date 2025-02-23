defmodule Gchatdemo1Web.UserSocket do
  use Phoenix.Socket

  ## Định nghĩa các channels
  channel "group_chat:*", Gchatdemo1Web.GroupChatChannel

 ## Authentication
def connect(%{"token" => token}, socket, _connect_info) do
  IO.inspect(token, label: "🔍 Received Token (String)")

  case Base.decode64(token) do
    {:ok, binary_token} ->
      IO.inspect(binary_token, label: "🔄 Decoded Token (Binary)")

      case Gchatdemo1.Accounts.get_user_by_session_token(binary_token) do
        nil ->
          IO.puts("❌ Token không hợp lệ hoặc user không tồn tại!")
          :error

        user ->
          IO.inspect(user, label: "✅ User Authenticated")
          {:ok, assign(socket, :user_id, user.id)}
      end

    :error ->
      IO.puts("❌ Không thể giải mã token!")
      :error
  end
end

  # Định danh cho socket (có thể dùng để theo dõi user online)
  def id(_socket), do: nil
end
