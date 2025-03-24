defmodule Gchatdemo1.Repo.Migrations.CreateStreamSettings do
  use Ecto.Migration

  def change do
    create table(:stream_settings) do
      add :streamer_id, :integer
      add :stream_key, :string
      add :title, :string
      add :description, :text

      timestamps(type: :utc_datetime)
    end
  end
end
