defmodule Gchatdemo1Web.UserActivityTracker do
  alias Gchatdemo1.Repo

  def update_last_active(user) do
    # Cắt microseconds
    datetime = DateTime.utc_now() |> DateTime.truncate(:second)

    user
    |> Ecto.Changeset.change(last_active_at: datetime)
    |> Repo.update()
  end
end
