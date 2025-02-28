defmodule Gchatdemo1.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:user_id, :conversation_id, :content, :message_type, :is_edited, :is_recalled]}
  schema "messages" do
    belongs_to :user, Gchatdemo1.Accounts.User
    belongs_to :conversation, Gchatdemo1.Chat.Conversation
    field :content, :string
    field :message_type, :string, default: "text"
    field :is_edited, :boolean, default: false
    field :is_recalled, :boolean, default: false
    field :is_deleted, :boolean, default: false
    field :status, :string, default: "sent"
    field :file_url, :string
    field :is_forwarded, :boolean, default: false
    belongs_to :original_sender, Gchatdemo1.Accounts.User, foreign_key: :original_sender_id
    timestamps()
  end

def changeset(message, attrs) do
  message
  |> cast(attrs, [:user_id, :conversation_id, :content, :message_type, :is_edited, :is_recalled, :is_deleted, :status, :file_url, :is_forwarded, :original_sender_id])
  |> validate_required([:user_id, :conversation_id, :content])
end

end
