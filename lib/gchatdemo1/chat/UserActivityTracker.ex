defmodule Gchatdemo1Web.UserActivityTracker do
  alias Gchatdemo1.Repo

  def update_last_active(user_id) do
    case Repo.get(Gchatdemo1.Accounts.User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        datetime = DateTime.utc_now() |> DateTime.truncate(:second)

        user
        |> Ecto.Changeset.change(last_active_at: datetime)
        |> Repo.update()
    end
  end
end
