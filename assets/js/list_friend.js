import { LitElement, html, css } from 'lit';

class FriendsComponent extends LitElement {
    static properties = {
        currentUser: { type: Object },
        friends: { type: Array },
        searchedUser: { type: Object },
        status: { type: String },
        searchEmail: { type: String },
        searchMessage: { type: String }
    };

    constructor() {
        super();
        this.currentUser = null;
        this.friends = [];
        this.searchedUser = null;
        this.status = null;
        this.searchEmail = '';
        this.searchMessage = ''; // Thuộc tính thông báo
    }

    connectedCallback() {
        super.connectedCallback();
        this.fetchFriends();
    }

    async fetchFriends() {
        try {
            console.log("🔍 Fetching friends data...");
            const response = await fetch('/api/list_friends', { credentials: 'include' });
            console.log("🟢 Response status:", response.status);

            if (!response.ok) {
                throw new Error(`Không thể tải danh sách bạn bè. HTTP ${response.status}`);
            }

            const data = await response.json();
            console.log("📥 Nhận dữ liệu từ API:", data);

            this.currentUser = data.current_user;
            this.friends = data.friends;
            this.requestUpdate();
        } catch (error) {
            console.error("❌ Lỗi khi tải danh sách bạn bè:", error);
        }
    }

    async searchFriend(e) {
        e.preventDefault();
        try {
            console.log("🔍 Searching friend with email:", this.searchEmail);
            const response = await fetch('/api/friends', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({ email: this.searchEmail }),
                credentials: 'include'
            });

            if (!response.ok) {
                throw new Error(`Không thể tìm kiếm bạn bè. HTTP ${response.status}`);
            }

            const data = await response.json();
            console.log("📥 Kết quả tìm kiếm:", data);
            console.log("📥 friends trong dữ liệu:", data.friends);

            // Giả sử API trả về thuộc tính searched_user nếu tìm thấy, ngược lại trả về null hoặc không có key này
            if (data.searched_user) {
                this.searchedUser = data.searched_user;
                this.searchMessage = `Tìm thấy người dùng: ${this.searchedUser.email}`;
            } else {
                this.searchedUser = null;
                this.searchMessage = 'Không tìm thấy người dùng';
            }

            this.status = data.status;
            // Cập nhật danh sách bạn bè nếu cần
            this.friends = data.friends || [];
            this.requestUpdate();
        } catch (error) {
console.error("❌ Lỗi khi tìm kiếm bạn bè:", error);
            this.searchMessage = 'Có lỗi xảy ra trong quá trình tìm kiếm';
            this.requestUpdate();
        }
    }
    async sendFriendRequest(userId) {
        try {
            // 1. Cập nhật UI ngay lập tức (nếu muốn)
            this.status = 'pending';
            this.requestUpdate();

            // 2. Gọi API
            const response = await fetch(`/api/users/${userId}/send_request`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                credentials: 'include'
            });

            // 3. Xử lý kết quả
            if (!response.ok) throw new Error(`HTTP ${response.status}`);

            const data = await response.json();
            console.log("Phản hồi từ server:", data);

            // 4. Cập nhật state: nếu thành công, gán status thành 'pending'
            if (data.success) {
                this.status = 'pending';
                // Cập nhật searchedUser nếu cần
                this.searchedUser = { ...this.searchedUser, status: 'pending' };
            }
        } catch (error) {
            console.error("❌ Lỗi:", error);
            this.status = null; // Rollback nếu thất bại
        } finally {
            this.requestUpdate(); // Đảm bảo re-render
        }
    }



    async cancelFriendRequest(userId) {
        try {
            const response = await fetch(`/api/users/${userId}/cancel_request`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                credentials: 'include'
            });

            if (!response.ok) {
                throw new Error(`Không thể hủy yêu cầu kết bạn. HTTP ${response.status}`);
            }

            const data = await response.json();
            this.status = data.status;
            this.requestUpdate();
        } catch (error) {
            console.error("❌ Lỗi khi hủy yêu cầu kết bạn:", error);
        }
    }

    async unfriend(friendId) {
        try {
            const response = await fetch(`/api/unfriend/${friendId}`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json'
                },
                credentials: 'include'
            });

            if (!response.ok) {
                throw new Error(`Không thể hủy kết bạn. HTTP ${response.status}`);
            }

            this.friends = this.friends.filter(friend => friend.id !== friendId);
            this.requestUpdate();
        } catch (error) {
            console.error("❌ Lỗi khi hủy kết bạn:", error);
        }
    }

    updateSearchEmail(e) {
        this.searchEmail = e.target.value;
    }
    navigate(event) {
        console.log("Navigating to:", event.target.href);
        window.location.href = event.target.href; // Chuyển hướng hoàn toàn
        history.pushState({}, '', event.target.href);
        console.log("History updated, current path:", window.location.pathname);
    }

    render() {
        if (!this.currentUser) {
            return html`<p>Đang tải...</p>`;
        }

        return html`
      <h1>Danh sách bạn bè</h1>

      <!-- Form tìm kiếm bạn bè -->
      <h2>Tìm kiếm bạn bè</h2>
      <form @submit="${this.searchFriend}">
        <input
          type="email"
          .value="${this.searchEmail}"
          @input="${this.updateSearchEmail}"
          placeholder="Nhập email thành viên"
          required
        />
        <button type="submit">Tìm kiếm</button>
      </form>

      <!-- Hiển thị thông báo kết quả tìm kiếm -->
      ${this.searchMessage ? html`
        <p style="color: ${this.searchedUser ? 'green' : 'red'};">${this.searchMessage}</p>
      ` : ''}

      <!-- Hiển thị kết quả tìm kiếm nếu có -->
      ${this.searchedUser ? html`
        <h2>Thông tin người dùng tìm thấy:</h2>
        <img src="${this.searchedUser.avatar_url}" alt="avatar" class="message-avatar" />
        <p>Email: ${this.searchedUser.email}</p>
        <p>ID: ${this.searchedUser.id}</p>

        ${this.searchedUser.id !== this.currentUser.id ? html`
          ${this.status === 'pending' ? html`
            <button @click="${() => this.cancelFriendRequest(this.searchedUser.id)}">Hủy yêu cầu</button>
          ` : this.status === 'accepted' ? html`
            <p>Đã là bạn bè</p>
          ` : html`
            <button @click="${() => this.sendFriendRequest(this.searchedUser.id)}">Kết bạn</button>
          `}
        ` : html`
          <p style="color: red;">(Bạn không thể kết bạn với chính mình)</p>
        `}
      ` : ''}

      <!-- Danh sách bạn bè -->
      <h2>Danh sách bạn bè</h2>
      ${Array.isArray(this.friends) && this.friends.length > 0 ? html`
        <ul>
          ${this.friends.map(friend => html`
            <li>
              <img src="${friend.avatar_url}" alt="avatar" class="message-avatar" />
              <p>Email: ${friend.email}</p>
              <p>ID: ${friend.id}</p>
              <button @click="${() => this.unfriend(friend.id)}">Hủy kết bạn</button>
            </li>
          `)}
        </ul>
      ` : html`
        <p>Bạn chưa có bạn bè nào.</p>
      `}

      <!-- Nút quay lại Dashboard -->
      <a
        href="/dashboard"
        @click="${this.navigate}"
        class="inline-block px-6 py-3 bg-blue-500 text-white font-bold rounded-lg shadow-md hover:bg-blue-700 transition duration-300"
      >
        Quay lại Dashboard
      </a>
    `;
    }
}

customElements.define('list_friends-component', FriendsComponent);