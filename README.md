# AugustDB

A key/value store backed by [LSM Trees](http://www.benstopford.com/2015/02/14/log-structured-merge-trees/) and SSTables.

This project is a work in progress 🚧 and is being developed primarily to suit the author's personal study goals 🎓.  But if you find something in here that helps you learn, that's great too!

## Initial design

All writes are first written to a commit log, protecting against crashes.

Newly written values are stored in a memtable backed by [:gb_trees](https://erlang.org/doc/man/gb_trees.html).

We define a binary SSTable format.

We use phoenix to expose a REST API (PUT, GET, DEL) for creating, reading, updating, and deleting (for now) string resources using `Content-Type: application/json`. [Support for application/octet-stream](https://github.com/Terkwood/AugustDB/issues/24) is forthcoming.

### SSTable Format

This is the specification for [binary SSTables](https://github.com/Terkwood/AugustDB/issues/51).

#### value records 

1. Length of key in bytes
2. Length of value in bytes
3. Raw key, not escaped
4. Raw value, not escaped

#### tombstone records

1. Length of key in bytes
2. -1 to indicate tombstone
3. Raw key, not escaped

### Making HTTP calls

Create a record

```sh
curl -X PUT  -d value='meh meh'  http://localhost:4000/api/values/1
```

Update a record
```sh
curl -X PUT  -d value='n0 n0'  http://localhost:4000/api/values/1
```

Get a record

```sh
curl  http://localhost:4000/api/values/1
```

Delete a record 

```sh
curl -X DELETE http://localhost:4000/api/values/1
```



## Inspiration

[Kleppmann: Designing Data-Intensive Applications](https://dataintensive.net/) gives a fantastic summary of local-node operation for data stores using SSTable, followed by detail on strategies for replication and partitioning.  Check it out!

I sourced https://github.com/tamas-soos/expoll/blob/master/lib/ex_poll_web/views/poll_view.ex as a preliminary example for working with Phoenix.

## Dev environment

You should enable [multi-time warp mode](https://erlang.org/doc/apps/erts/time_correction.html#Multi_Time_Warp_Mode) during development in the REPL.

```sh
ELIXIR_ERL_OPTIONS="+C multi_time_warp" iex -S mix
```


## 🔮 The Glorious Future: a distributed system

~~First implement a local key-value store that uses a memtable, SSTables, and a commit log~~.  Then implement a replicating data store which syncs via gossip.  Then implement partitioning using vnodes. [See the issue tracker](https://github.com/Terkwood/AugustDB/issues/15).


## Generating docs

You can [follow the CLI instructions for ExDoc](https://github.com/elixir-lang/ex_doc#using-exdoc-via-command-line):

```sh
ex_doc "AugustDB" "0.1.1" "_build/dev/lib/august_db/ebin"
 -m "AugustDbWeb.ValueController" -u "https://github.com/Terkwood/AugustDB"
```

## Webservice operation

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Install Node.js dependencies with `npm install` inside the `assets` directory
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).
