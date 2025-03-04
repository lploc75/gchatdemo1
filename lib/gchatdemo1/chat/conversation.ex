defmodule Gchatdemo1.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  # Chỉ mã hóa các trường này
  @derive {Jason.Encoder, only: [:id, :name, :is_group, :creator_id ,:only_admin_can_message, :visibility]}
  schema "conversations" do
    field :name, :string
    field :is_group, :boolean, default: false
    belongs_to :creator, Gchatdemo1.Accounts.User
    has_many :group_members, Gchatdemo1.Chat.GroupMember
    has_many :messages, Gchatdemo1.Chat.Message
    field :only_admin_can_message, :boolean, default: false
    field :visibility, :string, default: "public"

    timestamps()
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:name, :is_group, :creator_id, :only_admin_can_message, :visibility])
    |> validate_required([:name, :is_group, :creator_id, :only_admin_can_message, :visibility])
    # Chỉ chấp nhận 2 giá trị
    |> validate_inclusion(:visibility, ["public", "private"])
  end
end
