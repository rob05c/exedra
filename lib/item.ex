defmodule Exedra.Item do

  @data_file "data/items"

  defmodule Data do
    @enforce_keys [:id, :name, :brief]
    # name is a single word, like 'sword' or 'feather'. This is the keyword used to issue commands like 'drop sword'.
    # brief is a noun clause, like 'a wooden sword' or 'a dull, blue orb'. This is what is seen in arbitrary locations, such as inventory and wielding.
    # description is a paragraph. This is what is seen when inspecting an item in detail, for example 'probe sword'.
    # room_description is a declarative sentence, complete with period.. It is what is seen when the item is on the ground. For example, 'a chipped wooden sword lies here, muddy with footprints.'
    defstruct id:               0,
              name:             "",
              brief:            "",
              description:      "",
              room_description: ""
  end

  def load() do
    File.mkdir_p! Path.dirname(@data_file)
    case :ets.file2tab(String.to_charlist(@data_file)) do
      {:ok, :items} ->
        IO.puts "Items file loaded"
        :ok
      {:error, _} ->
        IO.puts "Items file didn't exist, creating new table"
        :items = :ets.new(:items, [:named_table, :set, :public])
    end
    :ok
  end

  def create(player, name, brief) do
    next_id = :ets.update_counter(:items, :next_id, 1, {1,0})
    new_item = %Exedra.Item.Data{id: next_id, name: name, brief: brief}
    :ets.insert_new(:items, {next_id, new_item})

    # debug - writing all objects to disk every change doesn't scale
    :ets.tab2file(:items, String.to_charlist(@data_file), sync: true)

    Exedra.User.set(%{player | items: MapSet.put(player.items, new_item.id)})

    new_item
  end

  def pickup(item_id, room, player) do
    Exedra.Room.set(%{room | items: MapSet.delete(room.items, item_id)})
    Exedra.User.set(%{player | items: MapSet.put(player.items, item_id)})
  end

  def drop(item_id, room, player) do
    Exedra.User.set(%{player | items: MapSet.delete(player.items, item_id)})
    Exedra.Room.set(%{room | items: MapSet.put(room.items, item_id)})
  end


  def get(id) do
    case :ets.lookup(:items, id) do
      [{_, item}] ->
        {:ok, item}
      [] ->
        :error
    end
  end

  def set(item) do
    :ets.insert(:items, {item.id, item})

    # debug - writing all users to disk every time someone moves doesn't scale.
    :ets.tab2file(:items, String.to_charlist(@data_file), sync: true)
  end
end
