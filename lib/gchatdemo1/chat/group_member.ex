defmodule Gchatdemo1.Chat.GroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:conversation_id, :user_id, :is_admin]}
  schema "group_members" do
    belongs_to :conversation, Gchatdemo1.Chat.Conversation
    belongs_to :user, Gchatdemo1.Accounts.User
    field :is_admin, :boolean, default: false

    timestamps()
  end

  def changeset(group_member, attrs) do
    group_member
    |> cast(attrs, [:conversation_id, :user_id, :is_admin])
    |> validate_required([:conversation_id, :user_id])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
