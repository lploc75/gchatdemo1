import { html, css, LitElement } from "lit";

class ForgotPassword extends LitElement {
  static styles = css`
    .container {
      max-width: 400px;
      margin: auto;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0px 0px 10px rgba(0, 0, 0, 0.1);
      text-align: center;
    }
    input, button {
      width: 100%;
      margin: 5px 0;
      padding: 10px;
      font-size: 16px;
    }
    a {
      color: blue;
      text-decoration: underline;
      cursor: pointer;
    }
    .message {
      color: green;
      font-size: 14px;
      margin-top: 10px;
    }
  `;

  static properties = {
    email: { type: String },
    message: { type: String }
  };

  constructor() {
    super();
    this.email = "";
    this.message = "";
  }

  async sendResetEmail() {
    this.message = "Đang gửi yêu cầu...";
    this.errorMessage="";
    const response = await fetch("/api/users/reset_password/request", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: this.email }),
    });
    const data = await response.json();
    console.log(data);
    if (data.success) {
      this.message = data.message;
    } else {
      this.errorMessage = data.error;
      this.message = "";
    }
    this.requestUpdate();
  }

  render() {
    return html`
      <div class="container">
        <h2>Quên mật khẩu?</h2>
        <p>Chúng tôi sẽ gửi liên kết đặt lại mật khẩu đến hộp thư đến của bạn.</p>
        <input type="email" placeholder="Email" @input="${(e) => this.email = e.target.value}" />
        <button @click="${this.sendResetEmail}">Gửi hướng dẫn</button>
        <p class="message">${this.message}</p>
        <p class="message">${this.errorMessage}</p>
        <p>
          <a href="/users/register">Đăng ký</a> | <a href="/users/log_in">Đăng nhập</a>
        </p>
      </div>
    `;
  }
}

customElements.define("forgot-password", ForgotPassword);
