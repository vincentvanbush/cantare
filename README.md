# Cantare [![Build Status](https://travis-ci.com/vincentvanbush/cantare.svg?branch=master)](https://travis-ci.com/vincentvanbush/cantare)

Declarative action authorization library for Elixir, inspired by [CanCanCan](https://github.com/ryanb/cancan).

Provide simple ability rules for your application using idiomatic Elixir patterns, just like this:

```
defmodule YourApp.Abilities do
  import Cantare.Abilities

  alias YourApp.Schemas.User
  alias YourApp.Schemas.{Item, Post}

  use Cantare.Abilities, repo: YourApp.Repo

  def abilities(User) do
    User
    |> can(:show, Item, fn %User{} = user, %Item{} = item -> item.active end)
    |> can(:edit, Post, fn %User{} = user, %Post{} = post -> Ecto.DateTime.compare(post.created_at, user.created_at) == :gt end)
    |> can(:create, League, fn current_user -> [name: current_user.email] end)
  end
end
```

Further README steps coming soon... This is still a very work-in-progress library that has _just_ been separated out of a private project from which it originated. There is still plenty of problems to resolve - perhaps most importantly, it still needs to be adapted to Ecto 3.

Stay tuned!

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cantare` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cantare, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/cantare](https://hexdocs.pm/cantare).

