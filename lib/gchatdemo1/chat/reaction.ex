defmodule Gchatdemo1.Chat.Reaction do
  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:id, :message_id, :user_id, :emoji, :inserted_at, :updated_at]}
  schema "reactions" do
    field :emoji, :string
    belongs_to :user, Gchatdemo1.Accounts.User
    belongs_to :message, Gchatdemo1.Chat.Message

    timestamps()
  end

  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:user_id, :message_id, :emoji])
    |> validate_required([:user_id, :message_id, :emoji])
    |> unique_constraint([:user_id, :message_id, :emoji]) # Đảm bảo mỗi user chỉ có 1 reaction cho 1 message
  end
end
