defmodule PowerAssert.Assertion do
  @moduledoc """
  This module handles Power Assert main function
  """

  # length of " = "
  @assign_len 3
  # length of " == "
  @equal_len 4

  @no_warning_annotation (if :erlang.system_info(:otp_release) >= '19' do
                            [generated: true]
                          else
                            [line: -1]
                          end)

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
    [_ | t] = String.split(Macro.to_string(ast), " = ")
    rhs_expr = Enum.join(t, " = ")
    rhs_index = (Macro.to_string(left) |> String.length()) + @assign_len
    injected_rhs_ast = inject_store_code(right, rhs_expr, rhs_index)
    message_ast = message_ast(msg)

    left = Macro.expand(left, __CALLER__)
    vars = collect_vars_from_pattern(left)

    return =
      no_warning(
        quote do
          if right do
            right
          else
            message = PowerAssert.Assertion.render_values(expr, values)
            unquote(message_ast)

            raise ExUnit.AssertionError,
              message: "Expected truthy, got #{inspect(right)}\n\n" <> message
          end
        end
      )

    quote do
      unquote(injected_rhs_ast)
      right = result
      expr = unquote(code)

      unquote(vars) =
        case right do
          unquote(left) ->
            unquote(return)
            unquote(vars)

          _ ->
            message = PowerAssert.Assertion.render_values(expr, values)
            unquote(message_ast)

            raise ExUnit.AssertionError,
              message: message
        end

      right
    end
  end

  defmacro assert({:==, _, [left, right]} = ast, msg) do
    code = Macro.escape(ast)
    [lhs_expr | t] = String.split(Macro.to_string(ast), " == ")
    rhs_expr = Enum.join(t, " == ")
    injected_lhs_ast = inject_store_code(left, lhs_expr)
    rhs_index = (Macro.to_string(left) |> String.length()) + @equal_len
    injected_rhs_ast = inject_store_code(right, rhs_expr, rhs_index)
    message_ast = message_ast(msg)

    quote do
      unquote(injected_lhs_ast)
      left = result
      left_values = values
      unquote(injected_rhs_ast)
      # wrap result for avoid warning: this check/guard will always yield the same result
      unless left == (fn x -> x end).(result) do
        message =
          PowerAssert.Assertion.render_values(unquote(code), left_values ++ values, left, result)

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

  # avoid a warning that "this check/guard will always yield the same result"
  defp message_ast(msg) when is_binary(msg) do
    quote do
      message = "#{unquote(msg)}\n\n" <> message
    end
  end

  defp message_ast(_msg), do: nil

  # structs
  defmodule Detector do
    defstruct code: nil, positions: [], in_fn: 0
  end

  defmodule Injector do
    defstruct positions: nil, in_fn: 0
  end

  @doc false
  def inject_store_code(ast, expr, default_index \\ 0) do
    positions = detect_position(ast, expr, default_index)

    {injected_ast, _} =
      Macro.traverse(
        ast,
        %Injector{positions: Enum.reverse(positions)},
        &pre_catcher/2,
        &catcher/2
      )

    # IO.inspect injected_ast
    # IO.inspect Macro.to_string injected_ast
    quote do
      {:ok, buffer} = Agent.start_link(fn -> [] end)
      result = unquote(injected_ast)
      values = Agent.get(buffer, & &1)
      Agent.stop(buffer)
    end
  end

  ## detect positions
  defp detect_position(ast, expr, default_index) do
    {_ast, %Detector{positions: positions}} =
      Macro.traverse(ast, %Detector{code: expr}, &pre_collect_position/2, &collect_position/2)

    positions =
      if default_index != 0 do
        Enum.map(positions, fn [pos, code] -> [default_index + pos, code] end)
      else
        positions
      end

    positions
  end

  @ignored_atoms [:fn, :&, :=, :"::", :@]
  defp pre_collect_position({atom, _, _args} = ast, detector) when atom in @ignored_atoms do
    {ast, %{detector | in_fn: detector.in_fn + 1}}
  end

  @unsupported_func [:quote, :<<>>, :case]
  defp pre_collect_position({func, _, _args} = ast, detector) when func in @unsupported_func do
    {ast, %{detector | in_fn: detector.in_fn + 1}}
  end

  @unsupported_func_arity2 [:put_in, :get_and_update_in, :update_in, :for, :match?]
  # get_and_update_in/2, put_in/2, update_in/2, for
  defp pre_collect_position({func, _, [_, _]} = ast, detector)
       when func in @unsupported_func_arity2 do
    {ast, %{detector | in_fn: detector.in_fn + 1}}
  end

  @ignore_ops [
    :.,
    :__aliases__,
    :|>,
    :==,
    :!=,
    :<,
    :>,
    :>=,
    :<=,
    :*,
    :||,
    :&&,
    :<>,
    :===,
    :!==,
    :and,
    :or,
    :=~,
    :%{},
    :%,
    :->,
    :|,
    :{}
  ]
  defp pre_collect_position({func, _, args} = ast, detector)
       when not (func in @ignore_ops) and is_atom(func) and is_list(args) do
    case Atom.to_string(func) do
      <<"sigil_", _name>> ->
        {ast, %{detector | in_fn: detector.in_fn + 1}}

      _ ->
        {ast, detector}
    end
  end

  defp pre_collect_position(ast, detector) do
    {ast, detector}
  end

  # ex:
  # context[:key]
  #        ^
  defp collect_position(
         {{:., _, [Access, :get]}, _, [_l, _r]} = ast,
         %Detector{in_fn: in_fn} = detector
       )
       when in_fn > 0,
       do: {ast, detector}

  defp collect_position({{:., _, [Access, :get]}, _, [_l, right]} = ast, detector) do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, detector.code, :function_boundary)
    right_expr = Macro.to_string(right)
    # last value is needed. ex: keywords = [value: [value: "nya"]]; keywords[:value][:value]
    [[{r_pos, r_len}] | _t] =
      Regex.scan(~r/\[#{Regex.escape(right_expr)}\]/, func_call, return: :index)
      |> Enum.reverse()

    match_indexes = Enum.map(match_indexes, fn [{pos, _len}] -> [{pos + r_pos, r_len}] end)
    positions = insert_pos_unless_exist(detector.positions, match_indexes, func_call)
    {ast, %{detector | positions: positions}}
  end

  # ex:
  # map = %{value: "nya-"}; map.value
  #                             ^
  #
  # List.first([1,2,3])
  #      ^
  defp collect_position({{:., _, [_l, r_atom]}, _, _} = ast, %Detector{in_fn: in_fn} = detector)
       when is_atom(r_atom) and in_fn > 0,
       do: {ast, detector}

  defp collect_position({{:., _, [_l, r_atom]}, _, _} = ast, detector) when is_atom(r_atom) do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, detector.code, :function_boundary)
    right_func_name = Atom.to_string(r_atom)
    # last value is needed. ex: map = %{value: %{value: "nya"}}; map.value.value
    [[{r_pos, r_len}] | _t] =
      Regex.scan(~r/(?!\.)#{Regex.escape(right_func_name)}/, func_call, return: :index)
      |> Enum.reverse()

    match_indexes = Enum.map(match_indexes, fn [{pos, _len}] -> [{pos + r_pos, r_len}] end)
    positions = insert_pos_unless_exist(detector.positions, match_indexes, func_call)
    {ast, %{detector | positions: positions}}
  end

  # ex:
  # func = fn () -> "nya-" end; func.()
  #                                  ^
  defp collect_position({{:., _, [_l]}, _, _} = ast, %Detector{in_fn: in_fn} = detector)
       when in_fn > 0,
       do: {ast, detector}

  defp collect_position({{:., _, [l]}, _, _} = ast, detector) do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, detector.code, :function_boundary)
    length = function_expression(l) |> String.length()
    match_indexes = Enum.map(match_indexes, fn [{pos, len}] -> [{pos + length + 1, len}] end)
    positions = insert_pos_unless_exist(detector.positions, match_indexes, func_call)
    {ast, %{detector | positions: positions}}
  end

  # ex:
  # x + y
  #   ^
  @arithmetic_ops [:*, :+, :-, :/, :++, :--]
  defp collect_position({op, _, [_l, _r]} = ast, %Detector{in_fn: in_fn} = detector)
       when op in @arithmetic_ops and in_fn > 0,
       do: {ast, detector}

  defp collect_position({op, _, [l, _r]} = ast, detector) when op in @arithmetic_ops do
    func_call = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(func_call, detector.code, :function_boundary)
    left_expr_len = Macro.to_string(l) |> String.length()
    op_len = Atom.to_string(op) |> String.length()

    match_indexes =
      Enum.map(match_indexes, fn [{pos, _len}] -> [{pos + left_expr_len + 1, op_len}] end)

    positions = insert_pos_unless_exist(detector.positions, match_indexes, func_call)
    {ast, %{detector | positions: positions}}
  end

  # ex:
  # fn(x) -> x == 1 end.(2)
  # @module_attribute
  defp collect_position({atom, _, _args} = ast, detector) when atom in @ignored_atoms do
    if atom == :@ and detector.in_fn == 1 do
      func_code = Macro.to_string(ast)
      match_indexes = match_indexes_in_code(func_code, detector.code, :function)
      positions = insert_pos_unless_exist(detector.positions, match_indexes, func_code)
      {ast, %{detector | positions: positions, in_fn: detector.in_fn - 1}}
    else
      {ast, %{detector | in_fn: detector.in_fn - 1}}
    end
  end

  # ex:
  # disregard inner ast
  # quote do: :hoge
  # ^
  defp collect_position({func, _, _args} = ast, detector) when func in @unsupported_func do
    if detector.in_fn == 1 do
      func_code = Macro.to_string(ast)
      match_indexes = match_indexes_in_code(func_code, detector.code, :function)
      positions = insert_pos_unless_exist(detector.positions, match_indexes, func_code)
      {ast, %{detector | positions: positions, in_fn: detector.in_fn - 1}}
    else
      {ast, %{detector | in_fn: detector.in_fn - 1}}
    end
  end

  # ex:
  # get_and_update_in/2, put_in/2, update_in/2, for needs special format for first argument
  defp collect_position({func, _, [_, _]} = ast, detector)
       when func in @unsupported_func_arity2 do
    if detector.in_fn == 1 do
      func_code = Macro.to_string(ast)
      match_indexes = match_indexes_in_code(func_code, detector.code, :function)
      positions = insert_pos_unless_exist(detector.positions, match_indexes, func_code)
      {ast, %{detector | positions: positions, in_fn: detector.in_fn - 1}}
    else
      {ast, %{detector | in_fn: detector.in_fn - 1}}
    end
  end

  # ex:
  # import List
  # [1, 2] |> first()
  #           ^
  defp collect_position({func, _, args} = ast, %Detector{in_fn: in_fn} = detector)
       when not (func in @ignore_ops) and is_atom(func) and is_list(args) and in_fn > 0 do
    case Atom.to_string(func) do
      # not supported sigils
      <<"sigil_", _name>> ->
        {ast, %{detector | in_fn: detector.in_fn - 1}}

      _ ->
        {ast, detector}
    end
  end

  defp collect_position({func, _, args} = ast, detector)
       when not (func in @ignore_ops) and is_atom(func) and is_list(args) do
    func_code = Macro.to_string(ast)
    matches = Regex.scan(~r/(?<!\.)#{Regex.escape(func_code)}/, detector.code, return: :index)
    positions = insert_pos_unless_exist(detector.positions, matches, func_code)
    {ast, %{detector | positions: positions}}
  end

  # ex:
  # x == y
  # ^    ^
  #
  # List.first(values)
  #            ^
  defp collect_position({variable, _, el} = ast, %Detector{in_fn: in_fn} = detector)
       when is_atom(variable) and is_atom(el) and in_fn > 0,
       do: {ast, detector}

  defp collect_position({variable, _, el} = ast, detector)
       when is_atom(variable) and is_atom(el) do
    code_fragment = Macro.to_string(ast)
    match_indexes = match_indexes_in_code(code_fragment, detector.code, :variable)
    positions = insert_pos_unless_exist(detector.positions, match_indexes, code_fragment)
    {ast, %{detector | positions: positions}}
  end

  defp collect_position(ast, detector), do: {ast, detector}

  defp match_indexes_in_code(code_fragment, code, :function_boundary) do
    Regex.scan(~r/#{Regex.escape(code_fragment)}/, code, return: :index)
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

    if Enum.find(positions, fn [p, _code] -> p == pos end) do
      insert_pos_unless_exist(positions, tail, code)
    else
      List.insert_at(positions, 0, [pos, code])
    end
  end

  defp function_expression({:fn, _, _args} = left_ast) do
    "(#{Macro.to_string(left_ast)})"
  end

  defp function_expression(left_ast) do
    Macro.to_string(left_ast)
  end

  ## injection
  defp inject_first_argument({:__block__, block_meta, [first, second, third]} = _ast) do
    ast_for_inject = {:l_value, [], PowerAssert.Assertion}
    {:=, meta, [v, {func_call, func_meta, func_args}]} = first

    injected_first_arg_ast =
      {:=, meta, [v, {func_call, func_meta, List.insert_at(func_args || [], 0, ast_for_inject)}]}

    {:inject, {:__block__, block_meta, [injected_first_arg_ast, second, third]}}
  end

  defp inject_first_argument(ast) do
    {:none, ast}
  end

  defp pre_catcher({atom, _, _args} = ast, injector) when atom in @ignored_atoms do
    {ast, %{injector | in_fn: injector.in_fn + 1}}
  end

  defp pre_catcher({func, _, _args} = ast, injector) when func in @unsupported_func do
    {ast, %{injector | in_fn: injector.in_fn + 1}}
  end

  defp pre_catcher({func, _, [_, _]} = ast, injector) when func in @unsupported_func_arity2 do
    {ast, %{injector | in_fn: injector.in_fn + 1}}
  end

  defp pre_catcher({func, _, args} = ast, injector)
       when not (func in @ignore_ops) and is_atom(func) and is_list(args) do
    case Atom.to_string(func) do
      <<"sigil_", _name>> ->
        {ast, %{injector | in_fn: injector.in_fn + 1}}

      _ ->
        {ast, injector}
    end
  end

  defp pre_catcher(ast, injector) do
    {ast, injector}
  end

  defp store_value_ast(ast, pos) do
    quote do
      v = unquote(ast)
      Agent.update(buffer, &[[unquote(pos), v] | &1])
      v
    end
  end

  defp catcher({:|>, _meta, [_l, _r]} = ast, %Injector{in_fn: in_fn} = injector) when in_fn > 0,
    do: {ast, injector}

  defp catcher({:|>, _meta, [l, r]}, injector) do
    {res, r_ast} = inject_first_argument(r)

    ast =
      if res == :inject do
        quote do
          l_value = unquote(l)
          unquote(r_ast)
        end
      else
        quote do
          unquote(l) |> unquote(r_ast)
        end
      end

    {ast, injector}
  end

  defp catcher({{:., _, [Access, :get]}, _, [_l, _r]} = ast, %Injector{in_fn: in_fn} = injector)
       when in_fn > 0,
       do: {ast, injector}

  defp catcher(
         {{:., _, [Access, :get]}, _, [_l, _r]} = ast,
         %Injector{positions: [[pos, _] | t]} = injector
       ) do
    {store_value_ast(ast, pos), %{injector | positions: t}}
  end

  defp catcher({{:., _, [_l, r_atom]}, _meta, _} = ast, %Injector{in_fn: in_fn} = injector)
       when is_atom(r_atom) and in_fn > 0,
       do: {ast, injector}

  defp catcher(
         {{:., _, [_l, r_atom]}, _meta, _} = ast,
         %Injector{positions: [[pos, _] | t]} = injector
       )
       when is_atom(r_atom) do
    {store_value_ast(ast, pos), %{injector | positions: t}}
  end

  defp catcher({{:., _, [_l]}, _, _} = ast, %Injector{in_fn: in_fn} = injector) when in_fn > 0,
    do: {ast, injector}

  defp catcher({{:., _, [_l]}, _, _} = ast, %Injector{positions: [[pos, _] | t]} = injector) do
    {store_value_ast(ast, pos), %{injector | positions: t}}
  end

  defp catcher({op, _, [_l, _r]} = ast, %Injector{in_fn: in_fn} = injector)
       when op in @arithmetic_ops and in_fn > 0,
       do: {ast, injector}

  defp catcher({op, _, [_l, _r]} = ast, %Injector{positions: [[pos, _] | t]} = injector)
       when op in @arithmetic_ops do
    {store_value_ast(ast, pos), %{injector | positions: t}}
  end

  defp catcher({atom, _, _args} = ast, %Injector{positions: [h | t]} = injector)
       when atom in @ignored_atoms do
    if atom == :@ and injector.in_fn == 1 do
      [pos, _] = h
      {store_value_ast(ast, pos), %{injector | positions: t, in_fn: injector.in_fn - 1}}
    else
      {ast, %{injector | in_fn: injector.in_fn - 1}}
    end
  end

  defp catcher({func, _, _args} = ast, %Injector{positions: [h | t]} = injector)
       when func in @unsupported_func do
    if injector.in_fn == 1 do
      [pos, _] = h
      {store_value_ast(ast, pos), %{injector | positions: t, in_fn: injector.in_fn - 1}}
    else
      {ast, %{injector | in_fn: injector.in_fn - 1}}
    end
  end

  defp catcher({func, _, [_, _]} = ast, %Injector{positions: [h | t]} = injector)
       when func in @unsupported_func_arity2 do
    if injector.in_fn == 1 do
      [pos, _] = h
      {store_value_ast(ast, pos), %{injector | positions: t, in_fn: injector.in_fn - 1}}
    else
      {ast, %{injector | in_fn: injector.in_fn - 1}}
    end
  end

  defp catcher({func, _, args} = ast, %Injector{positions: [_h | _t], in_fn: in_fn} = injector)
       when not (func in @ignore_ops) and is_atom(func) and is_list(args) and in_fn > 0 do
    case Atom.to_string(func) do
      <<"sigil_", _name>> ->
        {ast, %{injector | in_fn: injector.in_fn - 1}}

      _ ->
        {ast, injector}
    end
  end

  defp catcher({func, _, args} = ast, %Injector{positions: [[pos, _] | t]} = injector)
       when not (func in @ignore_ops) and is_atom(func) and is_list(args) do
    {store_value_ast(ast, pos), %{injector | positions: t}}
  end

  defp catcher({variable, _, el} = ast, %Injector{in_fn: in_fn} = injector)
       when is_atom(variable) and is_atom(el) and in_fn > 0,
       do: {ast, injector}

  defp catcher({variable, _, el} = ast, %Injector{positions: [[pos, _] | t]} = injector)
       when is_atom(variable) and is_atom(el) do
    {store_value_ast(ast, pos), %{injector | positions: t}}
  end

  defp catcher(ast, injector), do: {ast, injector}

  ## render
  def render_values(code, values, left \\ nil, right \\ nil)

  def render_values(code, [], left, right) do
    Macro.to_string(code) <> extra_information(left, right)
  end

  def render_values(code, values, left, right) do
    code_str = Macro.to_string(code)
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

  defp collect_vars_from_pattern(expr) do
    {_, vars} =
      Macro.prewalk(expr, [], fn
        {:"::", _, [left, _]}, acc ->
          {[left], acc}

        {skip, _, [_]}, acc when skip in [:^, :@] ->
          {:ok, acc}

        {:_, _, context}, acc when is_atom(context) ->
          {:ok, acc}

        {name, _, context}, acc when is_atom(name) and is_atom(context) ->
          {:ok, [{name, [generated: true], context} | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(vars)
  end

  defp no_warning({name, meta, args}) do
    {name, @no_warning_annotation ++ meta, args}
  end
end
