defmodule Gchatdemo1Web.CallChannel do
  use Gchatdemo1Web, :channel

  @impl true
  def join("call:" <> conversation_id, _params, socket) do
    IO.puts("User joined call channel for conversation #{conversation_id}")
    {:ok, assign(socket, :conversation_id, conversation_id)}
  end

  def handle_in("offer", %{"sdp" => sdp}, socket) do
    IO.puts("Received offer from #{socket.assigns.user_id}")
    broadcast!(socket, "offer", %{from: socket.assigns.user_id, sdp: sdp})
    {:noreply, assign(socket, call_state: :awaiting_answer)}
  end

  def handle_in("answer", %{"sdp" => sdp}, socket) do
    IO.puts("Received answer, current call_state: #{socket.assigns.call_state}")

    if socket.assigns.call_state in [:incoming_call, :awaiting_answer] do
      broadcast!(socket, "answer", %{from: socket.assigns.user_id, sdp: sdp})
      {:noreply, assign(socket, :call_state, :in_call)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_in("candidate", %{"candidate" => candidate}, socket) do
    broadcast!(socket, "candidate", %{candidate: candidate})
    {:noreply, socket}
  end
end
