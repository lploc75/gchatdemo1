import { html, css, LitElement } from "lit";

class UserConfirmation extends LitElement {
  static properties = {
    token: { type: String },
    message: { type: String },
  };

  constructor() {
    super();
    this.token = window.location.pathname.split("/").pop();
    this.message = "";
  }

  static styles = css`
    .container {
      max-width: 400px;
      margin: auto;
      text-align: center;
    }
    button {
      width: 100%;
      padding: 10px;
      background: #007bff;
      color: white;
      border: none;
      cursor: pointer;
    }
    .message {
      margin-top: 10px;
    }
  `;

  async confirmAccount() {
    if (!this.token) {
      this.message = "Token không hợp lệ.";
      return;
    }

    const response = await fetch("/api/users/confirm", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ token: this.token }),
    });

    const data = await response.json();
    this.message = data.message;
  }

  render() {
    return html`
      <div class="container">
        <h2>Xác nhận tài khoản</h2>
        <button @click=${this.confirmAccount} ?disabled=${!this.token}>
          Xác nhận tài khoản của tôi
        </button>
        ${this.message ? html`<p class="message">${this.message}</p>` : ""}
        ${this.token }
      </div>
    `;
  }
}

customElements.define("user-confirmation", UserConfirmation);
