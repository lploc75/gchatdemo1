import { Socket } from "phoenix";

let socket = new Socket("/socket", { withCredentials: true });

socket.connect();

export function joinGroupChat(groupId, onMessageReceived) {
  if (!socket.isConnected()) {
    console.error("❌ WebSocket chưa kết nối!");
    return null;
  }

  let channel = socket.channel(`group_chat:${groupId}`, {});

  channel.join()
    .receive("ok", () => console.log(`✅ Đã vào nhóm ${groupId}`))
    .receive("error", (err) => console.error("❌ Không thể vào nhóm!", err));

  channel.on("new_message", (payload) => {
    console.log("📩 Nhận tin nhắn mới:", payload);
    onMessageReceived(payload.message);
  });

  return {
    sendMessage: (content) => {
      if (!content.trim()) return;
      console.log("📤 Gửi tin nhắn:", content);

      channel.push("new_message", { content })
        .receive("ok", (resp) => console.log("✅ Tin nhắn đã gửi:", resp.message))
        .receive("error", (err) => console.error("❌ Lỗi gửi tin nhắn:", err));
    },

    leaveChannel: () => {
      channel.leave();
      console.log(`🚪 Rời nhóm ${groupId}`);
    },
  };
}

export default socket;
