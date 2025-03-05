defmodule Gchatdemo1.Repo.Migrations.AddMessageEdit do
  use Ecto.Migration

 def change do
    create table(:message_edits) do
      add :previous_content, :text
      add :message_id, references(:messages, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:message_edits, [:message_id])
  end
end
