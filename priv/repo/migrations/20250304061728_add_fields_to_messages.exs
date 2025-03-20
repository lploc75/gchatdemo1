defmodule Gchatdemo1.Repo.Migrations.AddFieldsToMessages do
  use Ecto.Migration


  def change do
    alter table(:messages) do
      add :file_url, :string
      add :is_forwarded, :boolean, default: false
      add :original_sender_id, references(:users, on_delete: :nothing)  # Tạo khóa ngoại tới bảng users
    end
  end
end
