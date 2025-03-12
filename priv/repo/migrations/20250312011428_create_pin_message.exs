defmodule Gchatdemo1.Repo.Migrations.CreatePinMessage do
  use Ecto.Migration

  def change do
    create table(:pinned_messages) do
      add :message_id, references(:messages, on_delete: :delete_all), null: false
      add :conversation_id, references(:conversations, on_delete: :delete_all), null: false
      add :pinned_by, references(:users, on_delete: :delete_all), null: false
      timestamps()
    end

    create unique_index(:pinned_messages, [:conversation_id, :message_id])
  end
end
