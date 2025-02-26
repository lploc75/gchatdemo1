import { html, css, LitElement } from "lit";
import { Socket } from "phoenix";

export class ChatRoom extends LitElement {
  static styles = css`
  .chat-container { 
    display: flex; 
    border: 1px solid #ddd; 
    border-radius: 8px; 
    overflow: hidden; 
    height: auto; 
    background: #f5f7fa;
  }
  
  .group-list { 
    width: 25%; 
    padding: 10px; 
    border-right: 1px solid #ddd; 
    background: #ffffff;
    overflow-y: auto;
  }

  .group-list h3 {
    text-align: center;
    font-size: 1.2em;
    color: #333;
  }

  ul { 
    list-style: none; 
    padding: 0; 
    margin: 0;
  }

  li { 
    padding: 10px; 
    cursor: pointer; 
    border-radius: 4px; 
    background: #fff; 
    margin-bottom: 5px;
    transition: background 0.2s;
  }

  li:hover { 
    background: #e0e0e0; 
  }

  .chat-box { 
    flex: 1; 
    display: flex; 
    flex-direction: column; 
    background: #ffffff;
    padding: 15px;
  }

  .chat-box h3 {
    text-align: center;
    color: #333;
  }

.email {
  font-size: 0.85em;
  margin-bottom: 5px;
  font-weight: bold;
}
  .messages { 
    flex: 1; 
    height: 350px; 
    overflow-y: auto; 
    border: 1px solid #ddd; 
    padding: 10px; 
    background: #fafafa;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .message { 
    position: relative;
    padding: 8px 12px; 
    border-radius: 8px; 
    max-width: 70%;
    word-wrap: break-word;
    margin-bottom: 2px; /* Khoảng cách mặc định */
  }

  .message.me { 
    align-self: flex-end; 
    background: #007bff; 
    color: #fff;
  }

  .message.other { 
    align-self: flex-start; 
    background: #e4e6eb;
    color: #333;
  }

  .message-input { 
    display: flex; 
    margin-top: 10px; 
    gap: 8px;
  }

  input { 
    flex: 1; 
    padding: 10px; 
    border: 1px solid #ddd; 
    border-radius: 6px; 
    font-size: 16px;
  }

  button { 
    padding: 10px 15px; 
    cursor: pointer; 
    background: #007bff; 
    color: white; 
    border: none; 
    border-radius: 6px; 
    font-size: 16px;
    transition: background 0.2s;
  }

  button:hover { 
    background: #0056b3; 
  }

  /* Context Menu */
  .context-menu {
  position: absolute;
  background: white;
  border: 1px solid #ddd;
  box-shadow: 2px 2px 5px rgba(0, 0, 0, 0.2);
  padding: 5px;
  z-index: 1000;
  }

  .context-menu button {
    background: #ff5252;
   color: white;
    border: none;
    padding: 5px 10px;
    cursor: pointer;
    font-size: 14px;
  }

  .context-menu.show {
  display: block;
  visibility: visible; /* Hiện khi có class show */
  }
  reaction {
  position: absolute;
  bottom: -10px;
  right: -5px;
  background: white;
  border-radius: 50%;
  padding: 3px 5px;
  font-size: 14px;
  box-shadow: 0px 0px 5px rgba(0, 0, 0, 0.2);
}

.emoji-picker {
  display: none;
  position: absolute;
  bottom: -30px;
  left: 50%;
  transform: translateX(-50%);
  background: white;
  border-radius: 20px;
  box-shadow: 0px 2px 5px rgba(0, 0, 0, 0.2);
  padding: 5px;
  z-index: 1000;
}

.message:hover .emoji-picker {
  display: flex;
}

.emoji-picker button {
  border: none;
  background: transparent;
  font-size: 18px;
  cursor: pointer;
}
  .reaction {
  position: absolute;
  bottom: -15px;
  right: 5px;
  background: white;
  border-radius: 15px;
  padding: 2px 8px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  font-size: 0.8em;
}

.message.has-reaction {
  margin-bottom: 15px; /* Tăng khoảng cách giữa các tin nhắn có emoji */
}
`;

