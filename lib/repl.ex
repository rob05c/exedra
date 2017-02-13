defmodule Exedra.REPL do
  def start(user_charlist) do
    username = String.Chars.to_string user_charlist
    spawn fn ->
      Process.flag(:trap_exit, true) # TODO: determine if necessary
      IO.puts "Hello " <> username <> "!"
      loop(username)
    end
  end

  def loop(username) do
    prompt = "> "

    line = prompt
    |> IO.gets
    |> String.Chars.to_string
    |> String.trim_trailing

    case line do
      "l" ->
        {:ok, user} = Exedra.User.get(username)
        room_id = user.room_id
        {:ok, room} = Exedra.Room.get(user.room_id)
        IO.puts Exedra.Room.print(room, false)
      "ql" ->
        {:ok, user} = Exedra.User.get(username)
        room_id = user.room_id
        {:ok, room} = Exedra.Room.get(user.room_id)
        IO.puts Exedra.Room.print(room, true)
      _ ->
        IO.puts "I don't understand '" <> line <> "'."
    end

    loop(username)
  end
end
