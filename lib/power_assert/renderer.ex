defmodule PowerAssert.Renderer do
  @moduledoc """
  This module renders test result
  """

  @doc false
  def render_values(code_ast, values, left \\ nil, right \\ nil)

  def render_values(code_ast, [], left, right) do
    Macro.to_string(code_ast) <> extra_information(left, right)
  end

  def render_values(code_ast, values, left, right) do
    code_str = Macro.to_string(code_ast)
    values = Enum.sort(values, fn [x_pos, _], [y_pos, _] -> x_pos > y_pos end)
    [max_pos, _] = Enum.max_by(values, fn [pos, _] -> pos end)
    first_line = String.duplicate(" ", max_pos + 1) |> replace_with_bar(values)
    lines = make_lines([], Enum.count(values), values, -1)
    Enum.join([code_str, first_line] ++ lines, "\n") <> extra_information(left, right)
  end

  defp make_lines(lines, 0, _, _latest_pos) do
    lines
  end

  defp make_lines(lines, times, values, latest_pos) do
    [[pos, value] | t] = values
    value = inspect(value)
    value_len = String.length(value)

    lines =
      if latest_pos != -1 && latest_pos - (pos + value_len) > 0 do
        [last_line | tail_lines] = Enum.reverse(lines)
        {before_str, after_str} = String.split_at(last_line, pos)
        {_removed_str, after_str} = String.split_at(after_str, value_len)
        line = before_str <> value <> after_str
        Enum.reverse([line | tail_lines])
      else
        line = String.duplicate(" ", pos + 1)
        line = replace_with_bar(line, values)
        line = String.replace(line, ~r/\|$/, value)
        lines ++ [line]
      end

    make_lines(lines, times - 1, t, pos)
  end

  defp replace_with_bar(line, values) do
    Enum.reduce(values, line, fn [pos, _value], line ->
      {front, back} = String.split_at(line, pos + 1)
      String.replace(front, ~r/ $/, "|") <> back
    end)
  end

  defp extra_information(left, right) when is_list(left) and is_list(right) do
    [
      "\n\nonly in lhs: " <> ((left -- right) |> inspect),
      "only in rhs: " <> ((right -- left) |> inspect)
    ]
    |> Enum.join("\n")
  end

  defp extra_information(left, right) when is_map(left) and is_map(right) do
    left = Map.delete(left, :__struct__)
    right = Map.delete(right, :__struct__)
    in_left = Map.split(left, Map.keys(right)) |> elem(1)
    in_right = Map.split(right, Map.keys(left)) |> elem(1)
    str = "\n"

    str =
      if map_size(in_left) != 0 do
        str <> "\nonly in lhs: " <> inspect(in_left)
      else
        str
      end

    str =
      if map_size(in_right) != 0 do
        str <> "\nonly in rhs: " <> inspect(in_right)
      else
        str
      end

    diff = collect_map_diff(left, right)

    str =
      case Enum.empty?(diff) do
        true -> str
        false -> str <> "\ndifference:\n" <> Enum.join(diff, "\n")
      end

    str
  end

  defp extra_information(left, right) do
    if String.valid?(left) && String.valid?(right) do
      extra_information_for_string(left, right)
    else
      ""
    end
  end

  defp extra_information_for_string(left, right) do
    "\n\ndifference:" <> "\n" <> left <> "\n" <> right
  end

  defp collect_map_diff(map1, map2) do
    Enum.reduce(map2, [], fn {k, v}, acc ->
      case Map.fetch(map1, k) do
        {:ok, ^v} ->
          acc

        {:ok, map1_value} ->
          acc ++ ["key #{inspect(k)} => {#{inspect(map1_value)}, #{inspect(v)}}"]

        _ ->
          acc
      end
    end)
  end


end
