defmodule Gchatdemo1Web.UserSettingsLive do
  use Gchatdemo1Web, :live_view

  alias Gchatdemo1.Accounts

  defp cloud_name(), do: Application.get_env(:cloudex, :cloud_name)
  defp api_key(), do: Application.get_env(:cloudex, :api_key)
  defp api_secret(), do: Application.get_env(:cloudex, :secret)

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Cài đặt tài khoản
      <:subtitle>Quản lý địa chỉ email và cài đặt mật khẩu tài khoản của bạn</:subtitle>
    </.header>

    <img
      src={
        @current_user.avatar_url ||
          "https://res.cloudinary.com/djyr2tc78/image/upload/v1739503287/default_avatar.png"
      }
      alt="Avatar"
      width="150"
      class="rounded-full"
    />
    <h1>Cập nhật ảnh đại diện</h1>

    <form phx-change="validate_images" phx-submit="upload_images">
      <.live_file_input upload={@uploads.images} /> <button type="submit">Tải ảnh đại diện</button>
      <article :for={entry <- @uploads.images.entries} class="upload-entry">
        <figure>
          <.live_img_preview :if={entry.client_type in ["image/png", "image/jpeg"]} entry={entry} />
          <figcaption>{entry.client_name}</figcaption>
        </figure>

        <button type="button" phx-click="cancel-upload" phx-value-ref={entry.ref} aria-label="cancel">&times;</button>

        <progress value={entry.progress} max="100"><%= entry.progress %>%</progress>

        <div :for={err <- upload_errors(@uploads.images, entry)} class="alert alert-danger">
          {upload_error_to_string(err)}
        </div>
      </article>
    </form>

    <%!--
    <div :if={@uploaded_images}>
      <h2>Avatar của bạn</h2>
      <img src={@uploaded_images} width="150" />
    </div> --%>
    <div class="space-y-12 divide-y">
    <div>
<.simple_form
  for={@display_name_form}
  id="display_name_form"
  phx-submit="update_display_name"
  phx-change="validate_display_name"
>
  <.input field={@display_name_form[:display_name]} type="text" label="Display Name" required />

  <:actions>
    <.button phx-disable-with="Saving...">Save</.button>
  </:actions>
</.simple_form>

    </div>
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Mật khẩu hiện tại"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Thay đổi Email</.button>
          </:actions>
        </.simple_form>
      </div>

      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label="Mật khẩu mới"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Xác nhận mật khẩu mới"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Mật khẩu hiện tại"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Thay đổi mật khẩu</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <a
          href={"/stream/#{@current_user.display_name}/custom_stream"}
          class="px-4 py-2 bg-blue-500 text-white font-semibold rounded-lg shadow-md hover:bg-blue-600 transition"
          target="_blank"
        >
          Cài đặt Stream
        </a>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    socket =
      socket
      # Gán avatar hiện tại vào assigns
      |> assign(:uploaded_images, user.avatar_url)
      |> allow_upload(:images,
        accept: ~w(image/png image/jpeg),
        max_entries: 1,
        auto_upload: false,
        external: &presign_upload/2,
        progress: &handle_progress/3
      )

    if Map.has_key?(params, "token") do
      socket =
        case Accounts.update_user_email(socket.assigns.current_user, params["token"]) do
          :ok ->
            put_flash(socket, :info, "Email changed successfully.")

          :error ->
            put_flash(socket, :error, "Email change link is invalid or it has expired.")
        end

      {:ok, push_navigate(socket, to: ~p"/users/settings")}
    else
      user = socket.assigns.current_user
      email_changeset = Accounts.change_user_email(user)
      password_changeset = Accounts.change_user_password(user)
      display_name_changeset = Accounts.change_user_display_name(user)

      socket =
        socket
        |> assign(:display_name_form, to_form(display_name_changeset))
        |> assign(:current_password, nil)
        |> assign(:email_form_current_password, nil)
        |> assign(:current_email, user.email)
        |> assign(:email_form, to_form(email_changeset))
        |> assign(:password_form, to_form(password_changeset))
        |> assign(:trigger_submit, false)

      {:ok, socket}
    end
  end

  defp presign_upload(_entry, socket) do
    user = socket.assigns.current_user
    # Lấy timestamp hiện tại
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    # Giữ nguyên ID user
    public_id = "avatars/#{user.id}"

    params = %{
      timestamp: timestamp,
      public_id: public_id,
      overwrite: true,
      eager: "w_400,h_300,c_pad|w_260,h_200,c_crop"
    }

    query_string_with_secret =
      params
      |> Enum.sort_by(fn {k, _v} -> k end)
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
      |> Enum.join("&")
      |> Kernel.<>(api_secret())

    signature =
      :crypto.hash(:sha256, query_string_with_secret)
      |> Base.encode16(case: :lower)

    fields =
      params
      |> Map.put(:signature, signature)
      |> Map.put(:api_key, api_key())

    meta = %{
      uploader: "Cloudinary",
      url: "https://api.cloudinary.com/v1_1/#{cloud_name()}/image/upload",
      fields: fields
    }

    {:ok, meta, socket}
  end

  defp handle_progress(:images, entry, socket) do
    if entry.done? do
      consume_uploaded_entry(socket, entry, fn %{fields: fields} ->
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        update_avatar_url(socket, cloudinary_image_url(fields.public_id, timestamp))
      end)
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_display_name", %{"user" => user_params}, socket) do
    display_name_form =
      socket.assigns.current_user
      |> Accounts.change_user_display_name(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, display_name_form: display_name_form)}
  end

  def handle_event("update_display_name", %{"user" => user_params}, socket) do
    user = socket.assigns.current_user

    case Accounts.update_user_display_name(user, user_params) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Display Name updated successfully!")
         |> assign(
           display_name_form: to_form(Accounts.change_user_display_name(updated_user)),
           current_user: updated_user
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, display_name_form: to_form(changeset))}
    end
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def handle_event("validate_images", _params, socket) do
    {:noreply, socket}
  end

  # 🟢 Cập nhật handle_event để xử lý danh sách ảnh tải lên
  def handle_event("upload_images", _params, socket) do
    uploaded_images =
      consume_uploaded_entries(socket, :images, fn %{fields: fields}, _entry ->
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        {:ok, cloudinary_image_url(fields.public_id, timestamp)}
      end)

    case uploaded_images do
      [images_url] -> update_avatar_url(socket, images_url)
      _ -> {:noreply, socket}
    end
  end

  defp update_avatar_url(socket, images_url) do
    case Accounts.update_user_avatar(socket.assigns.current_user, %{avatar_url: images_url}) do
      {:ok, updated_user} ->
        {:noreply, assign(socket, uploaded_images: images_url, current_user: updated_user)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Không thể cập nhật avatar!")}
    end
  end

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :images, ref)}
  end

  defp cloudinary_image_url(public_id, timestamp) do
    "https://res.cloudinary.com/#{cloud_name()}/image/upload/v#{timestamp}/#{public_id}.png"
  end

  defp upload_error_to_string(:too_large), do: "The file is too large"
  defp upload_error_to_string(:too_many_files), do: "You have selected too many files"
  defp upload_error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  defp upload_error_to_string(:external_client_failure), do: "Something went terribly wrong"
end
