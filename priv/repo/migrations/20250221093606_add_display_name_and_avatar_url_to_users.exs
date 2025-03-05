defmodule Gchatdemo1.Repo.Migrations.AddDisplayNameAndAvatarUrlToUsers do
  use Ecto.Migration

 def change do
    alter table(:users) do
      add :display_name, :string, null: true
      add :avatar_url, :string, null: true
    end
  end
end
