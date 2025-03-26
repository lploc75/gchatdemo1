import { LitElement, html, css } from 'lit';


class Dashboard extends LitElement {
  static styles = css`
      .message-avatar-container {
    align-self: flex-start;
    /* Giữ avatar luôn trên cùng */
    margin-top: 4px;
    /* Cân chỉnh vị trí avatar */
}

.message-avatar {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    object-fit: cover;
}
    `;
  // Định nghĩa các thuộc tính để lưu trữ dữ liệu
  static properties = {
    currentUser: { type: Object },
    friends: { type: Array }
  };

  constructor() {
    super();
    this.currentUser = null; // Khởi tạo người dùng hiện tại là null
    this.friends = [];       // Khởi tạo danh sách bạn bè là rỗng
  }

  // Gọi API khi thành phần được gắn vào DOM
  connectedCallback() {
    super.connectedCallback();
    this.fetchData();
  }

  // Hàm gọi API để lấy dữ liệu dashboard
  async fetchData() {
    try {
      console.log("🔍 Fetching dashboard data...");
      const response = await fetch('/api/dashboard', { credentials: 'include' });
      console.log("🟢 Response status:", response.status);

      if (!response.ok) {
        throw new Error(`Không thể tải dữ liệu dashboard. HTTP ${response.status}`);
      }

      const data = await response.json();
      console.log("📥 Nhận dữ liệu từ API:", data);

      this.currentUser = data.current_user;
      this.friends = data.friends;
    } catch (error) {
      console.error("❌ Lỗi khi tải dữ liệu dashboard:", error);
    }
  }


  // Render giao diện
  render() {
    // Hiển thị thông báo "Đang tải..." nếu chưa có dữ liệu
    if (!this.currentUser) {
      return html`<p>Đang tải...</p>`;
    }

    return html`
      <h1>Trang Dashboard</h1>
      <h2>Thông tin của bạn:</h2>
      <p>ID: ${this.currentUser.id}</p>
      <img src="${this.currentUser.avatar_url}" alt="avatar" class="message-avatar" />
      <p>Email: ${this.currentUser.email}</p>
      <a href="/list_friends" @click="${this.navigate}">Xem danh sách bạn bè</a><br>
      <a href="/friend_requests" @click="${this.navigate}">Yêu cầu kết bạn</a>

      <!-- Hiển thị danh sách bạn bè -->
      ${this.friends.length > 0 ? html`
        <h2>Danh sách bạn bè:</h2>
        <ul>
          ${this.friends.map(friend => html`
            <li style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.5em;">
              <div>
                <img src="${friend.avatar_url}" alt="avatar" class="message-avatar" />
                <strong>Email:</strong> ${friend.email} <br>
                <strong>ID:</strong> ${friend.id}
              </div>
              <div>
                <a href="/messages/${friend.conversation_id}" @click="${this.navigate}" style="padding: 0.3em 0.6em; background-color: #4CAF50; color: white; text-decoration: none; border-radius: 4px;">
Nhắn tin
                </a>
              </div>
            </li>
          `)}
        </ul>
      ` : html`<p>Bạn chưa có bạn bè nào.</p>`}
    `;
  }

  // Xử lý sự kiện điều hướng trong SPA
  navigate(event) {
    window.location.href = event.target.href; // Chuyển hướng hoàn toàn
    const path = event.target.getAttribute('href');
    history.pushState({}, '', path);
    this.dispatchEvent(new CustomEvent('navigate', { detail: { path } }));
  }
}

// Đăng ký thành phần với tên 'dashboard-component'
customElements.define('dashboard-component', Dashboard);