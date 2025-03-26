import { html, css, LitElement } from "lit";

export class LoginForm extends LitElement {
  static properties = { status: { type: String } };

  constructor() {
    super();
    this.status = "Chưa đăng nhập";
  }

  render() {
    return html`
      <div class="login-status">${this.status}</div>
    `;
  }
}

customElements.define("login-form", LoginForm);
