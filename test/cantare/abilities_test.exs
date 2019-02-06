defmodule Cantare.AbilitiesTest do
  use ExUnit.Case
  require Ecto.Query

  import TestUtils

  defmodule Breed do
    use Ecto.Schema

    schema "breed" do
      has_many(:pigs, Pig)

      field(:name, :string)
    end
  end

  defmodule Pig do
    use Ecto.Schema

    schema "pigs" do
      has_many(:sheeps, Sheep)
      belongs_to(:breed, Breed)

      field(:role, :string)
    end
  end

  defmodule Sheep do
    use Ecto.Schema

    schema "sheeps" do
      belongs_to(:pig, Pig)
    end
  end

  # This is a fake Repo that mimics Ecto behavior of association preloading for
  # records.
  defmodule FakeRepo do
    def preload(obj, assoc) do
      case obj do
        %Pig{id: 1} ->
          %Pig{obj | breed: %Breed{name: "Berkshire Boar", id: 2}}

        %Pig{id: 2} ->
          %Pig{obj | breed: %Breed{name: "Mangalica", id: 1}}

        %Pig{id: 3} ->
          %Pig{obj | breed: %Breed{name: "Mangalica", id: 1}}
      end
    end
  end

  defmacro define_pig_abilities(context \\ %{}, do: block) do
    quote do
      {:module, module_name, _, _} =
        defmodule AnimalFarm.Abilities do
          use Cantare.Abilities, repo: Cantare.AbilitiesTest.FakeRepo

          def abilities(Pig) do
            unquote(block)
          end
        end

      {
        :ok,
        Map.put(unquote(context), :ability_module, module_name)
      }
    end
  end

  defmacro define_sheep_abilities(context \\ %{}, do: block) do
    quote do
      {:module, module_name, _, _} =
        defmodule AnimalFarm.Abilities do
          use Cantare.Abilities, repo: Cantare.AbilitiesTest.FakeRepo

          def abilities(Sheep) do
            unquote(block)
          end
        end

      {
        :ok,
        Map.put(unquote(context), :ability_module, module_name)
      }
    end
  end

  setup [:prepare_pigs]

  describe "with a basic set of abilities given on Pig" do
    setup context do
      context
      |> define_pig_abilities do
        Pig
        |> Cantare.Abilities.can(:judge, Pig, fn pig, other_pig -> pig.id < other_pig.id end)
      end
    end

    test "can?", %{
      napoleon: napoleon,
      squealer: squealer,
      piglet: piglet,
      ability_module: ability_module
    } do
      assert(napoleon |> ability_module.can?(:judge, squealer))
      assert(napoleon |> ability_module.can?(:judge, piglet))
      assert(squealer |> ability_module.can?(:judge, piglet))
      refute(piglet |> ability_module.can?(:judge, squealer))
      refute(piglet |> ability_module.can?(:judge, napoleon))
      refute(squealer |> ability_module.can?(:judge, napoleon))
    end
  end

  describe "with a set of abilities given on Pig as Ecto keyword list" do
    setup context do
      context
      |> define_pig_abilities do
        Pig |> Cantare.Abilities.can(:view, Pig, fn current_pig -> [role: current_pig.role] end)
      end
    end

    test "can?/3", %{
      napoleon: napoleon,
      squealer: squealer,
      piglet: piglet,
      ability_module: ability_module
    } do
      assert(napoleon |> ability_module.can?(:view, napoleon))
      refute(napoleon |> ability_module.can?(:view, squealer))
      refute(napoleon |> ability_module.can?(:view, piglet))
      refute(piglet |> ability_module.can?(:view, squealer))
      refute(piglet |> ability_module.can?(:view, napoleon))
      refute(squealer |> ability_module.can?(:view, napoleon))
    end

    test "accessible_query/3 called with a query", %{ability_module: ability_module} do
      base_query = Ecto.Query.from(p in Pig)
      query = base_query |> ability_module.accessible_query(%Pig{role: "napoleon"}, :view)

      assert {"pigs", Pig} = query.from
      assert query |> query_equals(Ecto.Query.from(p in base_query, where: p.role == ^"napoleon"))
    end

    test "accessible_query/3 called with a schema", %{ability_module: ability_module} do
      query = Pig |> ability_module.accessible_query(%Pig{role: "napoleon"}, :view)

      assert {"pigs", Pig} = query.from
      assert query |> query_equals(Ecto.Query.from(p in Pig, where: p.role == ^"napoleon"))
    end
  end

  describe "with a set of abilities given on Sheep with nested association via Pig" do
    setup [:prepare_breeds, :assign_pigs_to_breeds]

    setup context do
      context
      |> define_sheep_abilities do
        Sheep
        |> Cantare.Abilities.can(:worship, Pig, fn _current_sheep ->
          [breed: [name: "Berkshire Boar"]]
        end)
      end
    end

    test "can?/3, pig breed not preloaded", %{napoleon: napoleon, ability_module: ability_module} do
      napoleons_sheep = %Sheep{pig_id: napoleon.id}
      assert(napoleons_sheep |> ability_module.can?(:worship, napoleon))
    end

    test "can?/3, pig breed preloaded", %{napoleon: napoleon, ability_module: ability_module} do
      napoleons_sheep = %Sheep{pig_id: napoleon.id, pig: napoleon}
      assert(napoleons_sheep |> ability_module.can?(:worship, napoleon))
    end

    test "accessible_query/3 called with a query"

    test "accessible_query/3 called with a schema"
  end

  # Named setups

  def prepare_pigs(context \\ %{}) do
    context
    |> Map.merge(%{
      napoleon: %Pig{role: "napoleon", id: 1},
      squealer: %Pig{role: "squealer", id: 2},
      piglet: %Pig{role: "piglet", id: 3}
    })
  end

  def prepare_breeds(context \\ %{}) do
    context
    |> Map.merge(%{
      mangalica: %Breed{name: "Mangalica", id: 1},
      berkshire_boar: %Breed{name: "Berkshire Boar", id: 2}
    })
  end

  def assign_pigs_to_breeds(
        %{
          napoleon: napoleon,
          squealer: squealer,
          piglet: piglet,
          mangalica: mangalica,
          berkshire_boar: berkshire_boar
        } = context
      ) do
    %{
      context
      | napoleon: %Pig{napoleon | breed_id: berkshire_boar.id},
        squealer: %Pig{squealer | breed_id: mangalica.id},
        piglet: %Pig{piglet | breed_id: mangalica.id}
    }
  end
end
