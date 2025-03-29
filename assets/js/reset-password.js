import { html, LitElement } from "lit";

class ResetPassword extends LitElement {
  static properties = {
    token: { type: String },
    password: { type: String },
    passwordConfirmation: { type: String },
    message: { type: String },
    errorMessage: { type: String },
    passwordError: { type: String },
    tokenValid: { type: Boolean }
  };

  constructor() {
    super();
    this.token = window.location.pathname.split("/").pop();
    this.password = "";
    this.passwordConfirmation = "";
    this.message = "";
    this.errorMessage = "";
    this.passwordError = "";
    this.tokenValid = false; // Mặc định là false, sẽ cập nhật sau khi kiểm tra token

    this.checkToken();
  }

  async checkToken() {
    try {
      const response = await fetch(`/api/users/check_reset_token?token=${this.token}`);
      const data = await response.json();

      if (data.success) {
        this.tokenValid = true;
      } else {
        this.errorMessage = data.error;
        this.tokenValid = false;
      }
    } catch (error) {
      this.errorMessage = "Lỗi kết nối đến server.";
      this.tokenValid = false;
    }
  }

  validatePassword() {
    if (this.password.length < 6) {
      this.passwordError = "Mật khẩu phải có ít nhất 6 ký tự.";
      return false;
    }
    if (this.password !== this.passwordConfirmation) {
      this.passwordError = "Mật khẩu xác nhận không khớp.";
      return false;
    }
    this.passwordError = "";
    return true;
  }

  async resetPassword() {
    if (!this.validatePassword()) return;

    this.message = "";
    this.errorMessage = "Đang xử lý...";

    try {
      const response = await fetch("/api/users/reset_password/confirm", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token: this.token,
          password: this.password,
          password_confirmation: this.passwordConfirmation,
        }),
      });

      const data = await response.json();

      if (data.success) {
        this.message = data.message;
        this.errorMessage = "";
        setTimeout(() => (window.location.href = "/users/log_in"), 2000);
      } else {
        this.errorMessage = data.error;
      }
    } catch (error) {
      this.errorMessage = "Lỗi kết nối đến server.";
    }
  }

  render() {
    return html`
      <div class="container">
        <h2>Đặt lại mật khẩu</h2>
        
        ${this.errorMessage 
          ? html`<p class="error">${this.errorMessage}</p>` 
          : ""}
        
        ${this.tokenValid
          ? html`
            <input 
              type="password" 
              placeholder="Mật khẩu mới" 
              @input="${e => { this.password = e.target.value; this.validatePassword(); }}"
            />
            <input 
              type="password" 
              placeholder="Xác nhận mật khẩu" 
              @input="${e => { this.passwordConfirmation = e.target.value; this.validatePassword(); }}"
            />
            
            ${this.passwordError ? html`<p class="error">${this.passwordError}</p>` : ""}
            
            <button 
              @click="${this.resetPassword}" 
              ?disabled="${!this.password || !this.passwordConfirmation}"
            >
              Đặt lại mật khẩu
            </button>
          `
          : ""}
        
        ${this.message ? html`<p class="message">${this.message}</p>` : ""}
      </div>
    `;
  }
}

customElements.define("reset-password", ResetPassword);
