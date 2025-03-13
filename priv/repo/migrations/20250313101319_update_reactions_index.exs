defmodule Gchatdemo1.Repo.Migrations.UpdateReactionsIndex do
  use Ecto.Migration

  def change do
    # Xóa unique constraint cũ (nếu có)
    drop_if_exists unique_index(:reactions, [:user_id, :message_id])

    # Tạo unique constraint mới (cho phép user thả nhiều loại emoji)
    create unique_index(:reactions, [:user_id, :message_id, :emoji])
  end
end
