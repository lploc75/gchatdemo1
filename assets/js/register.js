import { html, css, LitElement } from 'lit';

class UserRegistration extends LitElement {
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
  `;

  static properties = {
    email: { type: String },
    password: { type: String },
    message: { type: String }
  };

  constructor() {
    super();
    this.email = '';
    this.password = '';
    this.message = '';
  }

  async registerUser() {
    const response = await fetch('/api/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ user: { email: this.email, password: this.password } })
    });
    const data = await response.json();
    console.log(data);
    this.message = data.success 
      ? 'Đăng ký thành công! Vui lòng kiểm tra email.' 
      : Object.values(data.errors).join(', ');
  }

  render() {
    return html`
      <div class="container">
        <h2>Đăng ký tài khoản</h2>
        <input type="email" placeholder="Email" @input="${(e) => this.email = e.target.value}" />
        <input type="password" placeholder="Mật khẩu" @input="${(e) => this.password = e.target.value}" />
        <button @click="${this.registerUser}">Đăng ký</button>
        <p>${this.message}</p>
        <p>
          Đã có tài khoản?
          <a href="/users/log_in">Đăng nhập</a>
          vào tài khoản của bạn.
        </p>
      </div>
    `;
  }
}

customElements.define('user-registration', UserRegistration);
