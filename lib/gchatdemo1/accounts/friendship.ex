defmodule Gchatdemo1.Accounts.Friendship do
  use Ecto.Schema
  import Ecto.Changeset

  schema "friendships" do
    field :status, :string, default: "pending"

    # Assumes you have a MyApp.User schema for users
    belongs_to :user, Gchatdemo1.Accounts.User
    belongs_to :friend, Gchatdemo1.Accounts.User
    timestamps()
  end

  @doc false
  def changeset(friendship, attrs) do
    friendship
    |> cast(attrs, [:user_id, :friend_id, :status])
    |> validate_required([:user_id, :friend_id, :status])
    |> unique_constraint(:user_friend, name: :friendships_user_id_friend_id_index)
  end
end
