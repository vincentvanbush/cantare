defmodule Cantare.Abilities do
  @spec can(atom() | {atom(), nonempty_maybe_improper_list()}, atom(), module(), fun()) ::
          {atom(), nonempty_maybe_improper_list()}
  def can(entity_module, action, object_module, matcher)
      when is_atom(action) and is_atom(object_module) and is_atom(entity_module) and
             is_function(matcher) do
    {entity_module, [{action, object_module, matcher}]}
  end

  def can({entity_module, [_ | _] = action_matcher_list}, action, object_module, matcher)
      when is_atom(action) and is_atom(object_module) and is_atom(entity_module) and
             is_function(matcher) do
    {entity_module, [{action, object_module, matcher} | action_matcher_list]}
  end

  @spec can?(%{__struct__: any()}, atom(), any(), %{__struct__: any()}, [
          {:abilities, {any(), any()}},
          ...
        ]) :: boolean()
  def can?(
        %{:__struct__ => subject_schema} = subject,
        action,
        object_schema,
        %{:__struct__ => object_schema} = object,
        abilities: {subject_schema, [_ | _] = ability_list},
        repo: repo
      )
      when is_atom(action) do
    ability_list
    |> Enum.filter(fn {act, sch, _} ->
      action == act && sch == object_schema
    end)
    |> Enum.all?(fn {_, _, matcher} ->
      cond do
        is_function(matcher, 2) ->
          matcher.(subject, object)

        is_function(matcher, 1) ->
          condition_list = matcher.(subject)

          # awkward anonymous function recursion, but there you go...
          resolve_keyword = fn f, obj ->
            fn {field, expected_val} ->
              case expected_val do
                list when is_list(expected_val) ->
                  new_obj_ptr =
                    case Map.get(obj, field) do
                      %Ecto.Association.NotLoaded{} ->
                        # preload stuff, use a repo
                        Map.get(obj |> repo.preload(field), field)

                      _ ->
                        Map.get(obj, field)
                    end

                  Enum.all?(list, f.(f, new_obj_ptr))

                _ ->
                  Map.get(obj, field) == expected_val
              end
            end
          end

          condition_list |> Enum.all?(resolve_keyword.(resolve_keyword, object))

        true ->
          {:error, "wtf"}
      end
    end)
  end

  @spec can?(%{__struct__: any()}, atom(), module(), [{:abilities, {any(), any()}}, ...]) ::
          boolean()
  def can?(
        %{:__struct__ => subject_schema} = _subject,
        action,
        object_schema,
        abilities: {subject_schema, [_ | _] = ability_list}
      )
      when is_atom(action) do
    ability_list
    |> Enum.any?(fn {act, sch, _} -> action == act && sch == object_schema end)
  end

  defmacro __using__(opts) do
    quote do
      import Ecto.Query, only: [from: 2]

      def can?(
            %{:__struct__ => subject_schema} = subject,
            action,
            %{:__struct__ => object_schema} = object
          ) do
        Cantare.Abilities.can?(subject, action, object_schema, object,
          abilities: __MODULE__.abilities(subject_schema),
          repo: unquote(opts[:repo])
        )
      end

      def can?(
            %{:__struct__ => subject_schema} = subject,
            action,
            object_schema
          )
          when is_atom(object_schema) do
        Cantare.Abilities.can?(subject, action, object_schema,
          abilities: __MODULE__.abilities(subject_schema)
        )
      end

      # TODO: This method only filters records after they've been fetched.
      # This might sometimes be fine, but we still probably need a cancan-like
      # mechanism that lets users specify requirements with a keyword list
      # which is then converted into a function that can be either passed
      # to Ecto queries or used on single objects.
      def accessible_post_filter(
            %{:__struct__ => subject_schema} = subject,
            action,
            record_list
          )
          when is_list(record_list) do
        Enum.filter(record_list, fn elem ->
          subject |> __MODULE__.can?(action, elem)
        end)
      end

      require IEx

      def accessible_query(
            query_schema,
            %{:__struct__ => subject_schema} = subject,
            action
          )
          when is_atom(query_schema) do
        accessible_query(
          from(query_schema, []),
          subject,
          action
        )
      end

      def accessible_query(
            %Ecto.Query{} = query,
            %{:__struct__ => subject_schema} = subject,
            action
          ) do
        {_, query_schema} =
          case query.from do
            # Ecto 3. Explicit __struct__ resolution is used for compatibility.
            %{__struct__: Ecto.Query.FromExpr, source: source} -> source
            # Ecto 2
            _ -> query.from
          end

        {^subject_schema, ability_list} = __MODULE__.abilities(subject_schema)

        # TODO: Enhance this with the ability to prepare an accessibility query for
        # nested associations using join clauses.

        condition_list =
          ability_list
          |> Enum.filter(fn {act, object_schema, matcher} ->
            act == action && object_schema == query_schema && is_function(matcher, 1)
          end)
          |> Enum.map(fn {_, _, matcher} -> matcher.(subject) end)
          |> List.flatten()

        from(query, where: ^condition_list)
      end
    end
  end
end
