defmodule Gchatdemo1Web.Router do
  use Gchatdemo1Web, :router

  import Gchatdemo1Web.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Gchatdemo1Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_user
  end

  scope "/", Gchatdemo1Web do
    pipe_through :browser

    get "/", PageController, :home
    delete "/users/log_out", UserSessionController, :delete
    get "/users/register", PageController, :register
    get "/users/log_in", PageController, :log_in
    get "/users/forgot_password", PageController, :forgot_password
    get "/users/reset_password/:token", PageController, :reset_password
    get "/users/confirm/:token", PageController, :confirm_email
    get "/users/confirm", PageController, :confirm_email_instructions
    get "/messages/:conversation_id", PageController, :chat

     # Thêm rouute cho livestreamn
     get "/video/*filename", HlsController, :index
     get "/stream/:streamer_name/custom_stream", CustomStreamController, :index

     live "/watch_video/:id", VideoLive
     get "/stream_key/:streamer_name", StreamSettingController, :index
     live "/stream", StreamNowListLive

     # Cho xem restream
     get "/watch/:streamer_name", StreamListOldController, :index
     live "/watch/:display_name/:stream_id", WatchOldLive
     get "/watch_restream/:streamer_name/:stream_id/:filename", HlsController, :watch
     # List streamer

     live "/streamers", StreamerListLive
  end

  # Các route yêu cầu user phải đăng nhập
  scope "/", Gchatdemo1Web do
    pipe_through [:browser, :require_authenticated_user]
    get "/", PageController, :home
    get "/dashboard", PageController, :index
    get "/users/settings", PageController, :user_setting
    get "/users/settings/confirm_email/:token", PageController, :user_setting_confirm_email
    get "/list_friends", PageController, :list_friends
    get "/friend_requests", PageController, :friend_requests_page
  end

  # Other scopes may use custom stacks.
  # scope "/api", Gchatdemo1Web do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:gchatdemo1, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: Gchatdemo1Web.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end


  scope "/", Gchatdemo1Web do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{Gchatdemo1Web.UserAuth, :ensure_authenticated}] do
      live "/chat", ChatLive, :index # Route của chat nhóm
    end
  end

  scope "/", Gchatdemo1Web do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{Gchatdemo1Web.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  scope "/api", Gchatdemo1Web do
    pipe_through :api
    # pipe_through [:api, :require_authenticated_user]
    get "/users/check_reset_token", UserResetPasswordController, :check_token  # Kiểm tra token
    post "/register", AuthController, :register    # Đăng ký
    post "/users/log_in", UserSessionController, :create   # Đăng nhập
    post "/users/reset_password/request", UserForgotPasswordController, :send_reset_email  # Gửi email reset
    post "/users/reset_password/confirm", UserResetPasswordController, :reset_password  # Đặt lại mật khẩu
    post "/users/send_confirmation", UserConfirmationController, :send_instructions # gửi email xác nhận lại
    post "/users/confirm", UserConfirmationController, :confirm_account # xác nhận tài khoản
    # Trang user setting
    get "/users/avatar/presign", UserSettingController, :presign_avatar_upload
    post "/users/avatar/update", UserSettingController, :update_avatar
    post "/users/settings/update_email", UserSettingController, :update_email
    post "/users/settings/update_password", UserSettingController, :update_password
    get "/users/settings/confirm_email/:token", UserSettingController, :confirm_email
    post "/users/settings/update_display_name", UserSettingController, :update_display_name

    get "/dashboard", PageController, :dashboard
    post "/friends", PageController, :friends
    post "/users/:id/send_request", PageController, :send_friend_request
    post "/users/:id/cancel_request", PageController, :cancel_friend_request
    # Route hiển thị danh sách lời mời
    get "/friend_requests", PageController, :friend_requests
    # Route xử lý chấp nhận/từ chối lời mời
    post "/friend_requests/:id/accept", PageController, :accept_friend_request
    post "/friend_requests/:id/decline", PageController, :decline_friend_request
    # Hiện thị danh sách bạn bè
    get "/list_friends", PageController, :friends
    # Thêm route hủy kết bạn
    delete "/unfriend/:friend_id", PageController, :unfriend
    post "/messages", MessageController, :create
    # Router chuyển tiếp tin nhắn
    post "/forward_message", MessageController, :forward_message
    # Route lấy dữ liệu messages (JSON)
    get "/messages/:conversation_id", MessageController, :show

    # Route này để lấy token
    get "/user_token", UserSessionController, :get_token
    get "/users/me", UserSessionController, :get_user_info    # Lấy thông tin user
    # Lấy danh sách bạn bè của người dùng
    get "/friends", ChatController, :get_friends
    # Lấy danh sách bạn bè chưa trong group
    get "/groups/:conversation_id/available_friends", ChatController, :available_friends
    # Lấy dánh sách nhóm của người dùng
    get "/groups", ChatController, :get_groups
    # Lấy danh sách thành viên trong nhóm
    get "/groups/:conversation_id/members", ChatController, :list_members
    # Tìm kiếm tin nhắn
    get "/messages/search", ChatController, :search_messages
    # Lấy danh sách tin nhắn trong cuộc trò chuyện
    get "/group_messages/:conversation_id", ChatController, :get_messages

    # Cập nhật thông tin nhóm
    post "/groups/update", ChatController, :update_group
    # Tạo nhóm mới
    post "/groups/create", ChatController, :create_group
    # Xóa nhóm
    post "/groups/delete", ChatController, :delete_group
    # Thêm thành viên vào nhóm
    post "/groups/add_member", ChatController, :add_member
    # Xóa thành viên khỏi nhóm
    post "/groups/remove_member", ChatController, :remove_member
    # Rời nhóm
    post "/groups/leave", ChatController, :leave_group
    # Chuyển tiếp tin nhắn
    post "/messages/forward", ChatController, :forward_message
    # Cập nhật trạng thái tất cả tin nhắn của 1 người dùng trong 1 nhóm
    post "/messages/conversation/:conversation_id/mark-seen", ChatController, :mark_messages_as_seen
    # Cập nhật trạng thái của một tin nhắn
    post "/messages/:message_id/mark-seen", ChatController, :mark_single_message_as_seen

    # post "/messages", ChatController, :send_message

    # Xem stream
    get "/stream/:streamer_name", StreamController, :stream
    # Stream key
    get "/stream_key/:streamer_name", StreamController, :show
    post "/stream_key/:streamer_name", StreamController, :create
    # Streamer mode
    get "/stream/check/:streamer_name", StreamController, :check_stream_mode
    post "/stream/toggle", StreamController, :toggle_role
    # Xem stream list
    get "/streams/active", StreamController, :list_active_streams
    # Restream get
    get "/streamers", StreamController, :list_streamers
    get "/streams/old/:streamer_name", StreamController, :get_old_streams
    # Update title và desc
    put "/stream/update-setting", StreamController, :update_stream_setting
    # oldstream
    get "/video/:stream_id", StreamController, :get_video_info
    # tutorial
    get "/tutorial-stream/:name", StreamController, :get_streamer_id
  end

  scope "/", Gchatdemo1Web do
    pipe_through :browser

    live_session :authenticated_messaging,
      on_mount: [{Gchatdemo1Web.UserAuth, :ensure_authenticated}] do
      live "/messages/new", MessageLive, :new
      live "/messages/:conversation_id", MessageLive, :chat
    end
  end
end
