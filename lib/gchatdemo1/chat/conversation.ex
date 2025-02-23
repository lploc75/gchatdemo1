defmodule Gchatdemo1.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :is_group]}  # Chỉ mã hóa các trường này
  schema "conversations" do
    field :name, :string
    field :is_group, :boolean, default: false
    belongs_to :creator, Gchatdemo1.Accounts.User
    has_many :group_members, Gchatdemo1.Chat.GroupMember
    has_many :messages, Gchatdemo1.Chat.Message

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:name, :is_group, :creator_id])
    |> validate_required([:name, :is_group, :creator_id])
  end
end
