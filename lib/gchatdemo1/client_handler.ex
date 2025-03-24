defmodule Gchatdemo1.ClientHandler do
  @moduledoc """
  An implementation of `Membrane.RTMPServer.ClientHandlerBehaviour` compatible with the
  `Membrane.RTMP.Source` element, which also sends information about RTMP stream metadata to the `pipeline` process
  """
  require Logger

  @behaviour Membrane.RTMPServer.ClientHandler

  @handler Membrane.RTMP.Source.ClientHandlerImpl

  defstruct []

  @impl true
  def handle_init(%{pipeline: pid, streamer_id: streamer_id} = opts) do
    state = @handler.handle_init(opts)
    base_state = if is_map(state), do: state, else: %{}
    new_state =
      base_state
      |> Map.put(:pipeline, pid)
      |> Map.put(:streamer_id, streamer_id)
    Logger.info("State trong clienthandler: #{inspect(state)}")
    new_state
  end

  @impl true
  defdelegate handle_info(msg, state), to: @handler

  @impl true
  defdelegate handle_data_available(payload, state), to: @handler

  @impl true
  def handle_connection_closed(state) do
    Logger.info("Client disconnected, stopping pipeline and updating stream status...")

    if state.pipeline do
      Membrane.Pipeline.terminate(state.pipeline, timeout: 5000)
    end

    if state.streamer_id do
      try do
        case Gchatdemo1.Streams.update_stream_status_when_stop_stream(state.streamer_id) do
          {:ok, _updated_stream} ->
            Logger.info("✅ Đã dừng stream thành công cho streamer_id: #{state.streamer_id}")
          {:error, reason} ->
            Logger.error("❌ Lỗi khi dừng stream: #{inspect(reason)}")
        end
      rescue
        exception ->
          Logger.error("❌ Exception xảy ra: #{Exception.message(exception)}")
      end
    else
      Logger.warning("Streamer_id is nil, skipping stream status update")
    end

    state
  end

  @impl true
  defdelegate handle_delete_stream(state), to: @handler

  @impl true
  def handle_metadata(message, state) do
    send(state.pipeline, message)
    state
  end
end
