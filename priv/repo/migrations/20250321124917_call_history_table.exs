defmodule Gchatdemo1.Repo.Migrations.CallHistoryTable do
  use Ecto.Migration

  def change do
    create table(:call_history) do
      add :call_type, :string, null: false
      # "answered", "rejected", "missed"
      add :status, :string, null: false
      add :caller_id, references(:users, on_delete: :nothing), null: false
      add :callee_id, references(:users, on_delete: :nothing), null: false
      add :started_at, :naive_datetime
      add :ended_at, :naive_datetime
      # Thời lượng gọi (giây)
      add :duration, :integer
      add :conversation_id, references(:conversations, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:call_history, [:caller_id])
    create index(:call_history, [:callee_id])
    create index(:call_history, [:conversation_id])
  end
end
