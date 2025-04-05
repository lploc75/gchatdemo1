defmodule Gchatdemo1Web.UserSettingController do
  # Sử dụng controller của Phoenix
  use Gchatdemo1Web, :controller
  # Alias module Accounts để xử lý logic liên quan đến người dùng
  alias Gchatdemo1.Accounts

  # API để tạo URL tải lên cho avatar
  def presign_avatar_upload(conn, _params) do
    # Lấy ID người dùng hiện tại từ kết nối
    user_id = conn.assigns.current_user.id

    case generate_presigned_url(user_id) do
      {:ok, meta} ->
        # Log dữ liệu phản hồi từ Cloudinary
        IO.inspect(meta, label: "✅ Presigned URL Response")
        # Trả về JSON chứa URL tải lên
        json(conn, meta)

      {:error, reason} ->
        IO.puts("❌ Lỗi khi tạo presigned URL: #{reason}")

        conn
        # Trả về lỗi HTTP 422 nếu có lỗi
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  # Hàm tạo URL tải lên cho Cloudinary
  defp generate_presigned_url(user_id) do
    # Lấy cloud_name từ config
    cloud_name = Application.get_env(:cloudex, :cloud_name)
    # Lấy api_key từ config
    api_key = Application.get_env(:cloudex, :api_key)
    # Lấy api_secret từ config
    api_secret = Application.get_env(:cloudex, :secret)

    # Kiểm tra xem có đủ cấu hình không
    if cloud_name && api_key && api_secret do
      # Lấy timestamp hiện tại
      timestamp = DateTime.utc_now() |> DateTime.to_unix()
      # Định danh ảnh avatar theo user_id
      public_id = "avatars/#{user_id}"

      # Các tham số cần thiết cho yêu cầu tải lên Cloudinary
      params = %{
        timestamp: timestamp,
        public_id: public_id,
        overwrite: true
      }

      # Tạo chuỗi query để ký (theo yêu cầu của Cloudinary)
      query_string_with_secret =
        params
        # Sắp xếp theo key (Cloudinary yêu cầu)
        |> Enum.sort_by(fn {k, _v} -> k end)
        # Ghép key-value thành chuỗi
        |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)
        # Nối thành query string
        |> Enum.join("&")
        # Thêm API secret vào cuối để ký
        |> Kernel.<>(api_secret)

      # Tạo chữ ký SHA256
      signature =
        :crypto.hash(:sha256, query_string_with_secret)
        |> Base.encode16(case: :lower)

      # Thêm API key và chữ ký vào trường cần thiết
      fields =
        params
        |> Map.put(:signature, signature)
        |> Map.put(:api_key, api_key)

      # Trả về thông tin cần thiết để tải lên Cloudinary
      meta = %{
        uploader: "Cloudinary",
        url: "https://api.cloudinary.com/v1_1/#{cloud_name}/image/upload",
        fields: fields
      }

      # Trả về thành công
      {:ok, meta}
    else
      # Báo lỗi nếu thiếu config
      {:error, "Missing Cloudinary configuration"}
    end
  end

  # API để cập nhật avatar của người dùng trong cơ sở dữ liệu
  def update_avatar(conn, %{"avatar_url" => avatar_url}) do
    # Lấy người dùng hiện tại
    user = conn.assigns.current_user

    case Accounts.update_user_avatar(user, %{avatar_url: avatar_url}) do
      # Trả về avatar mới nếu cập nhật thành công
      {:ok, _user} ->
        json(conn, %{avatar_url: avatar_url})

      {:error, _reason} ->
        conn
        # Trả về lỗi HTTP 422 nếu cập nhật thất bại
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Không thể cập nhật avatar!"})
    end
  end

  # API: Cập nhật tên hiển thị
  def update_display_name(conn, %{"display_name" => new_display_name}) do
    user = conn.assigns.current_user

    case Accounts.update_user_display_name(user, %{"display_name" => new_display_name}) do
      {:ok, updated_user} ->
        json(conn, %{
          success: true,
          message: "Updated successfully!",
          display_name: updated_user.display_name
        })

      {:error, changeset} ->
        json(conn, %{success: false, errors: changeset.errors})
    end
  end

  # API: Đổi email (yêu cầu nhập mật khẩu và gửi email xác nhận)
  def update_email(conn, %{
        "current_password" => password,
        "user" => %{"email" => email} = user_params
      }) do
    user = conn.assigns.current_user

    if Accounts.email_exists?(email) do
      conn
      # Nếu email đã tồn tại => báo lỗi
      |> json(%{errors: %{email: "Email đã được sử dụng"}})
    else
      case Accounts.apply_user_email(user, password, user_params) do
        {:ok, applied_user} ->
          # Gửi email xác nhận đổi email (chứa token)
          Accounts.deliver_user_update_email_instructions(
            applied_user,
            user.email,
            &url(~p"/users/settings/confirm_email/#{&1}")
          )

          json(conn, %{message: "Một liên kết xác nhận thay đổi email của bạn đã được gửi."})

        {:error, changeset} ->
          # Trả về lỗi validate
          errors =
            changeset.errors
            |> Enum.map(fn {field, {message, _opts}} -> {field, message} end)
            # Chuyển về dạng Map
            |> Enum.into(%{})

          conn
          |> json(%{errors: errors})
      end
    end
  end

  # API: Xác nhận đổi email từ token
  def confirm_email(conn, %{"token" => token}) do
    user = conn.assigns.current_user

    case Accounts.update_user_email(user, token) do
      :ok ->
        # Thành công
        json(conn, %{message: "Email thay đổi thành công."})

      :error ->
        conn
        |> put_status(:unprocessable_entity)
        # Lỗi token
        |> json(%{error: "Liên kết thay đổi email đã hết hạn hoặc không hợp lệ."})
    end
  end

  # API: Đổi mật khẩu
  def update_password(conn, %{"current_password" => password, "user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, _user} ->
        # Đổi thành công
        json(conn, %{message: "Thay đổi mật khẩu thành công!"})

      {:error, changeset} ->
        # Trả về lỗi theo dạng Map
        errors =
          changeset.errors
          |> Enum.map(fn {field, {message, _opts}} -> {Atom.to_string(field), message} end)
          |> Enum.into(%{})

        conn
        |> json(%{errors: errors})
    end
  end
end
