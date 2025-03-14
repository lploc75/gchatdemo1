defmodule Gchatdemo1.Repo.Migrations.CreateVideos do
  use Ecto.Migration

  def change do
    create table(:videos) do
      add :title, :string
      add :url, :string
      add :description, :text

      timestamps()
    end
  end
end