  static properties = {
    groups: { type: Array },
    selectedGroup: { type: Object },
    messages: { type: Array },
    socket: { type: Object },
    channel: { type: Object },
    selectedMessageId: { type: String },
    contextMenuVisible: { type: Boolean },
    contextMenuPosition: { type: Object }
  };

  constructor() {
    super();
    this.groups = [];
    this.selectedGroup = null;
    this.selectedMessageId = null; // Lưu tin nhắn đang được chọn để thu hồi
    this.messages = [];
    this.socket = null;
    this.channel = null;
    this.contextMenuVisible = false; // Menu khi nhắn chuột phải
    this.contextMenuPosition = { top: 0, left: 0 }; 
  }
  
  async getUserIdAndToken() {
    try {
      const res = await fetch("/api/user_token", { credentials: "include" });
      const data = await res.json();
      if (data.token) {
        console.log("✅ Đã lấy token và user_id:", data.token, data.user_id);
        return { token: data.token, userId: data.user_id }; // Returning both token and userId
      } else {
        console.error("❌ Không thể lấy token!", data.error);
        return null;
      }
    } catch (error) {
      console.error("❌ Lỗi lấy token:", error);
      return null;
    }
  }

  async connectedCallback() {
    super.connectedCallback();
    const userData = await this.getUserIdAndToken(); // Lấy user id và session token
    if (userData) {
      const { token, userId } = userData;  // Destructure to get token and userId
      console.log("userId:", userId); // Check userId
      this.userId = userId; // Store userId
      this.initializeSocket(token);
    }

    this.loadGroups();
    document.addEventListener("click", (event) => {
      const contextMenu = this.shadowRoot.querySelector(".context-menu");
      if (contextMenu && !contextMenu.contains(event.target)) {
        this.contextMenuVisible = false;
        this.requestUpdate(); // 🔥 Cập nhật trạng thái để ẩn context menu
      }
    });  }

  initializeSocket(token) {
    this.socket = new Socket("/socket", { params: { token } });
    this.socket.connect();
  }

  async loadGroups() {
    try {
      const res = await fetch("/api/groups");
      if (!res.ok) throw new Error("Không thể tải nhóm!");
      this.groups = await res.json();
    } catch (error) {
      console.error(error);
    }
  }
  async selectGroup(group) {
    this.selectedGroup = group;
    this.messages = [];

    try {
      const res = await fetch(`/api/messages/${group.id}`);
      if (!res.ok) throw new Error("Không thể tải tin nhắn!");

      const data = await res.json(); // ✅ Lấy dữ liệu từ API
      console.log("📩 Tin nhắn từ API:", data); // ✅ Kiểm tra dữ liệu API
      this.messages = data.map(msg => {
        // console.log(`🧐 Tin nhắn ID: ${msg.id}, user_id: ${msg.user_id}, this.userId: ${this.userId},`);
        return {
          id: msg.id,  // Thêm ID để nhận diện tin nhắn khi thu hồi
          content: msg.content,
          sender: msg.user_id === this.userId ? "me" : "other",
          email: msg.user_email, // Lấy email từ API
          reaction: msg.reaction, // Lấy emoji từ API
          is_recalled: msg.is_recalled, // Tin nhắn bị thu hồi
        };
      });
      console.log("✅ Tin nhắn sau khi gán sender:", this.messages);

    } catch (error) {
      console.error("❌ Lỗi khi tải tin nhắn:", error);
      this.messages = []; // Nếu lỗi, giữ giá trị là mảng rỗng
    }

    // 🔴 Hủy đăng ký kênh cũ nếu có
    if (this.channel) {
      this.channel.leave();
    }

    // 🔵 Tham gia kênh mới
    if (this.socket) {
      this.channel = this.socket.channel(`group_chat:${group.id}`, {});
      this.channel.join()
        .receive("ok", () => {
          console.log(`✅ Đã tham gia kênh group_chat:${group.id}`);
        })
        .receive("error", (err) => {
          console.error("❌ Lỗi tham gia kênh:", err);
        });

      // Lắng nghe tin nhắn mới từ kênh
      this.channel.on("new_message", (payload) => {
        console.log("📩 Nhận tin nhắn mới:", payload);

        // Kiểm tra xem payload.message có tồn tại và có chứa thuộc tính content không
        if (payload.message && payload.message.content) {
          const newMessage = {
            id: payload.message.id,  
            content: payload.message.content,
            sender: payload.sender,
            email: payload.email, // Email từ payload của WebSocket
          };
          // Thêm tin nhắn mới vào danh sách tin nhắn hiện tại
          this.messages = [...this.messages, newMessage];
        } else {
          console.error("❌ Tin nhắn không hợp lệ:", payload.message);
        }
      });
      this.channel.on("message_recalled", (payload) => {
        console.log("🚨 Tin nhắn bị thu hồi:", payload);

        // Cập nhật danh sách tin nhắn: thay thế nội dung tin nhắn thành "[Message recalled]"
        this.messages = this.messages.map(msg =>
          msg.id === payload.message_id ? { ...msg, content: html`<em>Tin nhắn đã được thu hồi</em>`, reaction: msg.reaction ? null : undefined , is_recalled: true }
          : msg
        );
      });
      
      // Xóa tin nhắn
      this.channel.on("message_deleted", (payload) => {
        console.log("🗑 Tin nhắn bị xóa:", payload);
        this.messages = this.messages.filter(msg => msg.id !== payload.message_id);
      });
      // Thả emoji vào tin nhắn
      this.channel.on("reaction_added", (payload) => {
        console.log("💬 Nhận phản ứng emoji:", payload);

        this.messages = this.messages.map(msg => {
          if (msg.id === payload.message_id) {
            return {
              ...msg,
              reaction: payload.emoji // lưu emoji
            };
          }
          return msg;
        });
      });
      // Xóa emoji khỏi tin nhắn
      this.channel.on("reaction_removed", (payload) => {
        console.log("💬 Emoji bị xóa khỏi tin nhắn:", payload);

        this.messages = this.messages.map(msg => {
          if (msg.id === payload.message_id) {
            return { ...msg, reaction: null }; // Xóa emoji khỏi tin nhắn
          }
          return msg;
        });
      });

    } else {
      console.error("❌ WebSocket chưa được kết nối!");
    }
  }

