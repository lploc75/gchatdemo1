defmodule Gchatdemo1.Streams do
  @moduledoc """
  The Streams context.
  """

  import Ecto.Query, warn: false
  alias Gchatdemo1.Repo

  alias Gchatdemo1.Streams.StreamInfor
  alias Gchatdemo1.StreamSetting
  @doc """
  Returns the list of stream_infor.
  """
  def list_stream_infor do
    Repo.all(StreamInfor)
  end

  @doc """
  Gets a single stream_infor.

  Raises `Ecto.NoResultsError` if the Stream infor does not exist.
  """
  def get_stream_infor!(id), do: Repo.get!(StreamInfor, id)

  @doc """
  Creates a stream_infor.
  """
  def create_stream_infor(attrs \\ %{}) do
    %StreamInfor{}
    |> StreamInfor.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a stream_infor.
  """
  def update_stream_infor(%StreamInfor{} = stream_infor, attrs) do
    stream_infor
    |> StreamInfor.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stream_infor.
  """
  def delete_stream_infor(%StreamInfor{} = stream_infor) do
    Repo.delete(stream_infor)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream_infor changes.
  """
  def change_stream_infor(%StreamInfor{} = stream_infor, attrs \\ %{}) do
    StreamInfor.changeset(stream_infor, attrs)
  end

  # Lấy stream_id theo streamer_name và stream_status = true
  def get_stream_by_streamer_id(streamer_id) do
    streams =
      Repo.all(
        from s in StreamInfor,
          where: s.streamer_id == ^streamer_id and s.stream_status == true,
          order_by: [desc: s.id]
      )

    case streams do
      # Không có stream nào đang bật
      [] ->
        nil

      [latest | others] ->
        # Cập nhật tất cả các stream khác thành false
        Enum.each(others, fn stream ->
          Repo.update!(Ecto.Changeset.change(stream, stream_status: false))
        end)

        # Trả về stream mới nhất
        latest
    end
  end

  def update_output_path(%StreamInfor{} = stream, new_path) do
    stream
    |> StreamInfor.changeset(%{output_path: new_path})
    |> Repo.update()
  end

  def update_stream_status_when_stop_stream(streamer_id) do
    case Repo.get_by(StreamInfor, streamer_id: streamer_id, stream_status: true) do
      nil ->
        {:error, "Stream not found or already stopped"}

      stream ->
        stream
        |> StreamInfor.changeset(%{stream_status: false})
        |> Repo.update()
    end
  end

  # Cái này cho user nếu có sẵn khỏi dem qua
  def get_streamer_id_by_name(streamer_name) do
    Repo.one(
      # Thêm đầy đủ namespace
      from u in Gchatdemo1.Accounts.User,
        where: u.display_name == ^streamer_name,
        select: u.id
    )
  end

  # Cái này đúng hơn là coi user có bao giờ stream chưa
  def is_streamer(streamer_id) do
    query =
      from s in Gchatdemo1.Streams.StreamInfor,
        where: s.streamer_id == ^streamer_id,
        select: count(s.id) > 0

    Repo.one(query)
  end

  def turn_on_stream_mode?(streamer_id) do
    query =
      from u in Gchatdemo1.Accounts.User,
        where: u.id == ^streamer_id and u.role == 2,
        select: count(u.id) > 0

    Repo.one(query)
  end

  def toggle_role(user_id) do
    user = Repo.get!(Gchatdemo1.Accounts.User, user_id)

    new_role = if user.role == 1, do: 2, else: 1

    user
    |> Ecto.Changeset.change(role: new_role)
    |> Repo.update()
  end

  def get_all_stream_now do
    Repo.all(
      from s in StreamInfor,
        where: s.stream_status == true,
        select: %{streamer_id: s.streamer_id, stream_id: s.id}
    )
  end

  def get_stream_setting_for_user(streamer_id) do
    Repo.one(
      from s in Gchatdemo1.StreamSetting,
        where: s.streamer_id == ^streamer_id,
        select: %{streamer_id: s.streamer_id, title: s.title, description: s.description}
    )
  end

  def update_stream_setting_for_user(streamer_id, attrs) do
    Repo.get_by(Gchatdemo1.StreamSetting, streamer_id: streamer_id)
    |> case do
      nil ->
        {:error, "Stream setting not found"}

      stream_setting ->
        stream_setting
        |> Ecto.Changeset.change(attrs)
        |> Repo.update()
    end
  end

  def get_all_stream_old do
    Repo.all(
      from s in StreamInfor,
        join: ss in Gchatdemo1.StreamSetting,
        on: s.streamer_id == ss.streamer_id,
        where: s.stream_status == false,
        select: %{
          stream_id: s.id,
          streamer_id: s.streamer_id,
          title: ss.title,
          description: ss.description
        }
    )
  end


  def get_all_streamer_name do
    Repo.all(
      from u in Gchatdemo1.Accounts.User,
        where: u.role == 2,
        select: %{streamer_id: u.id, streamer_name: u.display_name, avatar_url: u.avatar_url}
    )
  end

  # Stream key`
  # Lấy stream key của streamer theo ID
  def get_stream_key_by_streamer_id(streamer_id) do
    Repo.one(
      from s in StreamSetting,
        where: s.streamer_id == ^streamer_id,
        select: s.stream_key
    )
  end

  # Tạo stream key mới
  def generate_stream_key do
    :crypto.strong_rand_bytes(12) |> Base.encode16() |> binary_part(0, 16)
  end

  # Lưu stream key vào database (tạo hoặc cập nhật)
  def save_stream_key(streamer_id) do
    stream_key = generate_stream_key()

    case Repo.get_by(StreamSetting, streamer_id: streamer_id) do
      nil ->
        changeset =
          StreamSetting.changeset(%StreamSetting{}, %{
            streamer_id: streamer_id,
            stream_key: stream_key
          })

        case Repo.insert(changeset) do
          {:ok, _} -> {:ok, stream_key}
          {:error, _} -> {:error, "Không thể tạo stream key"}
        end

      stream_setting ->
        changeset =
          StreamSetting.changeset(stream_setting, %{
            stream_key: stream_key
          })

        case Repo.update(changeset) do
          {:ok, _} -> {:ok, stream_key}
          {:error, _} -> {:error, "Không thể cập nhật stream key"}
        end
    end
  end
end
