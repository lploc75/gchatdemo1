defmodule Gchatdemo1.Chat.MessageEdit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "message_edits" do
    field :previous_content, :string
    belongs_to :message, Gchatdemo1.Chat.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(message_edit, attrs) do
    message_edit
    |> cast(attrs, [:previous_content, :message_id])
    |> validate_required([:previous_content, :message_id])
  end
end