  sendMessage(e) {
    e.preventDefault();
    const input = this.shadowRoot.querySelector("#message-input");
    if (!input.value.trim()) return;

    if (this.channel) {
      console.log("📤 Gửi tin nhắn:", input.value.trim());

      // Giả sử bạn có email của người dùng trong biến this.userEmail
      const message = {
        content: input.value.trim(),
        // sender: "me",  // Gán sender là "me" cho tin nhắn của bạn
      };

      this.channel.push("new_message", message)
        .receive("ok", (resp) => {
          console.log("✅ Tin nhắn đã gửi:", resp.message);
          // Cập nhật danh sách tin nhắn
          // this.messages = [...this.messages, { ...resp.message, sender: "me" }];
        })
        .receive("error", (err) => {
          console.error("❌ Lỗi gửi tin nhắn:", err);
          alert("Không thể gửi tin nhắn. Vui lòng thử lại!");
        });

      input.value = "";
    } else {
      console.error("❌ Chưa kết nối channel!");
    }
  }

  showContextMenu(event, messageId) {
    event.preventDefault();
    console.log("📌 Chuột phải vào tin nhắn:", messageId); // Kiểm tra hàm có chạy không

    const msg = this.messages.find(msg => msg.id === messageId);
    if (!msg) return;

    // Nếu tin nhắn của sender là "other" -> Không hiển thị context menu
    if (msg.sender === "other") {
      console.log("🚫 Không thể mở context menu cho tin nhắn của người khác");
      return;
    }
    this.selectedMessageId = messageId; // Lưu ID tin nhắn đang chọn
    this.contextMenuPosition = { top: event.clientY, left: event.clientX };
    this.contextMenuVisible = true;
    console.log("📌 Hiển thị context menu tại:", this.contextMenuPosition);
    this.requestUpdate(); // 🔥 Cập nhật UI để hiển thị context menu
  }

  recallMessage(messageId) {
    console.log("🚀 Đang thu hồi tin nhắn:", messageId);
    this.channel.push("recall_message", { message_id: messageId });
  }

