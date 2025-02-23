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

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:user_id, :conversation_id, :content, :message_type, :is_edited, :is_recalled])
    |> validate_required([:user_id, :conversation_id, :content])
  end
end
