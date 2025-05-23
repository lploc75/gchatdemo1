# Yêu cầu hệ thống
- **WSL** (Windows Subsystem for Linux).  
- **Ubuntu** trên WSL  
- Cài các công cụ sau trên Ubuntu (WSL): ([Tham khảo](https://hexdocs.pm/phoenix/installation.html))  
  - **Erlang**  
  - **Elixir**  
  - **Phoenix**  
  - **PostgreSQL**  
- Đã cài **OBS Studio** trên Windows

# Hướng dẫn cho stream:
1. Tải WSL (window subsystem for linux)
2. Tải Ubuntu cho wsl
3. Dùng lệnh `ls` để xem các thư mục, cd tới thư mục "~" hay là thư mục home
4. Tải erlang, elixir, phoenix trên wsl
5. Khi chạy `mix deps.get` hay là `mix deps.compile` thì có thể xáy ra lỗi vì có một vài deps nó cần cài thủ công nên cần phải hỏi gpt để chỉ cách tải.
6. Nếu muốn tương tác pgAdmin của postgrex trên wsl thì lên chat GPT hỏi hơi khó làm, còn ko thì cứ tương tác với database bằng ecto là được. (gõ là cách tương tác với pgadmin trên wsl là nó ra cách làm).
7. Vào OBS -> Setting -> Stream: Tại mục Services thì chọn là Custom..., mục Server thì rtmp://localhost:9006/<Streamer_Id còn gọi là User_Id> ví dụ (rtmp://localhost:9006/1), Stream key thì tạo r gắn vào mới stream dc.
8. Hiện tại cú merge vào main trước nếu có lỗi hay cài không dc liên hệ Kiên để setup các thứ.

# Gchatdemo1

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
