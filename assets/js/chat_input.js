import { LitElement, html, css } from 'lit';
import { Socket } from 'phoenix';
import { Presence } from "phoenix";

class ChatInput extends LitElement {
  static properties = {
    conversationId: { type: String },
    messages: { type: Array },
    conversation: { type: Object },
    currentUser: { type: Object },
    friend: { type: Object },
    friendStatus: { type: String },
    showSearch: { type: Boolean },
    searchQuery: { type: String },
    socket: { type: Object },
    channel: { type: Object },
    showEmojiPicker: { type: Number },
    selectedMessageId: { type: Number },
    showDropdown: { type: Number },
    //Tin nhắn ghim
    pinnedMessages: { type: Array },
    //Tin nhắn chỉnh sửa
    editContent: { type: String },
    //Modal để chỉnh sửa tin nhắn
    showEditModal: { type: Number },
    //Lịch sử cuộc gọi
    callHistory: { type: Array },
    // Các thuộc tính WebRTC
    callState: { type: String },          // Trạng thái cuộc gọi: 'idle', 'calling', 'awaiting_answer', 'in_call'
    isCaller: { type: Boolean },          // Xác định xem người dùng là người gọi hay không
    localStream: { type: Object },        // Stream video/audio cục bộ
    remoteStream: { type: Object },       // Stream video/audio từ đối phương
    peerConnection: { type: Object },     // Đối tượng RTCPeerConnection
    remoteOffer: { type: String },        // Offer từ đối phương
    pendingCandidates: { type: Array },   // Danh sách ICE candidates đang chờ xử lý
    //Chuyển tiếp tin nhắn
    showForwardModal: { type: Boolean },
    forwardMessage: { type: Object },
    friends: { type: Array },
    replyingTo: { type: Number }, // ID của tin nhắn đưuọc trả lời
    typingUsers: { type: Array }, // Danh sách người dùng đang gõ
    firstUnreadMessageId: { type: Number }, // ID của tin nhắn chưa đọc đầu tiên
    initialFirstUnreadMessageId: { type: Number }
  };

  constructor() {
    super();
    this.conversationId = '';
    this.messages = [];
    this.conversation = {};
    this.currentUser = {};
    this.friend = {};
    this.friendStatus = 'offline';
    this.showSearch = false;
    this.searchQuery = '';
    this.socket = null;
    this.channel = null;
    this.showEmojiPicker = null;
    this.selectedMessageId = null;
    //Dropdown các lựa chọn
    this.showDropdown = null;
    //Ghim tin nhắn
    this.pinnedMessages = [];
    //Lịch sử cuộc gọi
    this.callHistory = [];
    // Khởi tạo các thuộc tính WebRTC
    this.callState = 'idle';
    this.isCaller = false;
    this.localStream = null;
    this.remoteStream = null;
    this.peerConnection = null;
    this.remoteOffer = null;
    this.pendingCandidates = [];
    //Chuyển tiếp tin nhắn
    this.showForwardModal = false;
    this.forwardMessage = null;
    this.friends = [];
    this.replyingTo = null;
    // Xử lí theo dõi gõ tin nhắn
    this.typingUsers = [];
    this.isTyping = false; // Biến để theo dõi trạng thái gõ
    this.callTimeout = null; // Biến để đặt thời gian gọi
    this.firstUnreadMessageId = null;
    this.initialFirstUnreadMessageId = null;
  }

  async connectedCallback() {
    super.connectedCallback();
    this.conversationId = this.getAttribute('conversation-id') || '';
    if (this.conversationId) {
      const authData = await this.getUserIdAndToken();
      if (authData) {
        this.token = authData.token;
        this.currentUser = { id: authData.userId };
        await this.loadMessages();
        this.connectWebSocket();
      } else {
        console.error('❌ Không thể kết nối WebSocket do thiếu token');
      }
    }
  }

  async getUserIdAndToken() {
    try {
      const res = await fetch('/api/user_token', { credentials: 'include' });
      const data = await res.json();
      if (data.token) {
        console.log('✅ Đã lấy token và user_id:', data.token, data.user_id);
        return { token: data.token, userId: data.user_id };
      } else {
        console.error('❌ Không thể lấy token!', data.error);
        return null;
      }
    } catch (error) {
      console.error('❌ Lỗi lấy token:', error);
      return null;
    }
  }

  createPeerConnection() {
    const configuration = {
      iceServers: [{ urls: "stun:stun.l.google.com:19302" }]
    };
    this.peerConnection = new RTCPeerConnection(configuration);

    this.peerConnection.oniceconnectionstatechange = () => {
      console.log("🔄 ICE Connection State:", this.peerConnection.iceConnectionState);
      if (this.peerConnection.iceConnectionState === "connected") {
        console.log("🎉 Kết nối ICE thành công!");
      }
    };

    this.peerConnection.onicecandidate = (event) => {
      if (event.candidate) {
        console.log("✅ ICE candidate được tạo:", event.candidate);
        this.channel.push("candidate", { candidate: event.candidate.toJSON() });
      } else {
        console.log("⚠️ ICE gathering kết thúc (không có candidate)");
      }
    };

    this.peerConnection.ontrack = (event) => {
      console.log("📡 Nhận được track từ peer:", event.track.kind);
      const remoteVideo = this.shadowRoot.getElementById('remote-video');
      if (remoteVideo) {
        if (!remoteVideo.srcObject) {
          remoteVideo.srcObject = new MediaStream();
        }
        remoteVideo.srcObject.addTrack(event.track);
      }
    };
  }

  async loadMessages() {
    try {
      const response = await fetch(`/api/messages/${this.conversationId}`, { credentials: 'include' });
      if (!response.ok) throw new Error('Lỗi khi tải tin nhắn');
      const data = await response.json();
      this.messages = data.messages || [];
      console.log('Message statuses ban đầu:', JSON.stringify(this.messages.map(m => m.message_statuses)));
      this.conversation = data.conversation || {};
      this.currentUser = { ...this.currentUser, ...data.current_user };
      this.friend = data.friend || { email: 'Người dùng không xác định' };
      this.friendStatus = data.friend_status || 'offline';
      this.pinnedMessages = data.pinned_messages || [];
      this.callHistory = data.call_history || []; // Tải call_history từ API

      // Tính toán tin nhắn chưa đọc đầu tiên dựa trên trạng thái ban đầu
      this.initialFirstUnreadMessageId = this.findFirstUnreadMessage();
      this.firstUnreadMessageId = this.initialFirstUnreadMessageId; // Ban đầu giống nhau
      console.log('Initial first unread message ID:', this.initialFirstUnreadMessageId);

      console.log('Friend data:', this.friend);
      console.log('pinnedMessages data:', this.pinnedMessages);
      console.log('CallHistory data:', this.callHistory);
    } catch (error) {
      console.error('Lỗi tải tin nhắn:', error);
    }
  }

