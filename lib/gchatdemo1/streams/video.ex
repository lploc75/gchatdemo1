defmodule Gchatdemo1.Video do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :title, :description, :url, :inserted_at, :updated_at]}
  schema "videos" do
    field :title, :string
    field :description, :string
    field :url, :string

    timestamps()
  end

  def changeset(video, attrs) do
    video
    |> cast(attrs, [:title, :description, :url])
    |> validate_required([:title, :description, :url])
  end
end
