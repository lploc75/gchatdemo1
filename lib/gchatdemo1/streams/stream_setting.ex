defmodule Gchatdemo1.StreamSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stream_settings" do
    field :streamer_id, :integer
    field :stream_key, :string
    field :title, :string
    field :description, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(stream_setting, attrs) do
    stream_setting
    |> cast(attrs, [:streamer_id, :stream_key])
    |> validate_required([:streamer_id, :stream_key])
  end
end