  // Hàm tìm tin nhắn chưa đọc đầu tiên
  findFirstUnreadMessage() {
    console.log('🔍 Finding first unread message...');
    console.log('Current user ID:', this.currentUser.id);
    console.log('Messages:', JSON.stringify(this.messages, null, 2));

    for (const msg of this.messages) {
      console.log(`Checking message ${msg.id} from user ${msg.user_id}`);

      if (msg.user_id !== this.currentUser.id) {
        console.log("→ Message is from another user");

        // Kiểm tra message_statuses
        if (msg.message_statuses && msg.message_statuses.length > 0) {
          console.log(`Found ${msg.message_statuses.length} statuses for message ${msg.id}`);

          // Log tất cả các message_statuses để kiểm tra dữ liệu
          msg.message_statuses.forEach((status, index) => {
            console.log(`Status ${index + 1}:`, status);
          });

          // Tìm status cho user hiện tại
          const status = msg.message_statuses.find(s => s.user_id === this.currentUser.id);
          console.log(`Status for current user in message ${msg.id}:`, status);

          // Nếu có status và chưa được xem
          if (status && status.status !== 'seen') {
            console.log(`Found unread message ${msg.id} with status ${status.status}`);
            return msg.id;
          } else {
            console.log(`Status is either not found or already seen for message ${msg.id}`);
          }
        } else {
          console.log(`No message statuses found for message ${msg.id}`);
        }
      }
    }

    console.log('No unread messages found');
    return null;
  }

  async fetchFriends() {
    try {
      const response = await fetch('/api/list_friends', {
        credentials: 'include',
        headers: { 'Authorization': `Bearer ${this.token}` }
      });
      if (!response.ok) throw new Error('Lỗi khi lấy danh sách bạn bè');
      const data = await response.json();
      return data.friends || [];
    } catch (error) {
      console.error('Lỗi khi lấy danh sách bạn bè:', error);
      return [];
    }
  }

  async handleForwardMessage(e) {
    e.preventDefault();
    const formData = new FormData(e.target);
    const recipientId = formData.get('recipient_id');
    const messageId = formData.get('message_id');

    if (!recipientId || !messageId) {
      console.error('Thiếu recipient_id hoặc message_id');
      this.notification = 'Vui lòng chọn người nhận';
      return;
    }

    const payload = {
      message_id: parseInt(messageId, 10),
      recipient_id: parseInt(recipientId, 10)
    };
    console.log('Dữ liệu gửi đi:', payload); // Debug dữ liệu gửi

    try {
      const response = await fetch('/api/forward_message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.token}`
        },
        credentials: 'include',
        body: JSON.stringify(payload)
      });

      if (!response.ok) {
        const text = await response.text();
        console.error('Phản hồi không thành công từ server:', response.status, text);
        this.notification = `Lỗi từ server: ${response.status}`;
        return;
      }

