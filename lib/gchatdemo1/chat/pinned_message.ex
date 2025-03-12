defmodule Gchatdemo1.Chat.PinnedMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pinned_messages" do
    belongs_to :message, Gchatdemo1.Chat.Message
    belongs_to :conversation, Gchatdemo1.Chat.Conversation
    belongs_to :pinner, Gchatdemo1.Accounts.User, foreign_key: :pinned_by

    timestamps()
  end

  @doc false
  def changeset(pinned_message, attrs) do
    pinned_message
    |> cast(attrs, [:message_id, :conversation_id, :pinned_by])
    |> validate_required([:message_id, :conversation_id, :pinned_by])
    |> unique_constraint([:conversation_id, :message_id],
      name: :pinned_messages_conversation_id_message_id_index
    )
  end
end
