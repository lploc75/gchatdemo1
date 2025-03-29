defmodule Gchatdemo1Web.UserSettingController do
  use Gchatdemo1Web, :controller  # Sử dụng controller của Phoenix
  alias Gchatdemo1.Accounts       # Alias module Accounts để xử lý logic liên quan đến người dùng

  # API để tạo URL tải lên cho avatar
  def presign_avatar_upload(conn, _params) do
    user_id = conn.assigns.current_user.id  # Lấy ID người dùng hiện tại từ kết nối

    case generate_presigned_url(user_id) do
      {:ok, meta} ->
        IO.inspect(meta, label: "✅ Presigned URL Response") # Log dữ liệu phản hồi từ Cloudinary
        json(conn, meta)  # Trả về JSON chứa URL tải lên

      {:error, reason} ->
        IO.puts("❌ Lỗi khi tạo presigned URL: #{reason}")
        conn
        |> put_status(:unprocessable_entity)  # Trả về lỗi HTTP 422 nếu có lỗi
        |> json(%{error: reason})
    end
  end

  # Hàm tạo URL tải lên cho Cloudinary
  defp generate_presigned_url(user_id) do
    cloud_name = Application.get_env(:cloudex, :cloud_name)  # Lấy cloud_name từ config
    api_key = Application.get_env(:cloudex, :api_key)        # Lấy api_key từ config
    api_secret = Application.get_env(:cloudex, :secret)      # Lấy api_secret từ config

    if cloud_name && api_key && api_secret do  # Kiểm tra xem có đủ cấu hình không
      timestamp = DateTime.utc_now() |> DateTime.to_unix()  # Lấy timestamp hiện tại
      public_id = "avatars/#{user_id}"  # Định danh ảnh avatar theo user_id

      # Các tham số cần thiết cho yêu cầu tải lên Cloudinary
      params = %{
        timestamp: timestamp,
        public_id: public_id,
        overwrite: true
      }

      # Tạo chuỗi query để ký (theo yêu cầu của Cloudinary)
      query_string_with_secret =
        params
        |> Enum.sort_by(fn {k, _v} -> k end)  # Sắp xếp theo key (Cloudinary yêu cầu)
        |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)  # Ghép key-value thành chuỗi
        |> Enum.join("&")  # Nối thành query string
        |> Kernel.<>(api_secret)  # Thêm API secret vào cuối để ký

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

      {:ok, meta}  # Trả về thành công
    else
      {:error, "Missing Cloudinary configuration"}  # Báo lỗi nếu thiếu config
    end
  end

  # API để cập nhật avatar của người dùng trong cơ sở dữ liệu
  def update_avatar(conn, %{"avatar_url" => avatar_url}) do
    user = conn.assigns.current_user  # Lấy người dùng hiện tại

    case Accounts.update_user_avatar(user, %{avatar_url: avatar_url}) do
      {:ok, _user} -> json(conn, %{avatar_url: avatar_url})  # Trả về avatar mới nếu cập nhật thành công
      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)  # Trả về lỗi HTTP 422 nếu cập nhật thất bại
        |> json(%{error: "Không thể cập nhật avatar!"})
    end
  end

  def update_display_name(conn, %{"display_name" => new_display_name}) do
    user = conn.assigns.current_user

    case Accounts.update_user_display_name(user, %{"display_name" => new_display_name}) do
      {:ok, updated_user} ->
        json(conn, %{success: true, message: "Updated successfully!", display_name: updated_user.display_name})

      {:error, changeset} ->
        json(conn, %{success: false, errors: changeset.errors})
    end
  end

  def update_email(conn, %{"current_password" => password, "user" => %{"email" => email} = user_params}) do
    user = conn.assigns.current_user

    if Accounts.email_exists?(email) do
      conn
      |> json(%{errors: %{email: "Email đã được sử dụng"}})
    else
      case Accounts.apply_user_email(user, password, user_params) do
        {:ok, applied_user} ->
          Accounts.deliver_user_update_email_instructions(
            applied_user,
            user.email,
            &url(~p"/users/settings/confirm_email/#{&1}")
          )

          json(conn, %{message: "Một liên kết xác nhận thay đổi email của bạn đã được gửi."})

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.map(fn {field, {message, _opts}} -> {field, message} end)
            |> Enum.into(%{})  # Chuyển về dạng Map

          conn
          |> json(%{errors: errors})
      end
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    user = conn.assigns.current_user

    case Accounts.update_user_email(user, token) do
      :ok ->
        json(conn, %{message: "Email thay đổi thành công."})
      :error ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Liên kết thay đổi email đã hết hạn hoặc không hợp lệ."})
    end
  end

  def update_password(conn, %{"current_password" => password, "user" => user_params}) do
    user = conn.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, _user} ->
        json(conn, %{message: "Thay đổi mật khẩu thành công!"})

      {:error, changeset} ->
        # Chuyển đổi lỗi từ tuple thành map để Jason có thể mã hóa
        errors =
          changeset.errors
          |> Enum.map(fn {field, {message, _opts}} -> {Atom.to_string(field), message} end)
          |> Enum.into(%{})

        conn
        |> json(%{errors: errors})
    end
  end

end
