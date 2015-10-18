defmodule PowerAssert.Assertion do
  @moduledoc """
  This module handles Power Assert main function
  """

  @assign_len 3 # length of " = "
  @equal_len  4 # length of " == "

  @doc """
  assert with descriptive messages

      array |> Enum.at(index) == two
      |             |  |         |
      |             |  |         2
      |             |  2
      |             3
      [1, 2, 3]
  """
  defmacro assert(ast, msg \\ nil)

  defmacro assert({:=, _, [left, right]} = ast, msg) do
    # Almost the same code as ExUnit but rhs is displayed in detail
    code = Macro.escape(ast)
    [_|t] = String.split(Macro.to_string(ast), " = ")
    rhs_expr = Enum.join(t, " = ")
    rhs_index = (Macro.to_string(left) |> String.length) + @assign_len
    injected_rhs_ast = inject_store_code(right, rhs_expr, rhs_index)
    message_ast = message_ast(msg)

    {:if, meta, args} =
      quote do
        if right do
          right
        else
          message = PowerAssert.Assertion.render_values(expr, values)
          unquote(message_ast)
          raise ExUnit.AssertionError,
            message: "Expected truthy, got #{inspect right}\n\n" <> message
        end
      end
    return = {:if, [line: -1] ++ meta, args}

    {:case, meta, args} =
      quote do
        case right do
          unquote(left) ->
            unquote(return)
          _ ->
            message = PowerAssert.Assertion.render_values(expr, values)
            unquote(message_ast)
            raise ExUnit.AssertionError,
              message: message
        end
      end

    quote do
      unquote(injected_rhs_ast)
      right = result
      expr  = unquote(code)
      unquote({:case, [{:export_head, true}|meta], args})
    end
  end 

  defmacro assert({:==, _, [left, right]} = ast, msg) do
    code = Macro.escape(ast)
    [lhs_expr|t] = String.split(Macro.to_string(ast), " == ")
    rhs_expr = Enum.join(t, " == ")
    injected_lhs_ast = inject_store_code(left, lhs_expr)
    rhs_index = (Macro.to_string(left) |> String.length) + @equal_len
    injected_rhs_ast = inject_store_code(right, rhs_expr, rhs_index)
    message_ast = message_ast(msg)

    quote do
      unquote(injected_lhs_ast)
      left = result
      left_values = values
      unquote(injected_rhs_ast)
      # wrap result for avoid warning: this check/guard will always yield the same result
      unless left == fn(x) -> x end.(result) do
        message = PowerAssert.Assertion.render_values(unquote(code), left_values ++ values, left, result)
        unquote(message_ast)
        raise ExUnit.AssertionError,
          message: message
      end
      result
    end
  end

  defmacro assert(ast, msg) do
    code = Macro.escape(ast)
    injected_ast = inject_store_code(ast, Macro.to_string(ast))

    message_ast = message_ast(msg)

    quote do
      unquote(injected_ast)
      unless result do
        message = PowerAssert.Assertion.render_values(unquote(code), values)
        unquote(message_ast)
        raise ExUnit.AssertionError,
          message: message
      end
      result
    end
  end

  # for avoid "this check/guard will always yield the same result"
  defp message_ast(msg) when is_binary(msg) do
    quote do
      message = "#{unquote(msg)}\n\n" <> message
    end
  end
  defp message_ast(_msg), do: nil

  @doc false
  def inject_store_code(ast, expr, default_index \\ 0) do
    positions = detect_position(ast, expr, default_index)
    {injected_ast, {_, _}} = PowerAssert.Ast.traverse(ast, {Enum.reverse(positions), 0}, &pre_catcher/2, &catcher/2)
    # IO.inspect injected_ast
    # IO.inspect Macro.to_string injected_ast
    quote do
      {:ok, buffer} = Agent.start_link(fn -> [] end)
      result = unquote(injected_ast)
      values = Agent.get(buffer, &(&1))
      Agent.stop(buffer)
    end
  end

  ## detect positions
  defp detect_position(ast, expr, default_index) do
    {_ast, {_code, positions, _in_fn}} =
      PowerAssert.Ast.traverse(ast, {expr, [], 0}, &pre_collect_position/2, &collect_position/2)
    if default_index != 0 do
      positions = Enum.map(positions, fn([pos, code]) -> [default_index + pos, code] end)
    end
    positions
  end

  @ignored_atoms [:fn, :&, :=, :::, :@]
  defp pre_collect_position({atom, _, _args} = ast, {code, positions, in_fn} = _acc) when atom in @ignored_atoms do
    {ast, {code, positions, in_fn + 1}}
  end
  @unsupported_func [:quote, :<<>>, :case]
  defp pre_collect_position({func, _, _args} = ast, {code, positions, in_fn} = _acc) when func in @unsupported_func do
    {ast, {code, positions, in_fn + 1}}
  end
  @unsupported_func_arity2 [:put_in, :get_and_update_in, :update_in, :for, :match?]
  # get_and_update_in/2, put_in/2, update_in/2, for
  defp pre_collect_position({func, _, [_, _]} = ast, {code, positions, in_fn} = _acc) when func in @unsupported_func_arity2 do
    {ast, {code, positions, in_fn + 1}}
  end
  @ignore_ops [:., :__aliases__, :|>, :==, :!=, :<, :>, :>=, :<=, :*, :||, :&&, :<>, :===, :!==, :and, :or, :=~, :%{}, :%, :->, :|, :{}]
  defp pre_collect_position({func, _, args} = ast, {code, positions, in_fn} = acc) when not func in @ignore_ops and is_atom(func) and is_list(args) do
    case Atom.to_string(func) do
      <<"sigil_", _name>> ->
        {ast, {code, positions, in_fn + 1}}
      _ ->
        {ast, acc}
    end
  end
  defp pre_collect_position(ast, acc) do
    {ast, acc}
  end
  # ex:
  # context[:key]
  #        ^
  defp collect_position({{:., _, [Access, :get]}, _, [_l, _r]} = ast, {_code, _positions, in_fn} = acc) when in_fn > 0, do: {ast, acc}
  defp collect_position({{:., _, [Access, :get]}, _, [_l, right]} = ast, {code, positions, in_fn} = _acc) do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, code, :function_boundary)
    right_expr = Macro.to_string(right)
    # last value is needed. ex: keywords = [value: [value: "nya"]]; keywords[:value][:value]
    [[{r_pos, r_len}]|_t] = Regex.scan(~r/\[#{Regex.escape(right_expr)}\]/, func_call, return: :index)
                            |> Enum.reverse
    match_indexes = Enum.map(match_indexes, fn ([{pos, _len}]) -> [{pos + r_pos, r_len}] end)
    positions = insert_pos_unless_exist(positions, match_indexes, func_call)
    {ast, {code, positions, in_fn}}
  end
  # ex:
  # map = %{value: "nya-"}; map.value
  #                             ^
  #
  # List.first([1,2,3])
  #      ^
  defp collect_position({{:., _, [_l, r_atom]}, _, _} = ast, {_code, _positions, in_fn} = acc) when is_atom(r_atom) and in_fn > 0, do: {ast, acc}
  defp collect_position({{:., _, [_l, r_atom]}, _, _} = ast, {code, positions, in_fn} = _acc) when is_atom(r_atom) do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, code, :function_boundary)
    right_func_name = Atom.to_string(r_atom)
    # last value is needed. ex: map = %{value: %{value: "nya"}}; map.value.value
    [[{r_pos, r_len}]|_t] = Regex.scan(~r/(?!\.)#{Regex.escape(right_func_name)}/, func_call, return: :index)
                            |> Enum.reverse
    match_indexes = Enum.map(match_indexes, fn ([{pos, _len}]) -> [{pos + r_pos, r_len}] end)
    positions = insert_pos_unless_exist(positions, match_indexes, func_call)
    {ast, {code, positions, in_fn}}
  end
  # ex:
  # func = fn () -> "nya-" end; func.()
  #                                  ^
  defp collect_position({{:., _, [_l]}, _, _} = ast, {_code, _positions, in_fn} = acc) when in_fn > 0, do: {ast, acc}
  defp collect_position({{:., _, [l]}, _, _} = ast, {code, positions, in_fn} = _acc) do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, code, :function_boundary)
    length = Macro.to_string(l) |> String.length
    match_indexes = Enum.map(match_indexes, fn ([{pos, len}]) -> [{pos + length + 1, len}] end)
    positions = insert_pos_unless_exist(positions, match_indexes, func_call)
    {ast, {code, positions, in_fn}}
  end
  # ex:
  # x + y
  #   ^
  @arithmetic_ops [:*, :+, :-, :/, :++, :--]
  defp collect_position({op, _, [_l, _r]} = ast, {_code, _positions, in_fn} = acc) when op in @arithmetic_ops and in_fn > 0, do: {ast, acc}
  defp collect_position({op, _, [l, _r]} = ast, {code, positions, in_fn} = _acc) when op in @arithmetic_ops do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, code, :function_boundary)
    left_expr_len = Macro.to_string(l) |> String.length
    op_len = Atom.to_string(op) |> String.length
    match_indexes = Enum.map(match_indexes, fn ([{pos, _len}]) -> [{pos + left_expr_len + 1, op_len}] end)
    positions = insert_pos_unless_exist(positions, match_indexes, func_call)
    {ast, {code, positions, in_fn}}
  end
  # ex:
  # fn(x) -> x == 1 end.(2)
  # @module_attribute
  defp collect_position({atom, _, _args} = ast, {code, positions, in_fn} = _acc) when atom in @ignored_atoms do
    if atom == :@ and in_fn == 1 do
      func_code = Macro.to_string(ast)
      match_indexes = match_indexes_in_code(func_code, code, :function)
      positions = insert_pos_unless_exist(positions, match_indexes, func_code)
      {ast, {code, positions, in_fn - 1}}
    else
      {ast, {code, positions, in_fn - 1}}
    end
  end
  # ex:
  # disregard inner ast
  # quote do: :hoge
  # ^
  defp collect_position({func, _, _args} = ast, {code, positions, in_fn} = _acc) when func in @unsupported_func do
    if in_fn == 1 do
      func_code = Macro.to_string(ast)
      match_indexes = match_indexes_in_code(func_code, code, :function)
      positions = insert_pos_unless_exist(positions, match_indexes, func_code)
      {ast, {code, positions, in_fn - 1}}
    else
      {ast, {code, positions, in_fn - 1}}
    end
  end
  # ex:
  # get_and_update_in/2, put_in/2, update_in/2, for needs special format for first argument
  defp collect_position({func, _, [_, _]} = ast, {code, positions, in_fn} = _acc) when func in @unsupported_func_arity2 do
    if in_fn == 1 do
      func_code = Macro.to_string(ast)
      match_indexes = match_indexes_in_code(func_code, code, :function)
      positions = insert_pos_unless_exist(positions, match_indexes, func_code)
      {ast, {code, positions, in_fn - 1}}
    else
      {ast, {code, positions, in_fn - 1}}
    end
  end
  # ex:
  # import List
  # [1, 2] |> first()
  #           ^
  defp collect_position({func, _, args} = ast, {code, positions, in_fn} = acc) when not func in @ignore_ops and is_atom(func) and is_list(args) and in_fn > 0 do
    case Atom.to_string(func) do
      # not supported sigils
      <<"sigil_", _name>> ->
        {ast, {code, positions, in_fn - 1}}
      _ ->
        {ast, acc}
    end
  end
  defp collect_position({func, _, args} = ast, {code, positions, in_fn}) when not func in @ignore_ops and is_atom(func) and is_list(args) do
    func_code = Macro.to_string(ast)
    matches = Regex.scan(~r/(?<!\.)#{Regex.escape(func_code)}/, code, return: :index)
    positions = insert_pos_unless_exist(positions, matches, func_code)
    {ast, {code, positions, in_fn}}
  end
  # ex:
  # x == y
  # ^    ^
  #
  # List.first(values)
  #            ^
  defp collect_position({variable, _, el} = ast, {_code, _positions, in_fn} = acc) when is_atom(variable) and is_atom(el) and in_fn > 0, do: {ast, acc}
  defp collect_position({variable, _, el} = ast, {code, positions, in_fn} = _acc) when is_atom(variable) and is_atom(el) do
    code_fragment = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(code_fragment, code, :variable)
    positions = insert_pos_unless_exist(positions, match_indexes, code_fragment)
    {ast, {code, positions, in_fn}}
  end
  defp collect_position(ast, acc), do: {ast, acc}

  defp match_indexes_in_code(code_fragment, code, :function_boundary) do
    Regex.scan(~r/\b#{Regex.escape(code_fragment)}/, code, return: :index)
  end
  defp match_indexes_in_code(code_fragment, code, :function) do
    Regex.scan(~r/#{Regex.escape(code_fragment)}/, code, return: :index)
  end
  defp match_indexes_in_code(code_fragment, code, :variable) do
    Regex.scan(~r/(?<!\.)\b#{code_fragment}\b/, code, return: :index)
  end

  defp insert_pos_unless_exist(positions, [], _code) do
    positions
  end
  defp insert_pos_unless_exist(positions, matches, code) do
    [h | tail] = matches
    {pos, _} = List.first(h)
    if Enum.find(positions, fn([p, _code]) -> p == pos end) do
      insert_pos_unless_exist(positions, tail, code)
    else
      List.insert_at(positions, 0, [pos, code])
    end
  end


  ## injection
  defp inject_first_argument({:__block__, block_meta, [first, second, third]} = _ast) do
    ast_for_inject = {:l_value, [], PowerAssert.Assertion}
    {:=, meta, [v, {func_call, func_meta, func_args}]} = first
    injected_first_arg_ast = {:=, meta, [v, {func_call, func_meta, List.insert_at(func_args || [], 0, ast_for_inject)}]}
    {:inject, {:__block__, block_meta, [injected_first_arg_ast, second, third]}}
  end
  defp inject_first_argument(ast) do
    {:none, ast}
  end

  defp pre_catcher({atom, _, _args} = ast, {pos, in_fn} = _acc) when atom in @ignored_atoms do
    {ast, {pos, in_fn + 1}}
  end
  defp pre_catcher({func, _, _args} = ast, {pos, in_fn} = _acc) when func in @unsupported_func do
    {ast, {pos, in_fn + 1}}
  end
  defp pre_catcher({func, _, [_, _]} = ast, {pos, in_fn} = _acc) when func in @unsupported_func_arity2 do
    {ast, {pos, in_fn + 1}}
  end
  defp pre_catcher({func, _, args} = ast, {pos, in_fn} = acc) when not func in @ignore_ops and is_atom(func) and is_list(args) do
    case Atom.to_string(func) do
      <<"sigil_", _name>> ->
        {ast, {pos, in_fn + 1}}
      _ ->
        {ast, acc}
    end
  end
  defp pre_catcher(ast, acc) do
    {ast, acc}
  end

  defp store_value_ast(ast, pos) do
    quote do
      v = unquote(ast)
      Agent.update(buffer, &[[unquote(pos), v] | &1])
      v
    end
  end

  defp catcher({:|>, _meta, [_l, _r]} = ast, {_pos, in_fn} = acc) when in_fn > 0, do: {ast, acc}
  defp catcher({:|>, _meta, [l, r]}, acc) do
    {res, r_ast} = inject_first_argument(r)
    ast = if res == :inject do
            quote do
              l_value = unquote(l)
              unquote(r_ast)
            end
          else
            quote do
              unquote(l) |> unquote(r_ast)
            end
          end
    {ast, acc}
  end
  defp catcher({{:., _, [Access, :get]}, _, [_l, _r]} = ast, {_pos, in_fn} = acc) when in_fn > 0, do: {ast, acc}
  defp catcher({{:., _, [Access, :get]}, _, [_l, _r]} = ast, {[[pos, _]|t], in_fn}) do
    {store_value_ast(ast, pos), {t, in_fn}}
  end
  defp catcher({{:., _, [_l, r_atom]}, _meta, _} = ast, {_pos, in_fn} = acc) when is_atom(r_atom) and in_fn > 0, do: {ast, acc}
  defp catcher({{:., _, [_l, r_atom]}, _meta, _} = ast, {[[pos, _]|t], in_fn}) when is_atom(r_atom) do
    {store_value_ast(ast, pos), {t, in_fn}}
  end
  defp catcher({{:., _, [_l]}, _, _} = ast, {_pos, in_fn} = acc) when in_fn > 0, do: {ast, acc}
  defp catcher({{:., _, [_l]}, _, _} = ast, {[[pos, _]|t], in_fn}) do
    {store_value_ast(ast, pos), {t, in_fn}}
  end
  defp catcher({op, _, [_l, _r]} = ast, {_pos, in_fn} = acc) when op in @arithmetic_ops and in_fn > 0, do: {ast, acc}
  defp catcher({op, _, [_l, _r]} = ast, {[[pos, _]|t], in_fn}) when op in @arithmetic_ops do
    {store_value_ast(ast, pos), {t, in_fn}}
  end
  defp catcher({atom, _, _args} = ast, {[h|t], in_fn} = _acc) when atom in @ignored_atoms do
    if atom == :@ and in_fn == 1 do
      [pos, _] = h
      {store_value_ast(ast, pos), {t, in_fn - 1}}
    else
      {ast, {[h|t], in_fn - 1}}
    end
  end
  defp catcher({func, _, _args} = ast, {[h|t], in_fn} = _acc) when func in @unsupported_func do
    if in_fn == 1 do
      [pos, _] = h
      {store_value_ast(ast, pos), {t, in_fn - 1}}
    else
      {ast, {[h|t], in_fn - 1}}
    end
  end
  defp catcher({func, _, [_, _]} = ast, {[h|t], in_fn} = _acc) when func in @unsupported_func_arity2 do
    if in_fn == 1 do
      [pos, _] = h
      {store_value_ast(ast, pos), {t, in_fn - 1}}
    else
      {ast, {[h|t], in_fn - 1}}
    end
  end
  defp catcher({func, _, args} = ast, {[h|t], in_fn} = acc) when not func in @ignore_ops and is_atom(func) and is_list(args) and in_fn > 0 do
    case Atom.to_string(func) do
      <<"sigil_", _name>> ->
        {ast, {[h|t], in_fn - 1}}
      _ ->
        {ast, acc}
    end
  end
  defp catcher({func, _, args} = ast, {[[pos, _]|t], in_fn}) when not func in @ignore_ops and is_atom(func) and is_list(args) do
    {store_value_ast(ast, pos), {t, in_fn}}
  end
  defp catcher({variable, _, el} = ast, {_pos, in_fn} = acc) when is_atom(variable) and is_atom(el) and in_fn > 0, do: {ast, acc}
  defp catcher({variable, _, el} = ast, {[[pos, _]|t], in_fn}) when is_atom(variable) and is_atom(el) do
    {store_value_ast(ast, pos), {t, in_fn}}
  end
  defp catcher(ast, acc), do: {ast, acc}


  ## render
  def render_values(code, values, left \\ nil, right \\ nil)
  def render_values(code, [], left, right) do
    Macro.to_string(code) <> extra_information(left, right)
  end
  def render_values(code, values, left, right) do
    code_str = Macro.to_string(code)
    values = Enum.sort(values, fn([x_pos, _], [y_pos, _]) -> x_pos > y_pos end)
    [max_pos, _] = Enum.max_by(values, fn ([pos, _]) ->  pos end)
    first_line = String.duplicate(" ", max_pos + 1) |> replace_with_bar(values)
    lines = make_lines([], Enum.count(values), values, -1)
    Enum.join([code_str, first_line] ++ lines, "\n") <> extra_information(left, right)
  end

  defp make_lines(lines, 0, _, _latest_pos) do
    lines
  end
  defp make_lines(lines, times, values, latest_pos) do
    [[pos, value]|t] = values
    value = inspect(value)
    value_len = String.length(value)
    if latest_pos != -1 && latest_pos - (pos + value_len) > 0 do
      [last_line|tail_lines] = lines |> Enum.reverse
      {before_str, after_str} = String.split_at(last_line, pos)
      {_removed_str, after_str} = String.split_at(after_str, value_len)
      line = before_str <> value <> after_str
      lines = [line|tail_lines] |> Enum.reverse
    else
      line = String.duplicate(" ", pos + 1)
      line = replace_with_bar(line, values)
      line = String.replace(line, ~r/\|$/, value)
      lines = lines ++ [line]
    end
    make_lines(lines, times - 1, t, pos)
  end

  defp replace_with_bar(line, values) do
    Enum.reduce(values, line, fn ([pos, _value], line) ->
      {front, back} = String.split_at(line, pos + 1)
      String.replace(front, ~r/ $/, "|") <> back
    end)
  end

  defp extra_information(left, right) when is_list(left) and is_list(right) do
    ["\n\nonly in lhs: " <> ((left -- right) |> inspect),
     "only in rhs: " <> ((right -- left) |> inspect)]
    |> Enum.join("\n")
  end
  defp extra_information(left, right) when is_map(left) and is_map(right) do
    if Map.has_key? left, :__struct__ do
      left = Map.from_struct(left)
      right = Map.from_struct(right)
    end
    in_left = Map.split(left, Map.keys(right)) |> elem(1)
    in_right = Map.split(right, Map.keys(left)) |> elem(1)
    str = "\n"
    unless Map.size(in_left) == 0 do
      str = str <> "\nonly in lhs: " <> inspect(in_left)
    end
    unless Map.size(in_right) == 0 do
      str = str <> "\nonly in rhs: " <> inspect(in_right)
    end
    diff = collect_map_diff(left, right)
    unless Enum.empty?(diff) do
      str = str <> "\ndifference:\n" <> Enum.join(diff, "\n")
    end
    str
  end
  defp extra_information(_left, _right), do: ""

  defp collect_map_diff(map1, map2) do
    Enum.reduce(map2, [], fn({k, v}, acc) ->
      case Map.fetch(map1, k) do
        {:ok, ^v} -> acc
        {:ok, map1_value} ->
          acc ++ ["key #{inspect k} => {#{inspect map1_value}, #{inspect v}}"]
        _ -> acc
      end
    end)
  end
end