      const data = await response.json();
      if (data.success) {
        this.showForwardModal = false;
        this.notification = 'Đã chuyển tiếp tin nhắn thành công';
        setTimeout(() => {
          this.notification = '';
          this.requestUpdate();
        }, 3000);
        this.messages = [...this.messages, data.message];
        this.requestUpdate();
      } else {
        console.error('Lỗi từ server:', data.error);
        this.notification = `Lỗi khi chuyển tiếp: ${data.error}`;
      }
    } catch (error) {
      console.error('Lỗi khi gửi yêu cầu chuyển tiếp:', error);
      this.notification = 'Lỗi khi chuyển tiếp tin nhắn';
    }
  }

  connectWebSocket() {
    if (!this.token || !this.conversationId) {
      console.error('❌ Token or conversation_id is missing');
      return;
    }
    console.log('🔗 Connecting WebSocket with:', { token: this.token, conversationId: this.conversationId });
    this.socket = new Socket('/socket', { params: { token: this.token, conversation_id: this.conversationId } });
    this.socket.connect();

    const channelName = `conversation:${this.conversationId}`;
    this.channel = this.socket.channel(channelName, {});

    // 🛠 Log tất cả sự kiện presence nhận được
    this.channel.on("presence_state", state => {
      console.log("🔥 presence_state received:", state);
    });

    this.channel.on("presence_diff", diff => {
      console.log("🔄 presence_diff received:", diff);
    });
    // Trong connectWebSocket()
    this.channel.join()
      .receive('ok', resp => {
        console.log('✅ Joined conversation channel successfully', resp);

        // Kiểm tra điều kiện: friend đang hoạt động và tin nhắn cuối cùng không phải của friend
        const friendIsActive = this.friendStatus === 'online' || this.friendStatus === 'Đang hoạt động';
        const lastMsg = this.messages.length ? this.messages[this.messages.length - 1] : null;

        if (friendIsActive && lastMsg && lastMsg.user_id !== this.currentUser.id) {
          // Nếu thỏa điều kiện thì gửi event mark_messages_as_seen
          this.channel.push('mark_messages_as_seen', {
            conversation_id: this.conversationId,
            user_id: this.friend.id
          })
            .receive('ok', resp => console.log('✅ Marked messages as seen', resp))
            .receive('error', err => console.error('❌ Error marking messages as seen', err));
        } else {
          console.log('ℹ️ Không gửi event mark_messages_as_seen vì điều kiện không thỏa');
        }

        // Khởi tạo Presence
        this.presence = new Presence(this.channel);
        console.log("👀 Presence object initialized:", this.presence);

        this.presence.onSync(() => {
          console.log('🔔 onSync callback triggered');
          this.updateFriendStatus(this.presence.state);
        });
      })
      .receive('error', resp => {
        console.error('❌ Unable to join channel', resp);
      });


    console.log('📤 Dữ liệu gửi đi:', JSON.stringify({
      conversation_id: this.conversationId,
      user_id: this.currentUser.id
    }, null, 2));

    this.channel.on('new_message', payload => {
      console.log('💬 New message received:', payload);
      this.messages = [...this.messages, payload.message];
      this.firstUnreadMessageId = this.findFirstUnreadMessage(); // Cập nhật lại khi có tin nhắn mới
      this.requestUpdate();
    });

    // Trong messages_seen handler
    this.channel.on('messages_seen', payload => {
      console.log('👀 Messages seen event received:', payload);

      if (this.messages.length === 0) {
        console.warn('⚠️ Không có tin nhắn nào để cập nhật.');
        return;
      }

      console.log('🔍 Trước khi cập nhật:', JSON.stringify(this.messages[this.messages.length - 1]?.message_statuses));

      this.messages = this.messages.map(msg => {
        const newStatuses = msg.message_statuses.map(status => {
          if (status.status !== 'seen') {
            console.log(`📝 Cập nhật status của user ${status.user_id} từ "${status.status}" ➝ "seen"`);
            return { ...status, status: 'seen' };
          }
          return status;
        });

        return { ...msg, message_statuses: newStatuses };
      });

      console.log('🆕 Sau khi cập nhật:', JSON.stringify(this.messages[this.messages.length - 1]?.message_statuses));

      this.messages = [...this.messages]; // Deep clone để trigger render
      // Chỉ cập nhật firstUnreadMessageId, không động đến initialFirstUnreadMessageId
      this.firstUnreadMessageId = this.findFirstUnreadMessage();
      this.requestUpdate();
    });



    this.channel.on('new_reaction', payload => {
      console.log('🎉 New reaction received:', payload);
      this.messages = this.messages.map(msg => {
        if (msg.id === payload.message_id) {
          return { ...msg, reactions: payload.reactions };
        }
        return msg;
      });
      this.requestUpdate();
    });

    this.channel.on('message_recalled', payload => {
      console.log('Tin nhắn đã thu hồi:', payload);
      this.messages = this.messages.map(msg =>
        msg.id === payload.id ? { ...msg, is_recalled: true, content: "Tin nhắn đã được thu hồi", reactions: [] } : msg
      );
      this.requestUpdate();
    });

    // Trong connectWebSocket()
    this.channel.on('message_pinned', async payload => {
      console.log("📌 Tin nhắn được ghim:", payload.message);
      // Load tin nhắn trước khi cập nhật giao diện
      this.loadMessages();
      // Yêu cầu cập nhật giao diện sau khi load xong
      this.requestUpdate();
    });


    this.channel.on('message_unpinned', payload => {
      this.pinnedMessages = this.pinnedMessages.filter(m => m.id !== payload.message_id);
      this.requestUpdate();
    });

    this.channel.on('message_edited', payload => {
      console.log('✏️ Tin nhắn đã chỉnh sửa:', payload);
      this.messages = this.messages.map(msg =>
        msg.id === payload.id ? { ...msg, content: payload.content, is_edited: true } : msg
      );

      // Cập nhật pinned messages nếu cần
      this.pinnedMessages = this.pinnedMessages.map(msg =>
        msg.id === payload.id ? { ...msg, content: payload.content, is_edited: true } : msg
      );

      this.requestUpdate();
    });

    this.channel.on('message_deleted', payload => {
      console.log('🗑 Tin nhắn đã xóa:', payload);
      this.messages = this.messages.map(msg =>
        msg.id === payload.message_id ? { ...msg, is_deleted: true } : msg
      );
      this.pinnedMessages = this.pinnedMessages.filter(m => m.id !== payload.message_id);
      this.requestUpdate();
    });

    // Thêm các sự kiện WebRTC
    this.channel.on('offer', payload => {
      console.log("📥 Nhận offer từ server:", payload);
      if (!this.isCaller) {
        this.handleOffer(payload);
      } else {
        console.log("❌ Bỏ qua offer vì đây là caller");
      }
    });

    this.channel.on('answer', payload => {
      console.log("📥 Nhận answer từ server:", payload);
      if (this.isCaller) {
        this.handleAnswer(payload);
      }
    });

    this.channel.on('candidate', payload => {
      this.handleCandidate(payload.candidate);
    });

    this.channel.on('call_rejected', () => {
      clearTimeout(this.callTimeout); // Hủy timeout khi nhận call_rejected
      this.endCall();
    });

    // Thêm sự kiện end_call
    this.channel.on('end_call', () => {
      console.log("callState trước khi kiểm tra: ", this.callState);
      if (this.callState !== 'idle') {
        console.log("📥 Nhận tín hiệu end_call từ server");
        this.endCall();
      } else {
        console.log("🚨 Cuộc gọi đã kết thúc trước đó.");
      }
    });


    this.channel.on('new_call_history', payload => {
      this.messages = [...this.messages, payload.call_history].sort((a, b) => new Date(a.inserted_at) - new Date(b.inserted_at));
      this.requestUpdate();
    });

    // Trong connectWebSocket(), thêm sự kiện mới
    this.channel.on('user_typing', payload => {
      console.log('📝 Received user_typing:', payload);
      const userId = payload.user_id;
      const isTyping = payload.typing;
      this.typingUsers = isTyping
        ? [...this.typingUsers.filter(id => id !== userId), userId]
        : this.typingUsers.filter(id => id !== userId);
      console.log('🔍 typingUsers:', this.typingUsers);
      this.requestUpdate();
    });

    this.activeInterval = setInterval(() => {
      this.channel.push('update_active', {})
        .receive('ok', () => console.log('✅ Updated active status'))
        .receive('error', err => console.error('❌ Error updating active status:', err));
    }, 30000);

    this.socket.onError(() => console.error('❌ Socket error'));
    this.socket.onClose(() => {
      clearInterval(this.activeInterval);
      console.log('❌ Socket closed');
    });
  }

  updateFriendStatus(presenceState) {
    const expectedFriendId = this.friend?.id?.toString();
    if (!expectedFriendId) return;

    const presenceKeys = Object.keys(presenceState);
    console.log('🔎 Presence keys:', presenceKeys);
    console.log('🔎 Expected friend id:', expectedFriendId);

    const isOnline = presenceKeys.includes(expectedFriendId);
    const wasOnline = this.friendStatus === "Đang hoạt động";

    if (isOnline) {
      this.friendStatus = "Đang hoạt động";
    } else {
      // Nếu API đã có trạng thái "Hoạt động X phút trước", dùng luôn
      this.friendStatus = this.friendStatus || "Offline";

    }
    console.log('🔍 FriendStatus:', this.friendStatus);
    console.log('🔍 updateFriendStatus:', { isOnline, wasOnline, friendStatus: this.friendStatus });

    this.requestUpdate();
  }




  // Helper: Kiểm tra tin nhắn cuối cùng
  isLastMessage(msg) {
    return this.messages.length > 0 && msg.id === this.messages[this.messages.length - 1].id;
  }

  // Helper: Render trạng thái tin nhắn của currentUser
  renderMessageStatus(msg) {
    if (!msg.message_statuses) return '';

    const friendStatusObj = msg.message_statuses.find(s => s.user_id === this.friend.id);
    const currentUserStatusObj = msg.message_statuses.find(s => s.user_id === this.currentUser.id);

    if (friendStatusObj?.status === 'seen') {
      console.log(`🔍 Tin nhắn id ${msg.id}: trạng thái là "seen" (friend đã xem)`);
      return html`👀 đã xem`;
    } else if (currentUserStatusObj) {
      const status = currentUserStatusObj.status;
      console.log(`🔍 Tin nhắn id ${msg.id}: trạng thái của currentUser là "${status}"`);
      if (status === 'sent') return html`📤 đã gửi`;
      if (status === 'delivered') return html`📬 đã nhận`;
      if (status === 'seen') return html`👀 đã xem`;
    }
    return '';
  }

  async handleSubmit(e) {
    e.preventDefault();
    const contentInput = this.shadowRoot.getElementById('content');
    const content = contentInput.value.trim();
    if (!content) return;
    console.log('📩 Đã gửi tin nhắn:', content);

    const payload = { content };
    if (this.replyingTo) {
      payload.reply_to_id = this.replyingTo;
    }
    console.log("Payload gửi đi:", payload);
    this.channel.push('new_message', payload)
      .receive('ok', response => {
        console.log(`✅ Tin nhắn "${content}" đã được gửi thành công!`, response);
        contentInput.value = '';
        this.replyingTo = null; // Reset after sending
        this.isTyping = false; // Reset trạng thái gõ
        this.channel.push("typing_stop", {}) // Gửi typing_stop khi gửi tin nhắn
          .receive("ok", () => console.log("Typing stop event sent after submit"))
          .receive("error", err => console.error("Error sending typing stop:", err));
        console.log(`👀 Trạng thái bạn bè: ${this.friendStatus}`);
        if (this.friendStatus === 'Đang hoạt động') {
          console.log('📡 Gửi sự kiện mark_messages_as_seen...');
          this.channel.push('mark_messages_as_seen', {
            conversation_id: this.conversationId,
            user_id: this.currentUser.id
          })
            .receive('ok', resp => {
              console.log('✅ Marked messages as seen', resp);
              this.firstUnreadMessageId = null; // Xóa đường gạch ngang khi đã đọc hết
            })
            .receive('error', err => console.error('❌ Lỗi khi đánh dấu tin nhắn đã xem', err));
        } else {
          console.warn('⚠️ Bạn bè không hoạt động, không gửi sự kiện mark_messages_as_seen.');
        }
      })
      .receive('error', err => {
        console.error('❌ Lỗi khi gửi tin nhắn:', err);
      })
      .receive('timeout', () => {
        console.error('⏳ Timeout khi gửi tin nhắn');
      });
  }

  // Xử lý reaction
  async handleReactToMessage(messageId, emoji) {
    this.channel.push("react_to_message", {
      message_id: messageId,
      emoji: emoji
    })
      .receive("ok", () => console.log("Reaction added"))
      .receive("error", err => console.error("Error adding reaction:", err));

    this.showEmojiPicker = null;
  }
  // Cách 1: Sửa phương thức thành arrow function
  handleToggleEmojiPicker = (messageId) => {
    this.showEmojiPicker = this.showEmojiPicker === messageId ? null : messageId;
    this.selectedMessageId = messageId;
    this.requestUpdate();
  }

  handleSearch(e) {
    e.preventDefault();
    console.log("Form submitted!");

    // Kiểm tra xem e.target có tồn tại không
    if (!e.target) {
      console.error("Event target is undefined!");
      return;
    }

    // Kiểm tra xem input có tồn tại không
    const searchInput = e.target.search_query;
    if (!searchInput) {
      console.error("Search input not found!");
      return;
    }

    // Gán giá trị tìm kiếm và log ra để kiểm tra
    this.searchQuery = searchInput.value;
    console.log("Search Query:", this.searchQuery);
  }

  // Xử lý hiển thị dropdown
  handleShowDropdown = (messageId) => {
    if (this.showDropdown === messageId) {
      // Nếu dropdown đang hiển thị cho messageId này, ẩn nó đi
      this.showDropdown = null;
    } else {
      // Nếu không, hiển thị dropdown cho messageId mới
      this.showDropdown = messageId;
    }
    this.requestUpdate();
  };



  // Xử lý thu hồi tin nhắn
  handleRecallMessage = async (messageId) => {
    try {
      await this.channel.push("recall_message", { message_id: messageId });
      this.messages = this.messages.map(msg =>
        msg.id === messageId ? { ...msg, is_recalled: true, content: "Tin nhắn đã được thu hồi", reactions: [] } : msg
      );
      // Kiểm tra xem tin nhắn có trong pinnedMessages không
      const isPinned = this.pinnedMessages.some(pinned => pinned.id === messageId);
      if (isPinned) {
        // Gửi sự kiện unpin tới server
        this.channel.push("unpin_message", { message_id: messageId })
          .receive("ok", () => console.log("Đã gỡ ghim tin nhắn bị thu hồi"))
          .receive("error", err => console.error("Lỗi khi gỡ ghim:", err));
        // Cập nhật local pinnedMessages
        this.pinnedMessages = this.pinnedMessages.filter(pinned => pinned.id !== messageId);
      }
      this.requestUpdate();
    } catch (err) {
      console.error("Lỗi thu hồi tin nhắn:", err);
    }
  }

  handlePinMessage = async (messageId) => {
    this.channel.push("pin_message", { message_id: messageId })
      .receive("ok", () => console.log("Đã ghim tin nhắn"))
      .receive("error", err => console.error("Lỗi khi ghim:", err));
  }

  handleUnpinMessage = async (messageId) => {
    this.channel.push("unpin_message", { message_id: messageId })
      .receive("ok", () => console.log("Đã gỡ ghim"))
      .receive("error", err => console.error("Lỗi khi gỡ ghim:", err));
  }

  //Hàm chỉnh sửa tin nhắn
  async handleEditMessage(messageId, newContent) {
    try {
      const response = await this.channel.push("edit_message", {
        message_id: messageId,
        content: newContent
      });
      if (response.status === "ok") {
        console.log("✅ Tin nhắn đã được chỉnh sửa");
        this.messages = this.messages.map(msg =>
          msg.id === messageId ? { ...msg, content: newContent, is_edited: true } : msg
        );
        this.requestUpdate();
      }
    } catch (err) {
      console.error("❌ Lỗi khi chỉnh sửa:", err);
    }
  }

  // Thêm vào class ChatInput
  toggleEditModal(messageId) {
    this.showEditModal = this.showEditModal === messageId ? null : messageId;
    this.requestUpdate();
  }

  async handleEditSubmit(e, messageId) {
    e.preventDefault();
    const newContent = this.editContent;
    const maxLength = 2000;

    if (!newContent || !newContent.trim()) {
      console.error("❌ Nội dung không được để trống");
      return;
    }

    if (newContent.length > maxLength) {
      console.error(`❌ Nội dung vượt quá ${maxLength} ký tự (${newContent.length}/${maxLength})`);
      alert(`Nội dung không được vượt quá ${maxLength} ký tự! Hiện tại: ${newContent.length} ký tự.`);
      return;
    }

    await this.handleEditMessage(messageId, newContent);
    this.toggleEditModal(null);
  }

  //Hàm xóa tin nhắn
  async handleDeleteMessage(messageId) {
    try {
      await this.channel.push("delete_message", {
        message_id: messageId
      });

      // Cập nhật local state
      this.messages = this.messages.map(msg =>
        msg.id === messageId ? { ...msg, is_deleted: true } : msg
      );

      // Cập nhật pinned messages
      this.pinnedMessages = this.pinnedMessages.filter(m => m.id !== messageId);

      this.requestUpdate();
    } catch (err) {
      console.error("Lỗi khi xóa tin nhắn:", err);
    }
  }

  async startCall() {
    // Kiểm tra và đóng peerConnection cũ nếu tồn tại
    if (this.peerConnection) {
      console.warn("⚠️ PeerConnection cũ vẫn tồn tại, đóng nó trước");
      this.peerConnection.close();
      this.peerConnection = null;
    }

    this.isCaller = true;
    this.callState = 'calling';
    console.log("✅ startCall() chạy, thời gian bắt đầu:", this.callStartedAt);
    this.requestUpdate();

    try {
      this.localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      const localVideo = this.shadowRoot.getElementById('local-video');
      if (localVideo) localVideo.srcObject = this.localStream;

      this.createPeerConnection();
      this.localStream.getTracks().forEach(track => this.peerConnection.addTrack(track, this.localStream));

      const offer = await this.peerConnection.createOffer();
      await this.peerConnection.setLocalDescription(offer);

      const offerPayload = { sdp: this.peerConnection.localDescription.sdp, type: this.peerConnection.localDescription.type };
      console.log("📤 Gửi offer:", offerPayload);
      this.channel.push("offer", offerPayload)
        .receive("ok", () => console.log("✅ Offer gửi thành công"))
        .receive("error", err => console.error("❌ Lỗi gửi offer:", err));
      // Thêm timeout 30 giây
      this.callTimeout = setTimeout(() => {
        console.log("⏳ 30 giây trôi qua, không có phản hồi, tự động kết thúc cuộc gọi");
        this.endCall();
      }, 30000); // 30 giây
    } catch (err) {
      console.error("Lỗi khi bắt đầu cuộc gọi:", err);
    }
  }

  async handleOffer(offer) {
    console.log("📥 Nhận offer:", offer);
    this.remoteOffer = offer.sdp;
    this.callState = 'awaiting_answer';
    this.requestUpdate();
  }

  async acceptCall() {
    try {
      if (this.peerConnection) {
        console.warn("⚠️ PeerConnection cũ vẫn tồn tại, đóng nó trước");
        this.peerConnection.close();
        this.peerConnection = null;
      }
      this.callStartedAt = new Date().toISOString(); // Lưu thời gian bắt đầu
      console.log("🕒 Thời gian bắt đầu cuộc gọi:", this.callStartedAt);
      this.localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      const localVideo = this.shadowRoot.getElementById('local-video');
      if (localVideo) localVideo.srcObject = this.localStream;

      this.createPeerConnection();
      this.localStream.getTracks().forEach(track => this.peerConnection.addTrack(track, this.localStream));

      const remoteOfferDesc = new RTCSessionDescription({ type: "offer", sdp: this.remoteOffer });
      await this.peerConnection.setRemoteDescription(remoteOfferDesc);
      console.log("✅ Đặt remote description với offer:", this.remoteOffer);

      const answer = await this.peerConnection.createAnswer();
      await this.peerConnection.setLocalDescription(answer);

      const answerPayload = { sdp: this.peerConnection.localDescription.sdp, type: this.peerConnection.localDescription.type };
      console.log("📤 Gửi answer:", answerPayload);
      this.channel.push("answer", answerPayload)
        .receive("ok", () => console.log("✅ Answer gửi thành công"))
        .receive("error", err => console.error("❌ Lỗi gửi answer:", err));

      this.callState = 'in_call';
      this.requestUpdate();
    } catch (err) {
      console.error("Lỗi khi chấp nhận cuộc gọi:", err);
    }
  }

  async handleAnswer(answer) {
    if (this.callState === 'calling') {
      clearTimeout(this.callTimeout); // Hủy timeout khi nhận answer
      const answerDesc = new RTCSessionDescription(answer);
      await this.peerConnection.setRemoteDescription(answerDesc);

      // Áp dụng các candidate đang chờ
      while (this.pendingCandidates.length > 0) {
        const candidate = this.pendingCandidates.shift();
        await this.peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
        console.log("✅ Đã áp dụng candidate từ pending:", candidate);
      }
      this.callStartedAt = new Date().toISOString();
      this.callState = 'in_call';
      this.requestUpdate();
    }
  }

  endCall() {
    console.log("📞 Đang thực hiện endCall với callState: ", this.callState);

    if (this.peerConnection) {
      this.peerConnection.close();
      this.peerConnection = null;
    }

    if (this.localStream) {
      this.localStream.getTracks().forEach(track => track.stop());
      this.localStream = null;
    }

    const localVideo = this.shadowRoot.getElementById('local-video');
    const remoteVideo = this.shadowRoot.getElementById('remote-video');
    if (localVideo) localVideo.srcObject = null;
    if (remoteVideo) remoteVideo.srcObject = null;

    if (this.channel && this.callState !== 'idle') {
      let status, started_at, ended_at;
      if (this.callState === 'in_call') {
        status = 'answered';
        started_at = this.callStartedAt;
        ended_at = new Date().toISOString();
      } else if (this.callState === 'calling') {
        status = 'canceled';
        started_at = null;
        ended_at = new Date().toISOString();
      }

      const payload = { status, started_at, ended_at };
      console.log("📤 Gửi tín hiệu end_call:", payload);

      // Chỉ caller gửi tín hiệu lưu trữ
      if (this.isCaller) {
        this.channel.push("end_call", payload)
          .receive("ok", () => console.log("✅ Tín hiệu end_call gửi thành công"))
          .receive("error", err => console.error("❌ Lỗi gửi end_call:", err));
      } else {
        this.channel.push("end_call", {}); // Receiver chỉ thông báo kết thúc
      }
    }

    clearTimeout(this.callTimeout); // Hủy timeout khi kết thúc cuộc gọi
    this.callState = 'idle';
    this.isCaller = false;
    this.remoteOffer = null;
    this.pendingCandidates = [];
    this.remoteStream = null;
    this.callStartedAt = null;
    this.callTimeout = null; // Reset timeout
    this.requestUpdate();
  }


  async handleCandidate(candidate) {
    console.log("📥 Nhận candidate từ server:", candidate);
    if (!this.peerConnection || !this.peerConnection.remoteDescription) {
      this.pendingCandidates.push(candidate);
      console.log("⏳ Candidate được lưu vào pending:", this.pendingCandidates);
      return;
    }
    try {
      await this.peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
      console.log("✅ Đã thêm candidate:", candidate);
    } catch (err) {
      console.error("❌ Lỗi thêm ICE candidate:", err);
    }
  }

  rejectCall() {
    if (this.callState === 'awaiting_answer') {
      const callee_id = this.friend.id; // ID của người nhận cuộc gọi
      console.log("📤 Đang gửi call_rejected với callee_id:", callee_id);
      this.channel.push("call_rejected", { callee_id })
        .receive("ok", () => console.log("✅ Đã gửi call_rejected"))
        .receive("error", err => console.error("❌ Lỗi gửi call_rejected:", err));
      this.endCall(); // Kết thúc cuộc gọi sau khi từ chối
    }
  }

  async openForwardModal(messageId) {
    console.log('🔹 Gọi openForwardModal với messageId:', messageId);

    this.forwardMessage = this.messages.find((m) => m.id === messageId);
    console.log('🔹 Tin nhắn được tìm thấy:', this.forwardMessage);

    if (!this.forwardMessage) {
      console.error('❌ Tin nhắn không tồn tại:', messageId);
      return;
    }

    console.log('🔹 Gọi fetchFriends() để lấy danh sách bạn bè...');
    this.friends = await this.fetchFriends();
    console.log('✅ Danh sách bạn bè đã lấy:', this.friends);

    this.showForwardModal = true;
    console.log('🔹 Cập nhật state showForwardModal:', this.showForwardModal);

    this.requestUpdate();
    console.log('🔹 Gọi requestUpdate() để cập nhật giao diện');
  }

  setReplyTo(messageId) {
    console.log("Replying to message ID:", messageId);
    this.replyingTo = messageId;
    this.requestUpdate(); // Trigger UI update
  }

  cancelReply() {
    this.replyingTo = null;
    this.requestUpdate();
  }

  handleInput(e) {
    const content = e.target.value.trim();
    console.log('📝 Input content:', content);
    if (content.length > 0 && !this.isTyping) {
      this.isTyping = true;
      this.channel.push("typing_start", {})
        .receive("ok", () => console.log("Typing start event sent"))
        .receive("error", err => console.error("Error sending typing start:", err));
    } else if (content.length === 0 && this.isTyping) {
      this.isTyping = false;
      this.channel.push("typing_stop", {})
        .receive("ok", () => console.log("Typing stop event sent"))
        .receive("error", err => console.error("Error sending typing stop:", err));
    }
  }

  // Hàm formatDate để hiển thị thời gian (cộng thêm 7 giờ nếu dữ liệu là UTC)
  formatDate(isoString) {
    if (!isoString) return 'Không rõ';
    const date = new Date(isoString);
    if (isNaN(date.getTime())) {
      console.warn("Không parse được dateString:", isoString);
      return 'Không rõ';
    }
    // Cộng thêm 7 giờ để chuyển sang giờ VN
    date.setHours(date.getHours() + 7);
    return date.toLocaleString('vi-VN', {
      timeZone: 'Asia/Ho_Chi_Minh',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false
    });
  }

  static styles = css`
      .chat-messages {
        display: flex;
        flex-direction: column;
        gap: 8px;
        padding: 10px;
        max-height: 400px;
        overflow-y: auto;
      }
      .message-container {
        display: flex;
        align-items: center;
        justify-content: flex-start;
        gap: 4px;
        position: relative;
      }
      .message {
        max-width: 60%;
        padding: 8px 12px;
        border-radius: 12px;
        margin: 4px 0;
        position: relative;
      }
      .message-left {
        align-self: flex-start;
        background-color: #f1f0f0;
        margin-right: auto;
      }
      .message-right {
        align-self: flex-end;
        background-color: #0084ff;
        color: white;
        margin-left: auto;
      }
      .message-avatar-container {
        align-self: flex-start;
        margin-top: 4px;
      }
      .message-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        object-fit: cover;
      }
      #chat-header {
        padding: 10px;
        border-bottom: 1px solid #ddd;
      }
      #chat-header h2 {
        margin: 0;
        font-size: 1.5em;
      }
      .status {
        display: inline-block;
        padding: 4px 10px;
        border-radius: 12px;
        font-size: 14px;
        font-weight: 500;
        text-align: center;
        min-width: 80px;
      }
      .status.active {
        color: green;
      }
      .status.away {
        color: orange;
      }
      .status.offline {
        color: red;
      }
      .search-container {
        margin-top: 10px;
      }
      .search-container input {
        padding: 5px;
        margin-right: 5px;
      }
      .message-status {
        font-size: 12px;
        color: #555;
        margin-top: 2px;
        text-align: right;
      }
        .message-reactions {
      display: flex;
      gap: 4px;
      margin-top: 4px;
    }
    
    .emoji-reaction {
      background: #f0f0f0;
      border-radius: 8px;
      padding: 2px 6px;
      cursor: pointer;
    }
    
    .emoji-actions {
      position: relative;
      margin-top: 4px;
    }
    
    .emoji-picker {
      position: absolute;
      bottom: 100%;
      right: 0;
      background: white;
      border: 1px solid #ddd;
      border-radius: 8px;
      padding: 4px;
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 4px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }
    
    .emoji-picker button {
      border: none;
      background: none;
      padding: 4px;
      cursor: pointer;
      font-size: 1.2em;
    }
      .message:hover .message-actions {
      opacity: 1;
    }

    .message-container {
    display: flex;
    align-items: flex-start; /* Sửa lại cho phù hợp */
    gap: 4px;
    position: relative;
    }

  /* Bao bọc tin nhắn và dropdown thành 1 dòng ngang */
  .message-wrapper {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;
  }

  /* Đảm bảo tin nhắn chiếm phần lớn, còn dropdown sát bên phải */
  .message {
    flex: 1;
  }

  /* Dropdown container nằm bên phải */
  .dropdown-container {
    flex-shrink: 0;
  }

  /* Giữ nguyên các style của dropdown */
  .dropdown {
    position: relative;
    display: inline-block;
  }

  .dropdown-toggle {
    background: none;
    border: none;
    padding: 4px;
    cursor: pointer;
    font-size: 1.2em;
  }

  .dropdown-menu {
    position: absolute;
    right: 0;
    top: 100%;
    background: white;
    border: 1px solid #ddd;
    border-radius: 4px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    z-index: 100;
    min-width: 120px;
    display: none;
  }
  .dropdown-menu.show {
    display: block;
  }


    .dropdown-menu button {
      display: block;
      width: 100%;
      padding: 8px;
      border: none;
      background: none;
      text-align: left;
      cursor: pointer;
    }


    .recalled-message {
      color:rgb(0, 0, 0);
      font-style: italic;
    }
      .pinned-messages-section {
    border: 1px solid #ddd;
    padding: 10px;
    margin: 10px 0;
    border-radius: 8px;
  }
  
  .pinned-message {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px;
    margin: 5px 0;
    background-color: #fff9e6;
    border-radius: 4px;
  }
  
  .unpin-button {
    background: #ffebee;
    border: 1px solid #ffcdd2;
    padding: 4px 8px;
    border-radius: 4px;
    cursor: pointer;
  }
  
  .pin-btn, .unpin-btn {
    border: none;
    background: none;
    padding: 4px;
    cursor: pointer;
    font-size: 0.9em;
  }
  .edit-modal {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0,0,0,0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  
  .modal-content {
    background: white;
    padding: 20px;
    border-radius: 8px;
    width: 500px;
    max-width: 90%;
  }
  
  .modal-content textarea {
    width: 100%;
    height: 150px;
    margin: 10px 0;
    padding: 10px;
  }
  
  .modal-actions {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
  }
  
  .edited-label {
    font-size: 0.8em;
    color: #c3c3c3;
    margin-left: 5px;
    font-style: italic;
  }
    .deleted-message {
    opacity: 0.6;
    background-color: #f8f8f8;
    border: 1px dashed #ddd;
    position: relative;
  }
  
  .deleted-message::after {
    content: "Đã xóa";
    position: absolute;
    bottom: 5px;
    right: 5px;
    font-size: 0.8em;
    color: #666;
  }
    /* Các style hiện có giữ nguyên */
  #video-container {
    display: flex;
    justify-content: space-around;
    margin-top: 20px;
  }
  #local-video, #remote-video {
    width: 300px;
    height: 200px;
    background-color: black;
  }
  .call-controls {
    margin-top: 10px;
    text-align: center;
  }
  .calling-overlay, .incoming-call-overlay {
    background: rgba(0, 0, 0, 0.5);
    color: white;
    padding: 20px;
    border-radius: 10px;
  }
  .system-message {
    text-align: center;
    color: #666;
    font-style: italic;
  }

  .forward-modal {
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: white;
      padding: 20px;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.2);
      z-index: 1000;
      width: 400px;
      max-height: 80vh;
      overflow-y: auto;
    }
    .friends-list {
      margin: 10px 0;
      max-height: 300px;
      overflow-y: auto;
    }
    .friend-item {
      display: flex;
      align-items: center;
      padding: 8px;
      border-bottom: 1px solid #eee;
    }
    .modal-actions {
      display: flex;
      justify-content: flex-end;
      gap: 10px;
    }
    .notification {
      padding: 10px;
      background: #d4edda;
      color: #155724;
      border-radius: 4px;
      margin: 10px 0;
    }
    .forwarded-message-header {
      font-size: 0.9em;
      color: #666;
      margin-bottom: 4px;
    }
    .replying-to {
    background: #f0f0f0;
    padding: 5px 10px;
    border-radius: 4px;
    margin-bottom: 5px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    }

    .reply-info {
  font-size: 0.9em;
  color: #666;
  background: #e9ecef;
  padding: 4px 8px;
  border-radius: 4px;
  margin-bottom: 4px;
}
  .typing-indicator {
  padding: 8px 16px;
  color:rgb(255, 25, 60);
  font-style: italic;
  font-size: 0.85em;
  background-color: #f5f5f5;
  border-radius: 12px;
  margin: 4px 0;
  display: inline-block;
  transition: all 0.3s ease;
  max-width: 80%;
} 
  .unread-line {
    display: flex;
    align-items: center;
    margin: 10px 0;
  }
  .unread-line hr {
    flex-grow: 1;
    border: none;
    border-top: 1px solid #ff4444;
  }
  .unread-line span {
    padding: 0 10px;
    color: #ff4444;
    font-size: 0.9em;
    font-weight: bold;
  }
    `;

  render() {
    const cssClass =
      this.friendStatus === 'online' || this.friendStatus === 'Đang hoạt động'
        ? 'active'
        : this.friendStatus.startsWith('Hoạt động')
          ? 'away'
          : 'offline';

    // Gộp messages và callHistory thành combinedItems, sắp xếp theo inserted_at
    const combinedItems = [...this.messages, ...this.callHistory].sort(
      (a, b) => new Date(a.inserted_at) - new Date(b.inserted_at)
    );

    // Lọc danh sách dựa trên searchQuery
    const filteredItems = this.searchQuery
      ? combinedItems.filter((item) => {
        if (item.is_deleted || item.is_recalled) return false;
        if (item.content) {
          // Lọc tin nhắn dựa trên nội dung
          return item.content.toLowerCase().includes(this.searchQuery.toLowerCase());
        }
        return false; // Không lọc lịch sử cuộc gọi
      })
      : combinedItems.filter((item) => !item.is_deleted);

    // Thông báo kết quả tìm kiếm
    const searchNotification = this.searchQuery
      ? filteredItems.length > 0
        ? `Đã tìm thấy ${filteredItems.length} tin nhắn có chứa "${this.searchQuery}"`
        : 'Không tìm thấy tin nhắn nào'
      : '';

    const typingMessage = this.typingUsers.length > 0
      ? html`<div class="typing-indicator">
      ${this.typingUsers.map(id =>
        id === this.friend.id ? html`${this.friend.email} đang soạn tin nhắn...` : ''
      )}
    </div>`
      : '';

    return html`
        <div id="chat-header">
          <h2>Chat với ${this.friend?.email || 'Người dùng không xác định'}</h2>
          <p class="status ${cssClass}">Trạng thái: ${this.friendStatus}</p>
          <button
            type="button"
            @click=${() => (this.showSearch = !this.showSearch)}
            class="search-button"
          >
            🔍
          </button>
          ${this.showSearch
        ? html`
                <div class="search-container">
                  <form @submit=${this.handleSearch}>
                    <input
                      type="text"
                      name="search_query"
                      placeholder="Tìm kiếm tin nhắn..."
                      value=${this.searchQuery}
                      required
                    />
                    <button type="submit">🔍</button>
                  </form>
                </div>
              `
        : ''}
          ${this.searchQuery
        ? html`<div class="search-notification">${searchNotification}</div>`
        : ''}
        </div>
    
        <!-- Phần hiển thị video -->
        <div id="video-container">
          <video id="remote-video" autoplay playsinline></video>
          <video id="local-video" autoplay playsinline muted></video>
        </div>
    
        <!-- Phần điều khiển cuộc gọi -->
        <div class="call-controls">
          ${this.callState === 'idle'
        ? html`<button @click=${this.startCall}>Gọi video</button>`
        : ''}
          ${this.callState === 'calling'
        ? html`
                <div class="calling-overlay">
                  <p>Đang gọi...</p>
                  <button @click=${this.endCall}>Hủy</button>
                </div>
              `
        : ''}
          ${this.callState === 'awaiting_answer'
        ? html`
                <div class="incoming-call-overlay">
                  <p>Cuộc gọi đến từ ${this.friend.email}</p>
                  <button @click=${this.acceptCall}>Trả lời</button>
                  <button @click=${this.rejectCall}>Từ chối</button>
                </div>
              `
        : ''}
          ${this.callState === 'in_call'
        ? html`<button @click=${this.endCall}>Kết thúc</button>`
        : ''}
        </div>
    
        <!-- Phần hiển thị tin nhắn đã ghim -->
        <div class="pinned-messages-section">
          <h3>📌 Tin nhắn đã ghim</h3>
          ${this.pinnedMessages.length === 0
        ? html`<p class="no-pinned-messages">Chưa có tin nhắn nào được ghim</p>`
        : this.pinnedMessages.map(
          (pinned) => html`
                  <div class="pinned-message" id=${`pinned-message-${pinned.id}`}>
                    <div class="pinned-content">
                      <strong>${pinned.user?.email || 'Người dùng không xác định'}:</strong>
                      <p>${pinned.content}</p>
                    </div>
                    <button
                      @click=${() => this.handleUnpinMessage(pinned.id)}
                      class="unpin-button"
                    >
                      Gỡ ghim
                    </button>
                  </div>
                `
        )}
        </div>
    
        <!-- Phần hiển thị tin nhắn và lịch sử cuộc gọi -->
        <div class="chat-messages">
  ${filteredItems.map((item, index) => {
          // Tìm tin nhắn gốc trong this.messages dựa trên reply_to_id
          const replyToMessage = item.reply_to_id
            ? this.messages.find(msg => msg.id === item.reply_to_id)
            : null;
          if (item.content) {
            // Xử lý tin nhắn
            const messageClass = item.user_id === this.currentUser?.id ? 'message-right' : 'message-left';
            // Kiểm tra nếu đây là tin nhắn chưa đọc đầu tiên
            const isFirstUnread = this.initialFirstUnreadMessageId === item.id;
            return html`
            ${isFirstUnread
                ? html`
                <div class="unread-line">
                  <hr />
                  <span>Tin nhắn chưa đọc</span>
                </div>
              `
                : ''}
        <div class="message-container">
          ${item.user_id !== this.currentUser?.id && item.user?.avatar_url
                ? html`
                <div class="message-avatar-container">
                  <img src=${item.user.avatar_url} alt="avatar" class="message-avatar" />
                </div>
              `
                : ''}
          <div class="message-wrapper">
            ${this.showEditModal === item.id
                ? html`
                  <div class="edit-modal">
                    <div class="modal-content">
                      <h3>Chỉnh sửa tin nhắn</h3>
                      <form @submit=${(e) => this.handleEditSubmit(e, item.id)}>
                        <textarea
                          .value=${item.content}
                          @input=${(e) => (this.editContent = e.target.value)}
                          maxlength="2000"
                        ></textarea>
                        <div class="character-count">
                          ${this.editContent?.length || item.content.length || 0}/2000 ký tự
                        </div>
                        <div class="modal-actions">
                          <button type="button" @click=${() => this.toggleEditModal(null)}>
                            Hủy
                          </button>
                          <button type="submit">Lưu</button>
                        </div>
                      </form>
                    </div>
                  </div>
                `
                : ''}
            <div class="message ${messageClass}" title="Thời gian gửi: ${this.formatDate(item.inserted_at)}">
            ${replyToMessage
                ? html`
                      <div class="reply-info">
                        Trả lời: ${replyToMessage.content.substring(0, 20)}...
                      </div>
                    `
                : ''}
              <!-- Tin chuyển tiếp -->
              ${item.is_forwarded
                ? html`
                  
                  `
                : ''}
              <!-- Nội dung tin nhắn -->
              ${item.is_deleted
                ? html`<em>Tin nhắn đã bị xóa</em>`
                : item.is_recalled
                  ? html`<div class="recalled-message">Tin nhắn đã được thu hồi</div>`
                  : html`
                    <strong>${item.user?.email ?? 'Unknown User'}:</strong>
                    ${item.content}
                    ${item.is_edited ? html`<span class="edited-label">(đã chỉnh sửa)</span>` : ''}
                  `}
              <!-- Hiển thị trạng thái tin nhắn nếu là tin của người gửi hiện tại và là tin cuối -->
              ${item.user_id === this.currentUser?.id && this.isLastMessage(item)
                ? html`
                    <div class="message-status">
                      ${this.renderMessageStatus(item)}
                    </div>
                  `
                : ''}
              <!-- Phản ứng tin nhắn -->
              <div class="message-reactions">
                ${item.reactions?.map(
                  (reaction) => html`<span class="emoji-reaction">${reaction.emoji}</span>`
                )}
              </div>
              <!-- Các hành động emoji nếu tin chưa được thu hồi -->
              ${!item.is_recalled
                ? html`
                    <div class="emoji-actions">
                      <button @click=${() => this.handleToggleEmojiPicker(item.id)} class="emoji-trigger">
                        😀
                      </button>
                      ${this.showEmojiPicker === item.id
                    ? html`
                            <div class="emoji-picker">
                              ${['👍', '❤️', '😄', '😠', '😲'].map(
                      (emoji) => html`
                                  <button @click=${() => this.handleReactToMessage(item.id, emoji)}>
                                    ${emoji}
                                  </button>
                                `
                    )}
                            </div>
                          `
                    : ''}
                    </div>
                  `
                : ''}
            </div>
            <!-- Dropdown các thao tác -->
            <div class="dropdown-container">
              <div class="dropdown">
                <button class="dropdown-toggle" type="button" @click=${() => this.handleShowDropdown(item.id)}>
                  ⋯
                </button>
                <div class="dropdown-menu ${this.showDropdown === item.id ? 'show' : ''}">
                  ${item.user_id === this.currentUser?.id
                ? html`
                        ${!item.is_recalled
                    ? html`
                              <button @click=${() => this.handleRecallMessage(item.id)}>Thu hồi</button>
                              <button @click=${() => this.toggleEditModal(item.id)}>Chỉnh sửa</button>
                              <button @click=${() => this.openForwardModal(item.id)}>Chuyển tiếp</button>
                              <button @click=${() => this.setReplyTo(item.id)}>Trả lời</button>
                            `
                    : ''}
                        <button @click=${() => this.handleDeleteMessage(item.id)}>Xóa</button>
                      `
                : html`
                        ${!item.is_recalled && !item.is_deleted
                    ? html`
                              <button @click=${() => this.openForwardModal(item.id)}>Chuyển tiếp</button>
                            `
                    : ''}
                      `}
                  ${!item.is_recalled
                ? html`
                        ${this.pinnedMessages.some((m) => m.id === item.id)
                    ? html`
                              <button @click=${() => this.handleUnpinMessage(item.id)}>
                                Gỡ ghim
                              </button>
                            `
                    : html`
                              <button @click=${() => this.handlePinMessage(item.id)}>
                                Ghim tin nhắn
                              </button>
                            `}
                      `
                : ''}
                </div>
              </div>
            </div>
          </div>
        </div>
      `;
          } else {
            // Xử lý lịch sử cuộc gọi
            return html`
        <div class="system-message">
          ${item.status === 'rejected'
                ? html`
                <p>
                  📞 ${item.callee.email} đã từ chối cuộc gọi video - ${this.formatDate(item.inserted_at)}
                </p>
              `
                : item.status === 'answered'
                  ? html`
                <p>
                  📞 Cuộc gọi video đã kết thúc
                  (${Math.floor(item.duration / 60)}:${String(item.duration % 60).padStart(2, '0')})
                  - ${this.formatDate(item.inserted_at)}
                </p>
              `
                  : html`
                <p>📞 Cuộc gọi nhỡ - ${this.formatDate(item.inserted_at)}</p>
              `}
        </div>
      `;
          }
        })}
</div>

${this.showForwardModal
        ? html`
      <div class="forward-modal">
        <h2>Chuyển tiếp tin nhắn</h2>
        <form @submit=${this.handleForwardMessage}>
          <input type="hidden" name="message_id" value=${this.forwardMessage?.id} />
          <div class="friends-list">
            ${this.friends.map(
          (friend) => html`
                <label class="friend-item">
                  <input type="radio" name="recipient_id" value=${friend.id} />
                  <span>${friend.email}</span>
                </label>
              `
        )}
          </div>
          <div class="modal-actions">
            <button type="submit">Gửi</button>
            <button type="button" @click=${() => (this.showForwardModal = false)}>Hủy</button>
          </div>
        </form>
      </div>
    `
        : ''}
        ${this.replyingTo
        ? html`
              <div class="replying-to">
                Đang trả lời tin nhắn: ${this.messages.find(m => m.id === this.replyingTo)?.content.substring(0, 20)}...
                <button @click=${() => this.cancelReply()}>Hủy</button>
              </div>
            `
        : ''}
        ${typingMessage}
<form @submit=${this.handleSubmit}>
  <input type="text" id="content" placeholder="Nhập tin nhắn..." required @input=${this.handleInput}/>
  <button type="submit">Gửi</button>
</form>

      `;
  }
}

customElements.define('chat-input', ChatInput);
