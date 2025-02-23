export default {
  Cloudinary(entries, onViewError) {
    entries.forEach(entry => {
      if (!entry.meta || !entry.meta.url || !entry.meta.fields) {
        console.error("Lỗi: Thiếu meta.url hoặc meta.fields trong entry", entry)
        entry.error()
        return
      }

      let formData = new FormData()
      let { url, fields } = entry.meta

      formData.append("file", entry.file)
      Object.entries(fields).forEach(([key, val]) => formData.append(key, val))

      let xhr = new XMLHttpRequest()

      // Kiểm tra và thiết lập onViewError
      if (typeof onViewError === "function") {
        onViewError(() => xhr.abort())
      }

      xhr.upload.addEventListener("progress", (event) => {
        if (event.lengthComputable) {
          let percent = Math.round((event.loaded / event.total) * 100)
          if (percent < 100) {
            entry.progress(percent)
          }
        }
      })

      xhr.onload = () => {
        if (xhr.status === 200) {
          let response = JSON.parse(xhr.responseText)
          console.log("Upload thành công:", response)
          entry.progress(100)
        } else {
          console.error("Upload thất bại:", xhr.responseText)
          entry.error()
        }
      }

      xhr.onerror = () => {
        console.error("Lỗi kết nối khi tải lên Cloudinary")
        entry.error()
      }

      xhr.open("POST", url, true)
      xhr.send(formData)
    })
  }
}
