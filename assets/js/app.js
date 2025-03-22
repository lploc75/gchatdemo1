import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import "./chat-room.js";
import Uploaders from "./uploaders"

// Cấu hình STUN server của Google
const configuration = {
  iceServers: [
    { urls: "stun:stun.l.google.com:19302", }

  ]
};

// Các biến toàn cục
let localStream;
let remoteStream;
let peerConnection;
let remoteOffer; // Lưu remote offer khi nhận từ server


// Thêm biến toàn cục để lưu trữ candidate tạm thời
let pendingCandidates = [];

const handleCandidate = async (candidate) => {
  if (!candidate) {
    console.error("Candidate không hợp lệ:", candidate);
    return;
  }

  if (!peerConnection || !peerConnection.remoteDescription) {
    console.log("🚦 Lưu candidate vào hàng đợi:", candidate);
    pendingCandidates.push(candidate);
    return;
  }

  try {
    await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
    console.log("✅ ICE candidate added:", candidate);
  } catch (err) {
    console.error("❌ Lỗi thêm ICE candidate:", err);
  }
};

// Trong hàm processPendingCandidates
const processPendingCandidates = async () => {
  console.log("🕒 Bắt đầu xử lý candidate đang chờ");
  const candidates = [...pendingCandidates];
  pendingCandidates = [];
  for (const candidate of candidates) {
    try {
      await peerConnection.addIceCandidate(new RTCIceCandidate(candidate));
      console.log("✅ Thêm candidate thành công:", candidate);
    } catch (err) {
      console.error("❌ Lỗi thêm candidate:", err.message, candidate);
    }
  }
  console.log("✅ Đã xử lý tất cả candidate");
};


// Hàm khởi tạo RTCPeerConnection
const createPeerConnection = () => {
  console.log("Tạo PeerConnection với cấu hình:", configuration);
  peerConnection = new RTCPeerConnection(configuration);
  console.log("ICE state ban đầu:", peerConnection.iceConnectionState);

  if (!peerConnection) {
    console.error("⚠️ Lỗi: peerConnection chưa được khởi tạo!");
  } else {
    // Gộp log từ 2 callback thành 1
    peerConnection.oniceconnectionstatechange = () => {
      console.log("ICE Connection State:", peerConnection.iceConnectionState);
      if (peerConnection.iceConnectionState === "connected") {
        console.log("🎉 Kết nối ICE thành công!");
      }
    };
  }
  // Thêm trigger xử lý candidate từ cả 2 phía
  peerConnection.onnegotiationneeded = () => {
    console.log("🔄 Yêu cầu negotiate lại kết nối");
  };

  peerConnection.onicecandidate = (event) => {
    if (event.candidate) {
      console.log("✅ ICE candidate được tạo:", event.candidate);
      window.pushWebRTCEvent("candidate", { candidate: event.candidate.toJSON() });
    } else {
      console.log("⚠️ ICE gathering kết thúc (không có candidate)");
    }
  };

  peerConnection.ontrack = (event) => {
    console.log("📡 Nhận được track từ peer:", event.track.kind);
    const remoteVideo = document.getElementById('remote-video');
    if (!remoteVideo) {
      console.error("Không tìm thấy phần tử remote-video trong DOM");
      return;
    }
    if (event.track.kind === 'audio') {
      console.log("Đã nhận được audio track.");
      // // Tạo một MediaStream chỉ chứa audio track
      // let audioStream = new MediaStream([event.track]);

      // // Kiểm tra và tạo phần tử audio nếu chưa có
      // let audioElem = document.getElementById('remote-audio');
      // if (!audioElem) {
      //   audioElem = document.createElement('audio');
      //   audioElem.id = 'remote-audio';
      //   audioElem.controls = true;
      //   document.body.appendChild(audioElem);
      // }
      // // Gán stream cho audio element và phát lại
      // audioElem.srcObject = audioStream;
      // audioElem.play().catch(err => console.error("Lỗi phát audio:", err));

      // // --- Phần ghi âm audio ---
      // let recordedChunks = [];
      // // Tạo MediaRecorder với stream audio
      // let mediaRecorder = new MediaRecorder(audioStream);

      // // Khi có dữ liệu ghi âm sẵn sàng, lưu vào mảng recordedChunks
      // mediaRecorder.ondataavailable = (event) => {
      //   if (event.data.size > 0) {
      //     recordedChunks.push(event.data);
      //   }
      // };

      // // Khi dừng ghi âm, tạo Blob và tạo URL phát lại
      // mediaRecorder.onstop = () => {
      //   let blob = new Blob(recordedChunks, { type: 'audio/webm' });
      //   let url = URL.createObjectURL(blob);
      //   console.log("URL của audio ghi âm:", url);

      //   // Tạo hoặc cập nhật phần tử audio để phát lại đoạn ghi âm
      //   let recordedAudioElem = document.getElementById('recorded-audio');
      //   if (!recordedAudioElem) {
      //     recordedAudioElem = document.createElement('audio');
      //     recordedAudioElem.id = 'recorded-audio';
      //     recordedAudioElem.controls = true;
      //     document.body.appendChild(recordedAudioElem);
      //   }
      //   recordedAudioElem.src = url;
      // };

      // // Bắt đầu ghi âm (ví dụ: ghi trong 5 giây)
      // mediaRecorder.start();
      // console.log("Đang ghi âm audio...");
      // setTimeout(() => {
      //   mediaRecorder.stop();
      //   console.log("Dừng ghi âm audio sau 5 giây.");
      // }, 5000);
      // // --- End phần ghi âm ---

    } else if (event.track.kind === 'video') {
      if (!remoteVideo.srcObject) {
        console.log("🎥 Đang khởi tạo remote video stream");
        remoteVideo.srcObject = new MediaStream([event.track]);
        remoteVideo.onloadedmetadata = () => {
          console.log("🎬 Remote video ready to play");
          remoteVideo.play().catch(err => console.error("Lỗi play:", err));
        };
      }
    }
  };

  // Kiểm tra các receiver sau khi remote description được đặt
  setTimeout(() => {
    console.log("PeerConnection Receivers:", peerConnection.getReceivers());
  }, 1000);
};


