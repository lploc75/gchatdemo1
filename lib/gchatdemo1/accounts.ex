defmodule Gchatdemo1.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Gchatdemo1.Repo
  alias Gchatdemo1.Accounts.{User, UserToken, UserNotifier}
  # Thêm alias cho Friendship
  alias Gchatdemo1.Accounts.{User, Friendship}
  alias Gchatdemo1.Chat.Conversation
  alias Gchatdemo1.Chat.GroupMember
  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
         %UserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(user_email_multi(user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp user_email_multi(user, email, context) do
    changeset =
      user
      |> User.email_changeset(%{email: email})
      |> User.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm_email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)
    UserNotifier.deliver_update_email_instructions(user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, &url(~p"/users/confirm/#{&1}"))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, &url(~p"/users/confirm/#{&1}"))
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, user_token} = UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a user by the given token.

  If the token matches, the user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_user(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "confirm"),
         %User{} = user <- Repo.one(query),
         {:ok, %{user: user}} <- Repo.transaction(confirm_user_multi(user)) do
      {:ok, user}
    else
      _ -> :error
    end
  end

  defp confirm_user_multi(user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.confirm_changeset(user))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, ["confirm"]))
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, &url(~p"/users/reset_password/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    with {:ok, query} <- UserToken.verify_email_token_query(token, "reset_password"),
         %User{} = user <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  @doc """
  Cập nhật avatar của người dùng.

  ## Examples

      iex> update_user_avatar(user, %{avatar_url: "https://example.com/avatar.png"})
      {:ok, %User{}}

      iex> update_user_avatar(user, %{avatar_url: ""})
      {:error, %Ecto.Changeset{}}
  """
  def update_user_avatar(%User{} = user, attrs) do
    user
    |> User.avatar_changeset(attrs)
    |> Repo.update()
  end

  # Trả về một changeset để kiểm tra hoặc hiển thị form mà không thay đổi dữ liệu trong database.
  # Kiểm tra xem dữ liệu có hợp lệ không trước khi lưu vào database
  def change_user_display_name(%User{} = user, attrs \\ %{}) do
    User.display_name_changeset(user, attrs)
  end

  #  Cập nhật vào database
  def update_user_display_name(%User{} = user, attrs) do
    user
    |> User.display_name_changeset(attrs)
    |> Repo.update()
  end

  # Tìm dựa trên email
  def search_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  # Gửi yêu cầu kết bạn
  def send_friend_request(user_id, friend_id) do
    case Repo.get_by(Friendship, user_id: user_id, friend_id: friend_id) do
      nil ->
        %Friendship{}
        |> Friendship.changeset(%{user_id: user_id, friend_id: friend_id, status: "pending"})
        |> Repo.insert()
    end
  end

  # Hủy yêu cầu kết bạn
  def cancel_friend_request(user_id, friend_id) do
    case Repo.get_by(Friendship, user_id: user_id, friend_id: friend_id, status: "pending") do
      nil -> {:error, "No pending request"}
      request -> Repo.delete(request)
    end
  end

  # Lấy trạng thái của mối quan hệ bạn bè
  def get_friendship_status(current_user, target_user) do
    query =
      from f in Friendship,
        where:
          (f.user_id == ^current_user.id and f.friend_id == ^target_user.id) or
            (f.user_id == ^target_user.id and f.friend_id == ^current_user.id)

    case Repo.one(query) do
      nil -> nil
      friendship -> friendship.status
    end
  end

  # Lấy danh sách lời mời kết bạn đang chờ xử lý
  def list_pending_friend_requests(user_id) do
    Repo.all(
      from f in Friendship,
        where: f.friend_id == ^user_id and f.status == "pending",
        join: u in User,
        on: u.id == f.user_id,
        select: %{id: f.id, user_id: f.user_id, email: u.email}
    )
  end

  # Chấp nhận lời mời kết bạn
  def accept_friend_request(request_id) do
    Repo.transaction(fn ->
      case Repo.get(Friendship, request_id) do
        nil ->
          Repo.rollback({:error, "Request not found"})

        request ->
          # Cập nhật trạng thái lời mời thành "accepted"
          request
          |> Friendship.changeset(%{status: "accepted"})
          |> Repo.update!()

          # Lấy thông tin của người gửi và người nhận lời mời
          friend = Repo.get!(User, request.user_id)

          # Kiểm tra xem đã có cuộc trò chuyện riêng tư giữa 2 người hay chưa
          query =
            from(c in Conversation,
              where: c.is_group == false,
              join: m1 in GroupMember,
              on: m1.conversation_id == c.id,
              join: m2 in GroupMember,
              on: m2.conversation_id == c.id,
              where: m1.user_id == ^request.user_id and m2.user_id == ^request.friend_id,
              select: c
            )

          conversation = Repo.one(query)

          conversation =
            if conversation do
              # Nếu cuộc trò chuyện đã tồn tại, sử dụng luôn conversation đó
              conversation
            else
              # Nếu chưa có, tạo cuộc trò chuyện mới
              conversation_changeset =
                Conversation.changeset(%Conversation{}, %{
                  name: friend.email,
                  is_group: false,
                  creator_id: request.user_id
                })

              conversation = Repo.insert!(conversation_changeset)

              # Thêm cả 2 người vào bảng group_members
              members = [
                %GroupMember{conversation_id: conversation.id, user_id: request.user_id},
                %GroupMember{conversation_id: conversation.id, user_id: request.friend_id}
              ]

              Enum.each(members, &Repo.insert!/1)

              conversation
            end

          {:ok, conversation}
      end
    end)
  end

  # Từ chối lời mời kết bạn
  def decline_friend_request(request_id) do
    case Repo.get(Friendship, request_id) do
      nil -> {:error, "Request not found"}
      request -> Repo.delete(request)
    end
  end

  # Lấy danh sách bạn bè đã kết bạn
  def list_friends(user_id) do
    Repo.all(
      from f in Friendship,
        where: (f.user_id == ^user_id or f.friend_id == ^user_id) and f.status == "accepted",
        join: u in User,
        on:
          (u.id == f.friend_id and f.user_id == ^user_id) or
            (u.id == f.user_id and f.friend_id == ^user_id),
        select: %{id: f.id, friend_id: u.id, email: u.email}
    )
  end

  # <---- THÊM HÀM GET_USER ---->
  @doc """
  Gets a user by ID.
  Returns nil if not found.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  # lấy trạng thái hoạt động
  def get_user_status(user_id) do
    user = Repo.get(User, user_id)

    if user do
      now = DateTime.utc_now()
      last_seen = user.last_active_at || DateTime.from_unix!(0)
      diff = DateTime.diff(now, last_seen, :minute)

      cond do
        diff < 5 -> "Đang hoạt động"
        diff < 60 -> "Hoạt động #{diff} phút trước"
        diff < 1440 -> "Hoạt động #{div(diff, 60)} giờ trước"
        true -> "Hoạt động #{div(diff, 1440)} ngày trước"
      end
    else
      "Không rõ"
    end
  end

  # Hàm hủy kết bạn
  def unfriend(user_id, friend_id) do
    query =
      from f in Friendship,
        where:
          (f.user_id == ^user_id and f.friend_id == ^friend_id) or
            (f.user_id == ^friend_id and f.friend_id == ^user_id),
        where: f.status == "accepted"

    case Repo.one(query) do
      nil ->
        {:error, "Không tìm thấy kết bạn"}

      friendship ->
        Repo.delete(friendship)
    end
  end
end
