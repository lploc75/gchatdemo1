import { LitElement, html } from 'lit';

class FriendRequestsComponent extends LitElement {
  static properties = {
    requests: { type: Array },
    flashMessage: { type: Object } // Để hiển thị thông báo flash
  };

  constructor() {
    super();
    this.requests = [];
    this.flashMessage = { info: null, error: null };
  }

  connectedCallback() {
    super.connectedCallback();
    this.fetchFriendRequests();
  }

  async fetchFriendRequests() {
    try {
      console.log("🔍 Fetching friend requests...");
      const response = await fetch('/api/friend_requests', { credentials: 'include' });
      console.log("🟢 Response status:", response.status);

      if (!response.ok) {
        throw new Error(`Không thể tải danh sách lời mời kết bạn. HTTP ${response.status}`);
      }

      const data = await response.json();
      console.log("📥 Nhận dữ liệu từ API:", data);

      this.requests = data.requests || [];
      this.requestUpdate();
    } catch (error) {
      console.error("❌ Lỗi khi tải danh sách lời mời kết bạn:", error);
    }
  }

  async acceptFriendRequest(requestId) {
    try {
      const response = await fetch(`/api/friend_requests/${requestId}/accept`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include'
      });

      if (!response.ok) {
        throw new Error(`Không thể chấp nhận lời mời. HTTP ${response.status}`);
      }

      const data = await response.json();
      this.flashMessage = { info: data.message || "Đã chấp nhận lời mời kết bạn", error: null };
      this.requests = this.requests.filter(request => request.id !== requestId);
      this.requestUpdate();
    } catch (error) {
      console.error("❌ Lỗi khi chấp nhận lời mời:", error);
      this.flashMessage = { info: null, error: "Có lỗi xảy ra khi chấp nhận lời mời" };
      this.requestUpdate();
    }
  }

  async declineFriendRequest(requestId) {
    try {
      const response = await fetch(`/api/friend_requests/${requestId}/decline`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include'
      });

      if (!response.ok) {
        throw new Error(`Không thể từ chối lời mời. HTTP ${response.status}`);
      }

      const data = await response.json();
      this.flashMessage = { info: data.message || "Đã từ chối lời mời kết bạn", error: null };
      this.requests = this.requests.filter(request => request.id !== requestId);
      this.requestUpdate();
    } catch (error) {
      console.error("❌ Lỗi khi từ chối lời mời:", error);
      this.flashMessage = { info: null, error: "Có lỗi xảy ra khi từ chối lời mời" };
      this.requestUpdate();
    }
  }

  render() {
    return html`
      <h1>Lời mời kết bạn đang chờ:</h1>

      <!-- Hiển thị thông báo flash -->
${this.flashMessage.info ? html`
        <p style="color: green;">${this.flashMessage.info}</p>
      ` : ''}
      ${this.flashMessage.error ? html`
        <p style="color: red;">${this.flashMessage.error}</p>
      ` : ''}

      <!-- Danh sách lời mời kết bạn -->
      ${this.requests.length === 0 ? html`
        <p>Không có lời mời kết bạn nào.</p>
      ` : html`
        <ul>
          ${this.requests.map(request => html`
            <li>
              <img src="${request.
        sender_avatar
      }" alt="avatar" class="message-avatar" />
              <p>Email: ${request.sender_email
      }</p>
              <button @click="${() => this.acceptFriendRequest(request.id)}">Chấp nhận</button>
              <button @click="${() => this.declineFriendRequest(request.id)}">Từ chối</button>
            </li>
          `)}
        </ul>
      `}

      <!-- Nút quay lại Dashboard -->
      <a
  href="/dashboard"
  class="inline-block px-6 py-3 bg-blue-500 text-white font-bold rounded-lg shadow-md hover:bg-blue-700 transition duration-300"
>
  Quay lại Dashboard
</a>
    `;
  }
}

customElements.define('friend-requests-component', FriendRequestsComponent);