// Hàm chờ cho đến khi hook WebRTC sẵn sàng
const waitForWebRTC = () => {
  return new Promise((resolve) => {
    if (window.webrtcReady) {
      console.log("WebRTC đã sẵn sàng.");
      resolve();
    } else {
      console.log("Chờ WebRTC sẵn sàng...");
      const interval = setInterval(() => {
        if (window.webrtcReady) {
          clearInterval(interval);
          console.log("WebRTC sẵn sàng sau khi chờ.");
          resolve();
        }
      }, 100);
    }
  });
};

// Hàm bắt đầu cuộc gọi (cho bên gọi - caller)
const startCall = async () => {
  isAnswerProcessed = false; // Reset trạng thái
  console.log("Bắt đầu cuộc gọi (caller)...");
  await waitForWebRTC();

  try {
    // ✅ Thêm kiểm tra sau khi lấy stream
    if (peerConnection) {
      peerConnection.close();
      peerConnection = null;
    }
    localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    console.log("Lấy được local stream (caller):", localStream);
    const localVideo = document.getElementById("local-video");
    if (localVideo) {
      localVideo.srcObject = localStream;
      console.log("Gán local stream cho video caller thành công.");
    } else {
      console.error("Không tìm thấy phần tử video local (caller).");
    }

    createPeerConnection();
    localStream.getTracks().forEach((track) => {
      console.log("Thêm track vào PeerConnection (caller):", track);
      peerConnection.addTrack(track, localStream);
    });

    const offer = await peerConnection.createOffer({
      offerToReceiveAudio: true,
      offerToReceiveVideo: true
    });
    console.log("Tạo offer thành công (caller):", offer);
    await peerConnection.setLocalDescription(offer);
    console.log("Đặt local description thành công (caller):", peerConnection.localDescription);

    console.log("Đang gửi offer qua pushWebRTCEvent (caller)...");
    window.pushWebRTCEvent("offer", { sdp: offer.sdp, type: offer.type });
  } catch (err) {
    console.error("Lỗi khi bắt đầu cuộc gọi (caller):", err);
  }
};

// Hàm xử lý offer nhận được từ server (bên nhận - receiver)
// Chỉ lưu trữ remote offer để chờ người dùng bấm "Trả lời"
const handleOffer = async (offer) => {
  console.log("Đang lưu trữ offer nhận được (receiver):", offer);
  remoteOffer = offer.sdp || offer;
};

// Hàm xử lý khi người dùng chấp nhận cuộc gọi (receiver)
// Hàm này sẽ lấy local stream, tạo kết nối, áp dụng remote offer đã lưu, tạo answer và gửi answer lên server.
const acceptCall = async () => {
  console.log("Người dùng đã chấp nhận cuộc gọi (receiver)");
  try {
    if (peerConnection) {
      peerConnection.close();
      peerConnection = null;
    }
    localStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
    console.log("Lấy được local stream (receiver):", localStream);
    const localVideo = document.getElementById('local-video');
    if (localVideo) localVideo.srcObject = localStream;

    createPeerConnection();
    localStream.getTracks().forEach((track) => {
      console.log("Thêm track vào PeerConnection (receiver):", track);
      peerConnection.addTrack(track, localStream);
    });

    // Áp dụng remote offer đã lưu
    const remoteOfferDesc = new RTCSessionDescription({ type: "offer", sdp: remoteOffer });
    await peerConnection.setRemoteDescription(remoteOfferDesc);
    console.log("Đặt remote description với offer thành công (receiver).");
    await processPendingCandidates(); // Thêm dòng này

    const answer = await peerConnection.createAnswer({
      offerToReceiveAudio: true,
      offerToReceiveVideo: true
    });
    console.log("Tạo answer thành công (receiver):", answer);
    await peerConnection.setLocalDescription(answer);
    console.log("Đặt local description với answer thành công (receiver):", peerConnection.localDescription);

    console.log("Đang gửi answer qua pushWebRTCEvent (receiver)...");
    window.pushWebRTCEvent("answer", { sdp: answer.sdp, type: answer.type });
  } catch (err) {
    console.error("Lỗi khi chấp nhận cuộc gọi (receiver):", err);
  }
};

