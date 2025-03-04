defmodule Gchatdemo1.Repo.Migrations.AddFieldsToConversations do
  use Ecto.Migration

  def change do
    alter table(:conversations) do
      add :only_admin_can_message, :boolean, default: false, null: false
      add :visibility, :string, default: "public"
    end
  end
end
