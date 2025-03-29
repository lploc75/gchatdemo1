import { html, css, LitElement } from "lit";

class UserSetting extends LitElement {
  static properties = {
    avatarUrl: { type: String },
    uploading: { type: Boolean },
  };

  static styles = css`
    .container {
      text-align: center;
    }
    img {
      width: 150px;
      height: 150px;
      border-radius: 50%;
      object-fit: cover;
    }
    input {
      display: block;
      margin: 10px auto;
    }
    .spinner {
      display: inline-block;
      width: 20px;
      height: 20px;
      border: 2px solid transparent;
      border-top-color: #000;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }
    @keyframes spin {
      from {
        transform: rotate(0deg);
      }
      to {
        transform: rotate(360deg);
      }
    }
  `;

  constructor() {
    super();
    this.avatarUrl =
      "https://res.cloudinary.com/djyr2tc78/image/upload/v1739503287/default_avatar.png";
    this.uploading = false;
    this.emailErrors = {};
    this.passwordErrors = {};
    this.successMessage = "";
    // this.token = window.location.pathname.split("/").pop();
  }
  connectedCallback() {
    super.connectedCallback();
    this.fetchUserInfo(); // Gọi API khi component được load
    // Lấy pathname từ URL hiện tại
    const pathname = window.location.pathname; // Thêm dòng này để tránh lỗi

    // Kiểm tra định dạng đúng "/users/settings/confirm_email/:token"
    const tokenMatch = pathname.match(
      /^\/users\/settings\/confirm_email\/([A-Za-z0-9_-]+)$/
    );

    if (tokenMatch) {
      this.token = tokenMatch[1]; // Lấy token từ regex match
      this.confirmEmail(this.token); // Nếu đúng format, xác nhận email
    } else {
      // Đây không phải lỗi, chỉ để debug
      console.log(
        "Đây không phải lỗi \n url format không hợp lệ! -> không phải yêu cầu thay đổi email"
      );
    }

    console.log("Token:", this.token);
  }

  async confirmEmail(token) {
    try {
      const res = await fetch(`/api/users/settings/confirm_email/${token}`, {
        method: "GET",
      });
      const result = await res.json();

      if (res.ok) {
        this.successMessage = "Email confirmed successfully!";
      } else {
        this.successMessage = "Email confirmation link is invalid or expired.";
      }
    } catch (error) {
      this.successMessage = "An error occurred while confirming your email.";
    }
    console.log("Confirm email result:", this.successMessage);
  }

  async fetchUserInfo() {
    try {
      const res = await fetch("/api/users/me"); // API lấy thông tin user
      if (!res.ok) throw new Error("Không thể lấy thông tin user");
      const user = await res.json();
      console.log("Thông tin user:", user);
      this.avatarUrl = user.avatar_url || this.avatarUrl; // Cập nhật avatar nếu có
    } catch (error) {
      console.error("Lỗi khi lấy thông tin user:", error);
    }
  }

  async handleUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    this.uploading = true;
    try {
      const newAvatarUrl = await this.uploadAvatar(file);
      this.avatarUrl = newAvatarUrl;
    } catch (error) {
      alert("Upload thất bại: " + error.message);
    } finally {
      this.uploading = false;
    }
  }

  async uploadAvatar(file) {
    const res = await fetch("/api/users/avatar/presign");
    if (!res.ok) throw new Error("Lỗi khi lấy URL tải lên");
    const { url, fields } = await res.json();

    const formData = new FormData();
    Object.entries(fields).forEach(([key, value]) =>
      formData.append(key, value)
    );
    formData.append("file", file);

    const uploadRes = await fetch(url, {
      method: "POST",
      body: formData,
    });

    if (!uploadRes.ok) throw new Error("Upload thất bại");
    const { secure_url } = await uploadRes.json();

    await fetch("/api/users/avatar/update", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ avatar_url: secure_url }),
    });

    return secure_url;
  }
  
  async updateDisplayName(event) {
    event.preventDefault();
    this.successMessage = "";
    this.displayNameErrors = {};
  
    const formData = new FormData(event.target);
    const displayName = formData.get("display_name");
  
    try {
      const response = await fetch("/api/users/settings/update_display_name", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ display_name: displayName }),
      });
  
      const result = await response.json();
      console.log(result);
      if (response.ok) {
        this.successMessage = result.message;
      } else {
        this.displayNameErrors = result.errors || {};
      }
    } catch (error) {
      console.error("Error updating display name:", error);
    }
  }
  
  async updateEmail(event) {
    event.preventDefault();
    this.successMessage = "";
    this.emailErrors = {};

    const formData = new FormData(event.target);

    const response = await fetch("/api/users/settings/update_email", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${localStorage.getItem("auth_token")}`,
      },
      body: JSON.stringify({
        user: { email: formData.get("email") },
        current_password: formData.get("current_password"),
      }),
    });

    const result = await response.json();
    console.log(result);
    if (response.ok) {
      this.successMessage = result.message;
    } else {
      this.emailErrors = result.errors || {};
    }
  }

  async updatePassword(event) {
    event.preventDefault();
    this.passwordErrors = {};
    this.successMessage = "";
  
    const form = event.target; // Lấy form từ sự kiện
    const formData = new FormData(form);
  
    const response = await fetch("/api/users/settings/update_password", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${localStorage.getItem("auth_token")}`,
      },
      body: JSON.stringify({
        user: {
          password: formData.get("password"),
          password_confirmation: formData.get("password_confirmation"),
        },
        current_password: formData.get("current_password"),
      }),
    });
  
    const result = await response.json();
    console.log("Kết quả từ API", result);
    if (response.ok) {
      this.successMessage = result.message;
      if (form) { // Kiểm tra form có tồn tại không
        form.reset(); // Reset form
      }
    } else {
      this.passwordErrors = result.errors || {};
    }
  }
  
  render() {
    return html`
      <div class="container">
        <h2>Cập nhật ảnh đại diện</h2>
        <img src="${this.avatarUrl}" alt="Avatar" />
        <input
          type="file"
          @change="${this.handleUpload}"
          accept="image/png, image/jpeg"
        />
        ${this.uploading ? html`<div class="spinner"></div>` : ""}
      </div>

      <h2>Update Display Name</h2>
      <form @submit="${this.updateDisplayName}">
        <input type="text" name="display_name" placeholder="New display name" required />
        <button type="submit">Update Display Name</button>
      </form>

      <h2>Update Email</h2>
      <form @submit="${this.updateEmail}">
        <input type="email" name="email" placeholder="New email" required />
        <input
          type="password"
          name="current_password"
          placeholder="Current password"
          required
        />
        <button type="submit">Update Email</button>
        ${Object.values(this.emailErrors).map(
          (error) => html`<div class="error">${error}</div>`
        )}
      </form>

      <h2>Update Password</h2>
      <form @submit="${this.updatePassword}">
        <input
          type="password"
          name="password"
          placeholder="New password"
          required
        />
        <input
          type="password"
          name="password_confirmation"
          placeholder="Confirm new password"
          required
        />
        <input
          type="password"
          name="current_password"
          placeholder="Current password"
          required
        />
        <button type="submit">Update Password</button>
        ${Object.values(this.passwordErrors).map(
          (error) => html`<div class="error">${error}</div>`
        )}
      </form>

      ${this.successMessage
        ? html`<div class="success">${this.successMessage}</div>`
        : ""}
    `;
  }
}

customElements.define("user-setting", UserSetting);
