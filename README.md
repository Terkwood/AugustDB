# AugustDB

A key/value store backed by SSTables.

## Initial design

Use gb_trees as memtable.

Use nimble_csv to generate SSTable format.

Use phoenix to expose a REST API (PUT, GET, DEL).

## Notional distributed system

First implement a local key-value store that uses a memtable, SSTables, and a commit log.  Then implement a replicating data store which syncs via gossip.  Then implement partitioning using vnodes.

I'll probably abandon this project before I get that far, but it doesn't hurt to dream! 

### Inspiration

[Kleppmann: Designing Data-Intensive Applications](https://dataintensive.net/) gives a fantastic summary of local-node operation for data stores using SSTable, followed by detail on strategies for replication and partitioning.  Check it out!

I sourced https://github.com/tamas-soos/expoll/blob/master/lib/ex_poll_web/views/poll_view.ex as a preliminary example for working with Phoenix.

## Dev environment

You should enable [multi-time warp mode](https://erlang.org/doc/apps/erts/time_correction.html#Multi_Time_Warp_Mode) during development in the REPL.

```sh
ELIXIR_ERL_OPTIONS="+C multi_time_warp" iex -S mix
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
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).
