defmodule Gchatdemo1.Chat.CallHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "call_history" do
    field :call_type, :string
    field :status, :string
    field :started_at, :naive_datetime
    field :ended_at, :naive_datetime
    field :duration, :integer

    belongs_to :caller, Gchatdemo1.Accounts.User
    belongs_to :callee, Gchatdemo1.Accounts.User
    belongs_to :conversation, Gchatdemo1.Chat.Conversation

    timestamps(type: :naive_datetime)
  end

  def changeset(call_history, attrs) do
    call_history
    |> cast(attrs, [
      :call_type,
      :status,
      :caller_id,
      :callee_id,
      :started_at,
      :ended_at,
      :duration,
      :conversation_id
    ])
    |> validate_required([:call_type, :status, :caller_id, :callee_id, :conversation_id])
  end
end
