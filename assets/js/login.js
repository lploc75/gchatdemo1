import { html, css, LitElement } from "lit";

class LoginPage extends LitElement {
  static styles = css`
    :host {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      font-family: Arial, sans-serif;
    }
    form {
      display: flex;
      flex-direction: column;
      gap: 10px;
      width: 300px;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
      background: white;
    }
    input {
      padding: 8px;
      font-size: 16px;
      border: 1px solid #ccc;
      border-radius: 4px;
    }
    button {
      padding: 10px;
      font-size: 16px;
      background: blue;
      color: white;
      border: none;
      border-radius: 4px;
      cursor: pointer;
    }
    .error {
      color: red;
      font-size: 14px;
    }
  `;

  static properties = {
    email: { type: String },
    password: { type: String },
    errorMessage: { type: String },
  };

  constructor() {
    super();
    this.email = "";
    this.password = "";
    this.errorMessage = "";
  }

  async login() {
    this.errorMessage = "";

    const response = await fetch("/api/users/log_in", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        user: { email: this.email, password: this.password },
      }),
    });

    const data = await response.json();
    console.log(data);
    if (data.success) {
      window.location.href = "/dashboard";
    } else {
      this.errorMessage = data.error;
    }
  }

  render() {
    return html`
      <form
        @submit=${(e) => {
          e.preventDefault();
          this.login();
        }}
      >
        <h2>Đăng nhập</h2>
        ${this.errorMessage
          ? html`<p class="error">${this.errorMessage}</p>`
          : ""}
        <input
          type="email"
          placeholder="Email"
          .value=${this.email}
          @input=${(e) => (this.email = e.target.value)}
          required
        />
        <input
          type="password"
          placeholder="Mật khẩu"
          .value=${this.password}
          @input=${(e) => (this.password = e.target.value)}
          required
        />
        <button type="submit">Đăng nhập</button>
        <p>
          Không có tài khoản?
          <a href="/users/register" class="link">Đăng ký</a>
        </p>
        <p>
          Quên mật khẩu?
          <a href="/users/forgot_password" class="link">Đặt lại mật khẩu</a>
        </p>
      </form>
    `;
  }
}

customElements.define("login-page", LoginPage);
