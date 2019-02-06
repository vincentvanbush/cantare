ExUnit.start(timeout: 999_999_999)

defmodule TestUtils do
  def query_equals(q1, q2) do
    # TODO: It is likely that it's not only going to involve wheres - see joins, havings, etc.
    w1 = q1.wheres
    w2 = q2.wheres

    filter_locations = fn wheres ->
      wheres
      |> Enum.map(fn where ->
        where |> Map.drop([:file, :line])
      end)
    end

    filter_locations.(w1) == filter_locations.(w2)
  end
end

# Module redefinition warnings are no good in tests - redefining modules using
# macros is quite handy, so let's swallow this warning whatsoever.
Code.compiler_options(ignore_module_conflict: true)
