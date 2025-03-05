defmodule Gchatdemo1.Repo.Migrations.CreateReactions do
  use Ecto.Migration

  def change do
  create table(:reactions) do
        add :user_id, references(:users, on_delete: :delete_all), null: false
        add :message_id, references(:messages, on_delete: :delete_all), null: false
        add :emoji, :string, null: false  # Lưu emoji dưới dạng string (unicode)

        timestamps()
      end

      # Đảm bảo mỗi user chỉ có thể react 1 emoji duy nhất trên 1 tin nhắn
      create unique_index(:reactions, [:user_id, :message_id])
  end
end
