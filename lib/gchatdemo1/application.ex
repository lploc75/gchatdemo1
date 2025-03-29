defmodule Gchatdemo1.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  require Logger

  @port 9006
  @local_ip {127, 0, 0, 1}

  @impl true
  def start(_type, _args) do

    rtmp_server_options = %{
      port: @port,
      listen_options: [
        :binary,
        packet: :raw,
        active: false,
        ip: @local_ip
      ],
      # Xử lý các tác vụ khi bấm OBS stream (ví dụ như stream key)
      handle_new_client: fn client_ref, streamer_id, stream_key ->
        # Lấy stream_key từ database để check với cái từ OBS
        stream_key_current =
          case Gchatdemo1.Repo.get_by(Gchatdemo1.StreamSetting, streamer_id: streamer_id) do
            nil -> nil
            stream_setting -> stream_setting.stream_key
          end

        # Kiểm tra xem stream_key có hợp lệ không
        if stream_key == stream_key_current and stream_key_current != nil and streamer_id != nil do
          # Gọi modal xác nhận trước khi tạo stream


            # Tạo một stream_infor mới
            IO.inspect(streamer_id, label: "📌 streamer_id trước khi tạo stream")

            result =
              Gchatdemo1.Streams.create_stream_infor(%{
                streamer_id: streamer_id,
                stream_status: true
              })

            IO.inspect(result, label: "📌 Kết quả create_stream_infor")

            # Lấy stream_id để tạo output_path
            stream_infor = Gchatdemo1.Streams.get_stream_by_streamer_id(streamer_id)

            case stream_infor do
              nil ->
                Logger.info("Client ref khi tắt: #{inspect(client_ref)}")
                terminate_client_ref(client_ref, streamer_id)

              stream -> IO.inspect(stream, label: "📌 Kết quả stream_infor")
            end

            stream_id = stream_infor.id
            output_path = "#{stream_id}/index.m3u8"

            case Gchatdemo1.Streams.update_output_path(stream_infor, output_path) do
              {:ok, updated_stream} -> IO.inspect(updated_stream, label: "✅ Đã cập nhật output_path")
              {:error, changeset} -> IO.inspect(changeset.errors, label: "❌ Lỗi khi cập nhật output_path")
            end

            Logger.info("Starting pipeline for stream key: #{stream_key} + #{stream_key_current}")

            # Xóa file output.mp4
            File.mkdir_p("output/#{stream_id}")

            Logger.info("Client ref: #{inspect(client_ref)}")

            # Tạo pipeline stream
            {:ok, _sup, pid} =
              Membrane.Pipeline.start_link(Gchatdemo1.Pipeline, %{
                client_ref: client_ref,
                app: streamer_id,
                stream_key: stream_key
              })

            {Gchatdemo1.ClientHandler, %{pipeline: pid, streamer_id: streamer_id}}
        else
          Logger.error("Invalid stream key: #{stream_key}")
          terminate_client_ref(client_ref, streamer_id)
        end
      end
    }

    children = [
       # Start the RTMP server
       %{
        id: Membrane.RTMPServer,
        start: {Membrane.RTMPServer, :start_link, [rtmp_server_options]}
      },

      Gchatdemo1Web.Telemetry,
      Gchatdemo1.Repo,
      {DNSCluster, query: Application.get_env(:gchatdemo1, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Gchatdemo1.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Gchatdemo1.Finch},
      # Start a worker by calling: Gchatdemo1.Worker.start_link(arg)
      # {Gchatdemo1.Worker, arg},
      # Start to serve requests, typically the last entry
      Gchatdemo1Web.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Gchatdemo1.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Gchatdemo1Web.Endpoint.config_change(changed, removed)
    :ok
  end


  defp confirm_action do
    topic = "confirm_modal"
    parent = self()

    # Gửi sự kiện yêu cầu xác nhận đến LiveView
    Phoenix.PubSub.broadcast(Gchatdemo1.PubSub, topic, {:show_modal, parent})

    receive do
      {:modal_result, response} -> response
    end
  end

  def terminate_client_ref(client_ref, streamer_id) do
    Membrane.Pipeline.terminate(client_ref,
      timeout: 5000,
      force?: false,
      asynchronous?: true
    )

    {Gchatdemo1.ClientHandler, %{pipeline: client_ref, streamer_id: streamer_id}}
  end
end
