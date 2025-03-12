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
    position: relative; /* Làm gốc để căn chỉnh icon tìm kiếm */
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
    
  .search-icon {
    position: absolute;
    top: 10px;
    right: 10px;
    background: none;
    border: none;
    font-size: 20px;
    cursor: pointer;
    padding: 5px;
    color: #333;
    z-index: 10; /* Đảm bảo nằm trên tin nhắn */
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
  
/* Buộc ẩn form ngay cả khi display: flex có mặt */
  .message-input[hidden] {
    display: none !important;
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

.search-controls {
  display: none;
  padding: 5px;
  border-radius: 5px;
  margin-left: 10px;
}

.search-controls.visible {
  display: block;
}

.search-input {
  border: 1px solid #ccc;
  padding: 5px;
  border-radius: 5px;
  flex-grow: 1;
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
    this.editHistory = {}; // Lưu lịch sử chỉnh sửa theo từng messageId
    this.showEditHistoryId = null; // Message đang hiển thị lịch sử chỉnh sửa
    this.showSearchInput = false;

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
    });
  }

  initializeSocket(token) {
    this.socket = new Socket("/socket", { params: { token } });
    this.socket.connect();
  }

  // Chọn nhóm chat và gán vào selectedGroup
  async selectGroup(group) {
    this.selectedGroup = group;
    console.log("🚀 Đã chọn nhóm:", group);
    this.messages = [];
    try {
      const res = await fetch(`/api/messages/${group.conversation.id}`);
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
          is_edited: msg.is_edited, // Tin nhắn đã sửa
        };
      });
      console.log("✅ Tin nhắn sau khi gán sender:", this.messages);
    // 🔹 Gọi hàm loadMembers để tải danh sách thành viên
    await this.loadMembers(group.conversation.id);
    console.log("👥 SELECTED GROUP:", this.selectedGroup);
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
      this.channel = this.socket.channel(`group_chat:${group.conversation.id}`, {});
      this.channel.join()
        .receive("ok", () => {
          console.log(`✅ Đã tham gia kênh group_chat:${group.conversation.id}`);
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
          console.error("❌ Tin nhắn không hợp lệ:", payload.email);
        }
      });
      this.channel.on("message_recalled", (payload) => {
        console.log("🚨 Tin nhắn bị thu hồi:", payload);

        // Cập nhật danh sách tin nhắn: thay thế nội dung tin nhắn thành "[Message recalled]"
        this.messages = this.messages.map(msg =>
          msg.id === payload.message_id ? {
            ...msg, content: html`<em>Tin nhắn đã được thu hồi</em>`,
            reaction: msg.reaction ? null : undefined, is_recalled: true
          }
            : msg
        );
      });

      // Xóa tin nhắn
      this.channel.on("message_deleted", (payload) => {
        console.log("Tin nhắn bị xóa:", payload);
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
      this.channel.on("message_edited", (payload) => {
        this.messages = this.messages.map(msg => {
          if (msg.id === payload.message_id) {
            return {
              ...msg,
              content: payload.new_content,
              is_edited: true,
              edited_at: payload.edited_at // Hiển thị thời gian sửa
            }
          }
          return msg
        })
      })
    } else {
      console.error("❌ WebSocket chưa được kết nối!");
    }
  }

  async loadGroups() {
    try {
      const res = await fetch("/api/groups");
      if (!res.ok) throw new Error("Không thể tải nhóm!");
      this.groups = await res.json();
      console.log(this.groups);
    } catch (error) {
      console.error(error);
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

  startEditingMessage(messageId) {
    const msg = this.messages.find(msg => msg.id === messageId);
    if (!msg) return;

    this.editingMessageId = messageId;
    this.editingMessageContent = msg.content; // Lưu nội dung cũ để sửa
    this.contextMenuVisible = false; // Ẩn context menu
    this.requestUpdate();
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

  saveEditedMessage(messageId) {
    if (!this.editingMessageContent.trim()) return;

    this.channel.push("edit_message", { id: messageId, content: this.editingMessageContent })
      .receive("ok", (res) => {
        console.log("✅ Tin nhắn đã chỉnh sửa:", res);
        const msgIndex = this.messages.findIndex(m => m.id === messageId);
        if (msgIndex !== -1) {
          this.messages[msgIndex].content = this.editingMessageContent;
        }
        this.editingMessageId = null;
        this.requestUpdate();
      })
      .receive("error", (err) => {
        console.error("❌ Lỗi khi chỉnh sửa tin nhắn:", err);
      });
  }
  cancelEditing() {
    this.editingMessageId = null;
    this.editingMessageContent = "";
    this.requestUpdate();
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
        this.channel.push("add_reaction", { emoji, message_id: messageId })
          .receive("ok", () => {
            console.log(`✅ Đã gửi emoji ${emoji}`);
          })
          .receive("error", (err) => {
            console.error("❌ Lỗi khi thả emoji:", err);
          });
      }
    }
  }

  // Phương thức lấy danh sách bạn bè từ API
  async loadFriends() {
    try {
      const res = await fetch('/api/friends', { credentials: "include" });
      if (!res.ok) throw new Error("Không thể tải danh sách bạn bè!");
      this.friends = await res.json();
      console.log(this.friends);
    } catch (error) {
      console.error(error);
    }
  }

  async getNonGroupFriends(conversationId) {
    try {
      const res = await fetch(`/api/conversations/${conversationId}/available_friends`, { credentials: "include" });
      if (!res.ok) throw new Error("Không thể tải danh sách bạn bè!");
      const data = await res.json();
      this.friends = data.friends;
    } catch (error) {
      console.error(error);
    }
  }

  // Xử lý tạo nhóm khi submit form
  async createGroup(e) {
    e.preventDefault();
    const nameInput = this.shadowRoot.querySelector("#group-name");
    const selectEl = this.shadowRoot.querySelector("#friends-select");

    const name = nameInput.value.trim();
    // Lấy danh sách friend_id được chọn
    const selectedFriendIds = Array.from(selectEl.selectedOptions).map(option => option.value);

    // Kiểm tra số lượng thành viên: creator được tự động thêm vào, nên cần chọn tối thiểu 2 bạn nữa
    if (selectedFriendIds.length < 2) {
      alert("Cần ít nhất 3 thành viên (bao gồm bạn)!");
      return;
    }

    try {
      const res = await fetch("/api/groups/create", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, member_ids: selectedFriendIds })
      });
      const data = await res.json();
      if (res.ok) {
        const newGroup = {
          conversation: data.group, // Đưa group vào conversation
          admin_user_id: data.group.creator_id // Người tạo là admin
        };
        this.groups = [...this.groups, newGroup];
        console.log("Danh sách nhóm sau khi thêm:", this.groups);
        alert("Tạo nhóm thành công!");
        this.closeCreateGroupModal();
      } else {
        alert(data.message || "Lỗi khi tạo nhóm");
      }
    } catch (error) {
      console.error("❌ Lỗi khi tạo nhóm:", error);
    }
  }

  async deleteGroup() {
    if (!confirm("Bạn có chắc chắn muốn xóa nhóm này không?")) return;

    try {
      const response = await fetch("/api/groups/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ conversation_id: this.selectedGroup?.conversation.id }),
      });

      const result = await response.json();
      if (response.ok) {
        alert(result.message);

        // Cập nhật lại danh sách nhóm sau khi xóa
        this.groups = this.groups.filter(group => group.conversation.id !== this.selectedGroup?.conversation.id);
        this.closeEditGroupModal();
      } else {
        alert(result.message || "Có lỗi xảy ra!");
      }
    } catch (error) {
      console.error("Lỗi khi xóa nhóm:", error);
      alert("Có lỗi xảy ra, vui lòng thử lại!");
    }
  }

  async leaveGroup() {
    if (!confirm("Bạn có chắc muốn rời nhóm này không?")) return;

    try {
      const response = await fetch("/api/groups/leave", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ conversation_id: this.selectedGroup?.conversation.id }),
      });

      const result = await response.json();
      if (response.ok) {
        // Cập nhật danh sách nhóm sau khi rời nhóm
        this.groups = this.groups.filter(group => group.conversation.id !== this.selectedGroup?.conversation.id);
        alert(result.message);
        this.closeEditGroupModal(); // Đóng modal sau khi rời nhóm
      } else {
        alert(result.message || "Có lỗi xảy ra!");
      }
    } catch (error) {
      console.error("Lỗi khi rời nhóm:", error);
      alert("Có lỗi xảy ra, vui lòng thử lại!");
    }
  }

  async saveGroupEdit() {
    if (!this.selectedGroup || !this.selectedGroupName.trim()) return;

    try {
      const res = await fetch("/api/groups/update", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: this.selectedGroup.conversation.id, // lấy id từ conversation
          conversation: {
            name: this.selectedGroupName.trim(),
            only_admin_can_message: this.onlyAdminCanMessage,
            visibility: this.visibility
          }
        })
      });

      if (!res.ok) throw new Error("Không thể cập nhật nhóm!");

      const data = await res.json();
      if (data.status === "ok") {
        // Cập nhật UI: Cập nhật thông tin trong conversation
        this.groups = this.groups.map(group =>
          group.conversation.id === this.selectedGroup.conversation.id
            ? {
              ...group,
              conversation: {
                ...group.conversation,
                name: this.selectedGroupName.trim(),
                only_admin_can_message: this.onlyAdminCanMessage,
                visibility: this.visibility
              }
            }
            : group
        );
        this.closeEditGroupModal();
      } else {
        alert("Lỗi cập nhật nhóm!");
      }
    } catch (error) {
      console.error("❌ Lỗi khi chỉnh sửa nhóm:", error);
      alert("Không thể cập nhật nhóm!");
    }
  }


  toggleSelectedFriend(event, userId) {
    if (!this.selectedFriends) {
      this.selectedFriends = new Set();
    }

    if (event.target.checked) {
      this.selectedFriends.add(userId);
    } else {
      this.selectedFriends.delete(userId);
    }
  }

  async addSelectedFriendsToGroup() {
    if (!this.selectedFriends || this.selectedFriends.size === 0) {
      alert("Vui lòng chọn ít nhất một người bạn để thêm vào nhóm!");
      return;
    }

    try {
      const conversationId = this.selectedGroup.conversation.id;
      const userIds = Array.from(this.selectedFriends); // Chuyển Set thành mảng

      for (const userId of userIds) {
        const res = await fetch(`/api/groups/add_member`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json"
          },
          body: JSON.stringify({ conversation_id: conversationId, user_id: userId })
        });

        const data = await res.json();
        if (data.status !== "ok") {
          console.error(`Lỗi khi thêm thành viên ID ${userId}:`, data.errors);
        }
      }

      alert("Thêm thành viên thành công!");
      this.closeAddMemberModal();
    } catch (error) {
      console.error("Lỗi khi thêm thành viên:", error);
    }
  }

  async removeMember(userId) {
    if (!confirm("Bạn có chắc muốn xóa thành viên này khỏi nhóm?")) return;

    try {
      const res = await fetch("/api/groups/remove_member", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          conversation_id: this.selectedGroup.conversation.id,
          user_id: userId,
        }),
      });

      const data = await res.json();
      if (res.ok) {
        this.selectedGroup.members = this.selectedGroup.members.filter(m => m.id !== userId);
        alert("Xóa thành viên thành công!");
        this.requestUpdate();
      } else {
        alert(data.error || "Lỗi khi xóa thành viên");
      }
    } catch (error) {
      console.error("❌ Lỗi khi xóa thành viên:", error);
    }
  }
  // Gọi tìm kiếm tin nhắn sau khi chọn người gửi
  onMemberSelect(event) {
    this.selectedFindUserId = event.target.value;
    console.log("👤 Đã chọn user_id:", this.selectedFindUserId);
    this.searchMessages(); // Gọi lại tìm kiếm ngay khi chọn user
  }
  
  // Tìm kiếm tin nhắn
  async searchMessages() {
    const content = this.searchQuery.trim();
    const userId = this.selectedFindUserId; // Lấy user_id từ dropdown
    const conversationId = this.selectedGroup?.conversation?.id || '';

    console.log("🔍 Từ khoá:", content, "| 👤 User ID:", userId, "| 💬 Conversation ID:", conversationId);

    if (content === '' && !userId) {
      this.searchResults = [];
      this.requestUpdate();
      return;
    }

    try {
      // Xây dựng URL query
      const params = new URLSearchParams();
      if (content) params.append("content", content);
      if (conversationId) params.append("conversation_id", conversationId);
      if (userId) params.append("user_id", userId);

      const response = await fetch(`/api/messages/search?${params.toString()}`);
      if (!response.ok) throw new Error('Lỗi khi gọi API');

      const data = await response.json();
      // Cập nhật danh sách tin nhắn tìm được và xác định sender
      this.searchResults = data.messages.map(msg => ({
        ...msg,
        sender: msg.user_id === this.userId ? "me" : "other"
      }));
      console.log('Kết quả tìm kiếm:', this.searchResults);
      this.requestUpdate(); // Cập nhật giao diện ngay lập tức

    } catch (error) {
      console.error('Lỗi tìm kiếm:', error);
    }
  }

  toggleSearch() {
    this.showSearchInput = !this.showSearchInput;
    this.searchQuery = "";  // Xoá nội dung tìm kiếm
    this.selectedFindUserId = ""; // Reset lại thành viên đã chọn
    this.searchResults = []; // Xoá kết quả tìm kiếm
    this.requestUpdate();
  }

  // Mở modal tạo nhóm và load danh sách bạn bè
  async openCreateGroupModal() {
    await this.loadFriends();
    this.closeEditGroupModal();
    this.showCreateGroupModal = true;
    this.requestUpdate();
  }

  async openEditGroupModal(event, group) {
    event.stopPropagation(); // Ngăn chặn sự kiện click lan ra ngoài
    this.selectedGroup = group;
    console.log("🚀 Đang chỉnh sửa nhóm:", this.selectedGroup);

    // 🔹 Đóng các modal khác trước khi mở modal chỉnh sửa
    this.closeMemberListModal();
    this.closeAddMemberModal();
    this.closeCreateGroupModal();

    // 🔹 Gán thông tin nhóm vào biến state
    this.selectedGroupName = group.conversation.name;
    this.onlyAdminCanMessage = group.conversation.only_admin_can_message; // ✅ Cập nhật checkbox
    this.visibility = group.conversation.visibility; // ✅ Cập nhật dropdown

    try {
      // 🔹 Gọi loadMembers để lấy danh sách thành viên mới nhất
      await this.loadMembers(group.conversation.id);
      console.log("👥 Danh sách thành viên đã tải:", this.selectedGroup.members);
    } catch (error) {
      console.error("❌ Lỗi khi tải danh sách thành viên:", error);
    }
    
    this.showEditGroupModal = true;
    this.requestUpdate();
  }

  async openAddMemberModal() {
    await this.getNonGroupFriends(this.selectedGroup.conversation.id);
    console.log(this.selectedGroup.conversation.id);
    this.showEditGroupModal = false;

    this.showAddMemberModal = true;
    this.requestUpdate();
  }

  async loadMembers() {
    try {
      const res = await fetch(`/api/groups/${this.selectedGroup.conversation.id}/members`);
      const data = await res.json();
  
      if (data.status === "ok") {
        this.selectedGroup.members = data.members; // Gán danh sách thành viên vào nhóm đã chọn
        // console.log("👥 Thành viên của nhóm:", this.selectedGroup.members);
      } else {
        console.error("❌ Lỗi khi tải danh sách thành viên:", data.errors);
      }
    } catch (error) {
      console.error("❌ Lỗi khi tải danh sách thành viên:", error);
      this.selectedGroup.members = [];
    }
  }

  openMemberListModal() {
    if (!this.selectedGroup || !this.selectedGroup.members) {
      console.error("❌ Không có nhóm nào được chọn hoặc danh sách thành viên trống!");
      return;
    }
    this.showEditGroupModal = false;
    this.showMemberListModal = true;
    this.requestUpdate();
  }

  // Đóng modal
  closeCreateGroupModal() {
    this.showCreateGroupModal = false;
    this.requestUpdate();
  }

  closeEditGroupModal() {
    this.showEditGroupModal = false;
    this.requestUpdate();
  }

  closeAddMemberModal() {
    this.showAddMemberModal = false;
    this.showEditGroupModal = true;
    this.requestUpdate();
  }

  closeMemberListModal() {
    this.showMemberListModal = false;
    this.showEditGroupModal = true;
    this.requestUpdate();
  }

  render() {
    return html`
      <div class="chat-container">
        <div class="group-list">
          <h3>Nhóm Chat</h3>
          <button @click="${this.openCreateGroupModal}">Tạo nhóm</button>
          <ul>
            ${this.groups.map((group) => html`
              <li>
                <span @click="${() => this.selectGroup(group)}">${group.conversation.name}</span>
                <button class="menu-button" @click="${(e) => this.openEditGroupModal(e, group)}">⋮</button>
              </li>
            `)}
          </ul>
      </div>
        <div class="chat-box">
          ${this.selectedGroup ? html`
                <h3>Nhóm: ${this.selectedGroup.conversation.name}</h3>
                  <div class="messages">
                    <div class="search-container">
                      <button class="search-icon" @click="${this.toggleSearch}">&#x1F50E;&#xFE0E;</button>

                      <!-- 🔹 Dropdown và ô tìm kiếm -->
                      <div class="search-controls ${this.showSearchInput ? 'visible' : ''}">
                      <input 
                      type="text" 
                      class="search-input"
                      placeholder="Nhập nội dung tìm kiếm..." 
                      @input="${(e) => { this.searchQuery = e.target.value; this.searchMessages(); }}"
                                          .value="${this.searchQuery}">

                      <select class="member-select" @change="${this.onMemberSelect}" .value="${this.selectedFindUserId}">
                        <option value="">Chọn thành viên</option>
                        ${this.selectedGroup.members?.map(member => html`
                          <option value="${member.id}">${member.email}</option>
                        `)}
                      </select>
                  </div>

                  </div>
                    <!-- 🔥 Nếu có kết quả tìm kiếm, hiển thị danh sách tìm kiếm -->
                    ${this.searchResults && this.searchResults.length > 0 ? html`
                    <div class="search-results">
                      ${this.searchResults.map((msg) => html`
                        <div class="message ${msg.sender} search-result" @click="${() => this.jumpToMessage(msg.id)}">
                          <div class="email">${msg.email}</div>
                          <div class="content">${msg.content}</div>
                        </div>
                      `)}
                    </div>
                    ` : html`
                    <!-- 🔥 Hiển thị tin nhắn bình thường -->
                    ${this.messages.map((msg) => html`
                      <div class="message ${msg.sender} ${msg.reaction ? 'has-reaction' : ''}" data-id="${msg.id}"
                        @contextmenu="${(e) => this.showContextMenu(e, msg.id)}">
                        <div class="email">${msg.email}</div> 
                        <div class="content">
                          ${this.editingMessageId === msg.id ? html`
                            <input type="text" .value="${this.editingMessageContent}"
                              @input="${(e) => this.editingMessageContent = e.target.value}" />
                            <button @click="${() => this.saveEditedMessage(msg.id)}">Lưu</button>
                            <button @click="${() => this.cancelEditing()}">Hủy</button>
                          ` : (msg.is_recalled ? html`<em>Tin nhắn đã được thu hồi</em>`
                            : msg.is_edited ? html`
                                <span class="edited-text" @click="${() => this.toggleEditHistory(msg.id)}">
                                  ${msg.content} <span class="edited-label">(Đã chỉnh sửa)</span>
                                </span>
                                ${this.showEditHistoryId === msg.id ? html`
                                  <div class="edit-history">
                                    ${this.editHistory[msg.id]?.map(edit => html`
                                      <div class="edit-item">${edit.previous_content}</div>
                                    `) ?? ''}
                                  </div>
                                ` : ''}
                              ` : msg.content)}
                        </div>

                        ${msg.reaction ? html`<div class="reaction">${msg.reaction}</div>` : ""}  

                        <!-- Nút thả emoji ẩn, hiện khi hover -->
                        ${!msg.is_recalled ? html`
                          <div class="emoji-picker">
                            ${["😍", "😂", "👍", "❤️"].map((emoji) => html`
                              <button @click="${() => this.reactToMessage(msg.id, emoji)}">
                                ${emoji}
                              </button>
                            `)}
                          </div>
                        ` : ""}
                      </div>
                    `)}
                    `}
                </div>

                <form @submit="${this.sendMessage}" class="message-input"
                  ?hidden="${this.selectedGroup?.conversation.only_admin_can_message &&
        this.userId !== this.selectedGroup?.admin_user_id}">
                  <input id="message-input" type="text" placeholder="Nhập tin nhắn..." />
                  <button type="submit">Gửi</button>
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
              ? html`<button @click="${() => this.recallMessage(this.selectedMessageId)}">Thu hồi tin nhắn</button>
                    <button @click="${() => this.startEditingMessage(this.selectedMessageId)}">Chỉnh sửa tin nhắn</button>`
              : ""}
            <button @click="${() => this.deleteMessage(this.selectedMessageId)}">Xóa tin nhắn</button>
            `;
        })()}
      </div>
        ` : ''}

      <!-- Modal tạo nhóm -->
      ${this.showCreateGroupModal ? html`
        <div class="modal">
          <h3>Tạo nhóm mới</h3>
          <form @submit="${this.createGroup}">
            <input type="text" id="group-name" placeholder="Tên nhóm" required />
            <label for="friends-select">Chọn bạn bè:</label>
            <select id="friends-select" multiple size="5">
              ${this.friends.map(friend => html`
                <option value="${friend.id}">
                  ${friend.email || friend.id}
                </option>
              `)}
            </select>
            <div>
              <button type="submit">Tạo nhóm</button>
              <button type="button" @click="${this.closeCreateGroupModal}">Hủy</button>
            </div>
          </form>
        </div>
      ` : ''}
      
      <!-- Modal chỉnh sửa nhóm -->
      ${this.showEditGroupModal ? html`
        <div class="modal-overlay">
          <div class="modal">
            <h3>Chỉnh sửa nhóm</h3>
            <form @submit="${this.saveGroupEdit}">
            <input type="hidden" .value="${this.selectedGroup?.conversation.id}" />
              
          
              <!-- Nhập tên nhóm -->
              <input type="text"
               .value="${this.selectedGroupName}"
               @input="${(e) => this.selectedGroupName = e.target.value}"
               placeholder="Tên nhóm"
               ?disabled="${this.userId !== this.selectedGroup?.admin_user_id}"
               required />

              <!-- Chỉ admin có thể nhắn tin -->
              <label>
                <input type="checkbox"
                      .checked="${this.onlyAdminCanMessage}"
                      @change="${(e) => this.onlyAdminCanMessage = e.target.checked}"
                      ?disabled="${this.userId !== this.selectedGroup?.admin_user_id}" />
                Chỉ admin có thể nhắn tin
              </label>

              <!-- Chọn chế độ nhóm -->
              <label for="visibility">Chế độ nhóm:</label>
              <select id="visibility"
                      .value="${this.visibility}"
                      @change="${(e) => this.visibility = e.target.value}"
                      ?disabled="${this.userId !== this.selectedGroup?.admin_user_id}">
                <option value="public">Công khai</option>
                <option value="private">Riêng tư</option>
              </select>

      
              ${!(this.visibility === "private" && this.userId !== this.selectedGroup?.admin_user_id)
          ? html`<button type="button" @click="${this.openAddMemberModal}">Thêm thành viên</button>`
          : ''}

              <!-- Nút mở modal danh sách thành viên -->
              <button type="button" @click="${this.openMemberListModal}">Xem thành viên</button>

              <!-- Nút rời nhóm -->
              <button type="button" class="leave-button" @click="${this.leaveGroup}">Rời nhóm</button>

              <!-- Nút xóa nhóm, chỉ hiện nếu là admin -->
              ${this.userId === this.selectedGroup?.admin_user_id ? html`
                <button type="button" class="delete-button" @click="${this.deleteGroup}">Xóa nhóm</button>
              ` : ''}
              <div>
                <button type="submit">Lưu</button>
                <button type="button" @click="${this.closeEditGroupModal}">Hủy</button>
              </div>
            </form>
          </div>
        </div>
      ` : ''}

        <!-- Modal thêm thành viên -->
        ${this.showAddMemberModal ? html`
          <div class="modal-overlay">
            <div class="modal">
              <h3>Thêm thành viên vào nhóm</h3>
              
              <div class="friends-list">
                ${this.friends?.length ? this.friends.map(friend => html`
                  <label>
                    <input type="checkbox"
                          .value="${friend.id}"
                          @change="${(e) => this.toggleSelectedFriend(e, friend.id)}" />
                    ${friend.email}
                  </label>
                `) : html`<p>Không có bạn bè nào để thêm.</p>`}
              </div>

              <button type="button" @click="${this.addSelectedFriendsToGroup}">Thêm</button>
              <button type="button" @click="${this.closeAddMemberModal}">Đóng</button>
            </div>
          </div>
        ` : ''}
              
        <!-- Modal danh sách thành viên -->
        ${this.showMemberListModal ? html`
          <div class="modal-overlay">
            <div class="modal">
              <h3>Danh sách thành viên</h3>

              <ul>
                ${this.selectedGroup.members?.length ? this.selectedGroup.members.map(member => html`
                  <li>
                    ${member.email} 
                    ${this.userId === this.selectedGroup?.admin_user_id ?
              html`<button @click="${() => this.removeMember(member.id)}">Xóa</button>`
              : ''}                 
                    </li>
                `) : html`<p>Nhóm chưa có thành viên.</p>`}
              </ul>

              <button type="button" @click="${this.closeMemberListModal}">Đóng</button>
            </div>
          </div>
        ` : ''}

      `;
  }
}

customElements.define("chat-room", ChatRoom);
