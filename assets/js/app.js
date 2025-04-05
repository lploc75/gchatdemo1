import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"
import Uploaders from "./uploaders"

import "./chat-room.js";
import "./dashboard.js";
import "./list_friend.js";
import "./friend_request.js";
import "./register.js";
import "./login.js";
import "./forgot-password.js";
import "./reset-password.js";
import "./user-confirmation.js";
import "./user-confirm-instruction.js";
import "./user-setting.js";
import "./chat_input.js"

// ✅ Load HLS.js từ CDN
const loadHls = new Promise((resolve) => {
  if (window.Hls) return resolve(window.Hls);
  let script = document.createElement("script");
  script.src = "https://cdn.jsdelivr.net/npm/hls.js@latest";
  script.onload = () => resolve(window.Hls);
  document.head.appendChild(script);
});

// 🔥 Phoenix LiveView Hook cho HLS Player để lấy dc quality cho video restream
let Hooks = {};
Hooks.HLSPlayer = {
  mounted() {
    console.log("✅ Hook HLSPlayer mounted!");

    const video = this.el;
    const qualitySelector = document.getElementById("quality-selector");
    const videoSrc = video.dataset.src;

    if (!videoSrc) {
      console.error("❌ No video source available!");
      return;
    }

    if (Hls.isSupported()) {
      const hls = new Hls();
      hls.startPosition = 0;
      hls.loadSource(videoSrc);
      hls.attachMedia(video);

      let seeked = false; // ✅ Biến cờ kiểm tra đã seek hay chưa

      hls.on(Hls.Events.MANIFEST_PARSED, function () {
        let optionsHTML = `<option value="-1">Auto</option>`;
        hls.levels.forEach((level, index) => {
          console.log(`📌 Thêm option: ${level.height}p`);
          optionsHTML += `<option value="${index}">${level.height}p</option>`;
        });

        qualitySelector.innerHTML = optionsHTML;

        qualitySelector.addEventListener("change", function () {
          const quality = parseInt(qualitySelector.value);
          hls.currentLevel = quality;
          console.log(`✅ Đổi chất lượng sang: ${quality === -1 ? "Auto" : hls.levels[quality]?.height + "p"}`);
        });

        video.play();
      });

      // ✅ Chỉ seek về 0 đúng 1 lần
      hls.on(Hls.Events.BUFFER_APPENDED, function () {
        if (!seeked && video.currentTime > 0) {
          console.log("⏪ Seek về 0...");
          video.currentTime = 0;
          seeked = true; // 🔥 Đánh dấu đã seek, không seek lại nữa
        }
      });

      hls.on(Hls.Events.ERROR, function (event, data) {
        console.error("❌ HLS.js error:", data);
      });
    } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
      video.src = videoSrc;
      video.addEventListener("loadedmetadata", function () {
        video.currentTime = 0;
        video.play();
      });
    } else {
      console.error("❌ HLS is not supported in this browser!");
    }
  }
};

// let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
// let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, uploaders: Uploaders, params: { _csrf_token: csrfToken } });

topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());


let WebRTCHook = {
  mounted() {
    console.log("Hook WebRTC đã được mount.");

    window.pushWebRTCEvent = (event, payload) => {
      console.log(`Gọi pushWebRTCEvent với event: ${event}`, payload);
      this.pushEvent(event, payload);
    };

    window.webrtcReady = true;
    console.log("WebRTC sẵn sàng.");
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  uploaders: Uploaders,
  params: { _csrf_token: csrfToken },
  hooks: {
    WebRTC: WebRTCHook,
    ...Hooks // Giữ lại các hooks từ object Hooks ban đầu
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
liveSocket.connect();
console.log("LiveSocket connected:", liveSocket.isConnected());


window.liveSocket = liveSocket;