  deleteMessage(messageId) {
    console.log("Xóa tin nhắn:", messageId);
    if (this.channel) {
      this.channel.push("delete_message", { message_id: messageId })
        .receive("ok", () => {
          console.log("✅ Tin nhắn đã bị xóa");
        })
        .receive("error", (err) => {
          console.error("❌ Lỗi khi xóa tin nhắn:", err);
          alert("Không thể xóa tin nhắn!");
        });
    }
  }

  reactToMessage(messageId, emoji) {
    console.log(`📢 Thả hoặc bỏ emoji: ${emoji} vào tin nhắn ${messageId}`);

    const message = this.messages.find(msg => msg.id === messageId);

    if (this.channel) {
      if (message.reaction === emoji) {
        // Nếu emoji đã tồn tại, thì gửi sự kiện xóa reaction
        this.channel.push("remove_reaction", { message_id: messageId })
          .receive("ok", () => {
            console.log(`✅ Đã xóa emoji ${emoji}`);
          })
          .receive("error", (err) => {
            if (err === "Reaction not found") {
              console.error("❌ Reaction not found");
            } else {
              console.error("❌ Lỗi khi xóa emoji:", err);
            }
          });
      } else {
        // Nếu chưa có emoji, gửi sự kiện thêm reaction
        this.channel.push("add_reaction", { message_id: messageId, emoji })
          .receive("ok", () => {
            console.log(`✅ Đã gửi emoji ${emoji}`);
          })
          .receive("error", (err) => {
            console.error("❌ Lỗi khi thả emoji:", err);
          });
      }
    }
  }

  render() {
    return html`
      <div class="chat-container">
        <div class="group-list">
          <h3>Nhóm Chat</h3>
          <ul>
            ${this.groups.map((group) => html`
                <li @click="${() => this.selectGroup(group)}">${group.name}</li>
              `
            )}
      </ul>
      </div>
        <div class="chat-box">
          ${this.selectedGroup? html`
                <h3>Nhóm: ${this.selectedGroup.name}</h3>
                  <div class="messages">
                  ${this.messages.map((msg) => html`
                    <div class="message ${msg.sender} ${msg.reaction ? 'has-reaction' : ''}" data-id="${msg.id}
                    " @contextmenu="${(e) => this.showContextMenu(e, msg.id)}">
                    <div class="email">${msg.email}</div> 
                    <div class="content">
                      ${msg.is_recalled ? html`<em>Tin nhắn đã được thu hồi</em>` : msg.content}
                    </div>
                   ${msg.reaction ? html`
                    <div class="reaction">${msg.reaction}</div>
                  ` : ""}  
                <!-- Nút thả emoji ẩn, hiện khi hover -->
                ${!msg.is_recalled ? html`
                    <div class="emoji-picker">
                      ${["😍", "😂", "👍", "❤️"].map(
                        (emoji) => html`
                          <button @click="${() => this.reactToMessage(msg.id, emoji)}">${emoji}</button>
                        `
                      )}
                    </div>
                  ` : ""}
                  `)}
                </div>

                <form @submit="${this.sendMessage}" class="message-input">
                  <input id="message-input" type="text" placeholder="Nhập tin nhắn..." />
                  <button type="submit">Send</button>
                </form>
              `
        : html`<p>Chọn nhóm để bắt đầu chat</p>`}
      </div>
    </div>

      ${this.contextMenuVisible ? html`
      <div class="context-menu"
        style="top: ${this.contextMenuPosition.top}px; left: ${this.contextMenuPosition.left}px;"
        @click="${(e) => e.stopPropagation()}">
        ${(() => {
              const msg = this.messages.find(msg => msg.id === this.selectedMessageId);
              if (!msg) return null;

              return html`
            ${!msg.is_recalled
                  ? html`<button @click="${() => this.recallMessage(this.selectedMessageId)}">Thu hồi tin nhắn</button>`
                  : ""}
          <button @click="${() => this.deleteMessage(this.selectedMessageId)}">Xóa tin nhắn</button>
          `;
        })()}
      </div>

      ` : ''}

    `;
  }
}

customElements.define("chat-room", ChatRoom);
