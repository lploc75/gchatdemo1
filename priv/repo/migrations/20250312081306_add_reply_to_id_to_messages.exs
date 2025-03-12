defmodule Gchatdemo1.Repo.Migrations.AddReplyToIdToMessages do
  use Ecto.Migration

  def change do
    alter table(:messages) do
      add :reply_to_id, references(:messages, on_delete: :nilify_all)
    end
  end
end
