# AugustDb

A KV store backed by SSTables.

## Design

Use gb_trees as memtable.

Use nimble_csv to generate sstable format.

Use phoenix to expose a REST API (PUT, GET, DEL).

### Inspiration

Kleppmann, _Designing Data-Intensive Applications_

We worked from https://github.com/tamas-soos/expoll/blob/master/lib/ex_poll_web/views/poll_view.ex as a preliminary example for Phoenix

## Dev environment

You should enable [multi-time warp mode](https://erlang.org/doc/apps/erts/time_correction.html#Multi_Time_Warp_Mode) during development in the REPL.

```sh
`ELIXIR_ERL_OPTIONS="+C multi_time_warp" iex -S mix`
```

## Generating docs

You can [follow the CLI instructions for ExDoc](https://github.com/elixir-lang/ex_doc#using-exdoc-via-command-line):

```sh
ex_doc "AugustDB" "0.0.0" "_build/dev/lib/august_db/ebin"
 -m "AugustDbWeb.ValueController" -u "https://github.com/Terkwood/AugustDB"
```

## Webservice operation

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
