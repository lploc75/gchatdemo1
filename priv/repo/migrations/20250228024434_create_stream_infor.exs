defmodule Gchatdemo1.Repo.Migrations.CreateStreamInfor do
  use Ecto.Migration

  def change do
    create table(:stream_infor) do
      add :streamer_id, :integer
      add :output_path, :string, null: true
      add :stream_status, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
