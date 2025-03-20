defmodule Gchatdemo1.Chat.MessageStatus do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message_statuses" do
    belongs_to :message, Gchatdemo1.Chat.Message
    belongs_to :user, Gchatdemo1.Accounts.User
    field :status, :string, default: "sent" # sent, delivered, seen
    timestamps()
  end

  @doc false
  def changeset(message_status, attrs) do
    message_status
    |> cast(attrs, [:message_id, :user_id, :status])
    |> validate_required([:message_id, :user_id, :status])
  end
end
