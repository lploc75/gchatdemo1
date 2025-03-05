defmodule Gchatdemo1.Repo.Migrations.AddFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :status, :string, default: "offline"
      add :last_active_at, :utc_datetime
      add :role, :integer, default: 1
      timestamps(type: :utc_datetime)
    end
  end
end
