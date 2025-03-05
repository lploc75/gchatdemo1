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
    # ⚠️ Cần có dòng này!
    plug :fetch_session
    # ⚠️ Cần có dòng này!
    plug :fetch_current_user
  end

  scope "/", Gchatdemo1Web do
    pipe_through :browser

    get "/", PageController, :home
    get "/dashboard", PageController, :dashboard
    post "/dashboard", PageController, :dashboard
    post "/users/:id/send_request", PageController, :send_friend_request
    post "/users/:id/cancel_request", PageController, :cancel_friend_request
    # Route hiển thị danh sách lời mời
    get "/friend_requests", PageController, :friend_requests
    # Route xử lý chấp nhận/từ chối lời mời
    post "/friend_requests/:id/accept", PageController, :accept_friend_request
    post "/friend_requests/:id/decline", PageController, :decline_friend_request
    # Hiện thị danh sách bạn bè
    get "/friends", PageController, :friends
    # Thêm route hủy kết bạn
    delete "/unfriend/:friend_id", PageController, :unfriend
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

  ## Authentication routes

  scope "/", Gchatdemo1Web do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{Gchatdemo1Web.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", Gchatdemo1Web do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{Gchatdemo1Web.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      # Thêm route cho trang chat
      live "/chat", ChatLive, :index
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

    # Thêm route này để lấy token
    get "/user_token", UserSessionController, :get_token

    # Lấy danh sách bạn bè của người dùng
    get "/friends", ChatController, :get_friends
    # Lấy danh sách bạn bè chưa trong group
    get "/conversations/:conversation_id/available_friends", ChatController, :available_friends
    # Lấy dánh sách nhóm của người dùng
    get "/groups", ChatController, :get_groups
    # Lấy danh sách thành viên trong nhóm
    get "/groups/:conversation_id/members", ChatController, :list_members
    # Đổi list_messages thành get_messages
    get "/messages/:conversation_id", ChatController, :get_messages

    post "/groups/update", ChatController, :update_group
    post "/groups/create", ChatController, :create_group
    post "/groups/add_member", ChatController, :add_member
    # post "/messages", ChatController, :send_message
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
