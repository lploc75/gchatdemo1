defmodule Gchatdemo1.Repo.Migrations.CreateMessageStatuses do
  use Ecto.Migration

  def change do
    create table(:message_statuses) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :status, :string, default: "sent" # sent, delivered, seen
      timestamps()
    end

    create unique_index(:message_statuses, [:message_id, :user_id])
  end
end
