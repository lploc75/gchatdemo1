defmodule Gchatdemo1.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    # Tạo bảng users
    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Tạo chỉ mục duy nhất trên email
    create unique_index(:users, [:email])

    # Tạo bảng users_tokens
    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    # Tạo bảng conversations
    create table(:conversations) do
      add :name, :string, null: false
      add :is_group, :boolean, default: false, null: false
      add :creator_id, references(:users, on_delete: :delete_all)  # Sửa thành :delete_all
      timestamps()
    end

    # Tạo bảng group_members
    create table(:group_members) do
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :is_admin, :boolean, default: false

      timestamps()
    end

    # Tạo bảng messages
    create table(:messages) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :message_type, :string, default: "text", null: false
      add :is_edited, :boolean, default: false
      add :is_recalled, :boolean, default: false

      timestamps()
    end

    # Tạo bảng friendships
    create table(:friendships) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :friend_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "pending", null: false

      timestamps()
    end

    # Tạo các chỉ mục
    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
    create unique_index(:group_members, [:conversation_id, :user_id])
    create index(:messages, [:conversation_id])
    create unique_index(:friendships, [:user_id, :friend_id])
  end
end