let isAnswerProcessed = false;

const handleAnswer = async (answer) => {
  console.log("🔔 Bắt đầu xử lý answer...");
  if (isAnswerProcessed) {
    console.log("🚨 Answer đã được xử lý trước đó, bỏ qua.");
    return;
  }
  if (!peerConnection) {
    console.log("🚨 PeerConnection chưa được khởi tạo, không thể xử lý answer.");
    return;
  }
  try {
    const answerDesc = new RTCSessionDescription(answer);
    console.log("🔧 Đang đặt remote description...");
    await peerConnection.setRemoteDescription(answerDesc);
    console.log("✅ Đặt remote description thành công");
    await processPendingCandidates();
    isAnswerProcessed = true;
  } catch (err) {
    console.error("❌ Lỗi xử lý answer:", err);
  }
};







const endCall = () => {
  isAnswerProcessed = false;
  console.log("Kết thúc cuộc gọi.");
  // Xóa các candidate đang chờ
  pendingCandidates = [];
  if (peerConnection) {
    peerConnection.close();
    peerConnection = null;
    console.log("Đóng kết nối PeerConnection thành công.");
  }
  if (localStream) {
    localStream.getTracks().forEach((track) => {
      track.stop();
      console.log("Dừng track của local stream:", track);
    });
    localStream = null;
  }
  if (remoteStream) {
    remoteStream.getTracks().forEach((track) => {
      track.stop();
      console.log("Dừng track của remote stream:", track);
    });
    remoteStream = null;
  }
  const localVideo = document.getElementById('local-video');
  const remoteVideo = document.getElementById('remote-video');
  if (localVideo) {
    localVideo.srcObject = null;
    console.log("Xóa nguồn cho video local.");
  }
  if (remoteVideo) {
    remoteVideo.srcObject = null;
    console.log("Xóa nguồn cho video remote.");
  }
};

let WebRTCHook = {
  mounted() {
    console.log("Hook WebRTC đã được mount.");

    window.pushWebRTCEvent = (event, payload) => {
      console.log(`Gọi pushWebRTCEvent với event: ${event}`, payload);
      this.pushEvent(event, payload);
    };

    window.webrtcReady = true;
    console.log("WebRTC sẵn sàng.");

    // Khi nhận offer từ server, chỉ lưu trữ remote offer (không tự động trả lời)
    this.handleEvent("handle_offer", async ({ sdp }) => {
      console.log("Nhận offer - chỉ lưu trữ:", sdp);
      await handleOffer(sdp);
    });

    this.handleEvent("handle_answer", (payload) => {
      console.log("Nhận answer từ server:", payload);
      handleAnswer(payload);
    });


    this.handleEvent("handle_candidate", (payload) => {
      console.log("Nhận candidate từ server:", payload);
      handleCandidate(payload.candidate);
    });

    this.handleEvent("call_rejected", () => {
      console.log("Cuộc gọi bị từ chối");
      endCall();
    });
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: { _csrf_token: csrfToken },
  hooks: {
    WebRTC: WebRTCHook
  }
});

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());
document.addEventListener("DOMContentLoaded", () => {
  document.body.addEventListener("click", (event) => {
    const dropdown = event.target.closest(".dropdown");
    if (dropdown) {
      dropdown.classList.toggle("open");
    } else {
      document.querySelectorAll(".dropdown.open").forEach((el) => el.classList.remove("open"));
    }
  });
});
console.log("Hihi Khanh")
liveSocket.connect();
console.log("LiveSocket connected:", liveSocket.isConnected());

// Lắng nghe sự kiện từ LiveView cho caller
window.addEventListener("phx:start_call", (event) => {
  console.log("Nhận sự kiện phx:start_call từ server (caller).");
  startCall();
});
window.addEventListener("phx:end_call", (event) => {
  console.log("Nhận sự kiện phx:end_call từ server.");
  endCall();
});

// Lắng nghe sự kiện từ LiveView khi người dùng bấm nút "Trả lời" (sự kiện "user_answer")
// Ở phía server, bạn cần xử lý "user_answer" để push event "accept_call" về client.
window.addEventListener("phx:accept_call", () => {
  acceptCall();
});

window.addEventListener("phx:handle_answer", (event) => {
  console.log("Nhận sự kiện phx:handle_answer từ server:", event.detail);
  handleAnswer(event.detail);
});

window.liveSocket = liveSocket;
