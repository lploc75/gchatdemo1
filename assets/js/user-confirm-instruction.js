import { html, css, LitElement } from "lit";

class UserConfirmInstruction extends LitElement {
  static properties = {
    email: { type: String },
    message: { type: String },
  };

  constructor() {
    super();
    this.email = "";
    this.message = "";
  }

  static styles = css`
    .container {
      max-width: 400px;
      margin: auto;
      text-align: center;
    }
    input {
      width: 100%;
      padding: 8px;
      margin-bottom: 10px;
    }
    button {
      width: 100%;
      padding: 10px;
      background: #007bff;
      color: white;
      border: none;
      cursor: pointer;
    }
    button:disabled {
      background: gray;
    }
    .message {
      margin-top: 10px;
      color: green;
    }
  `;

  handleInput(event) {
    this.email = event.target.value;
  }

  async sendInstructions() {
    const response = await fetch("/api/users/send_confirmation", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: this.email }),
    });

    const data = await response.json();
    console.log(data);
    this.message = data.message;
  }

  render() {
    return html`
      <div class="container">
        <h2>Không nhận được hướng dẫn xác nhận?</h2>
        <p>Chúng tôi sẽ gửi liên kết xác nhận mới đến hộp thư đến của bạn</p>
        
        <input type="email" placeholder="Email" @input=${this.handleInput} />
        <button @click=${this.sendInstructions} ?disabled=${!this.email}>
          Gửi lại hướng dẫn xác nhận
        </button>
        
        ${this.message ? html`<p class="message">${this.message}</p>` : ""}
      </div>
    `;
  }
}

customElements.define("user-confirm-instruction", UserConfirmInstruction);
