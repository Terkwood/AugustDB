# AugustDB

A key/value store backed by [LSM Trees](http://www.benstopford.com/2015/02/14/log-structured-merge-trees/) and SSTables.

This project is a work in progress 🚧 and is being developed primarily to suit the author's personal study goals 🎓. But if you find something in here that helps you learn, that's great too!

## Initial design

All writes are first written to a commit log, protecting against crashes.

Newly written values are stored in a memtable backed by [:gb_trees](https://erlang.org/doc/man/gb_trees.html).

[We define a binary SSTable format](#sstable-format).

We use phoenix to expose a REST API (PUT, GET, DEL) for creating, reading, updating, and deleting (for now) string resources using `Content-Type: application/json`. [Support for application/octet-stream](https://github.com/Terkwood/AugustDB/issues/24) is forthcoming.

## Webservice operation

To start the Phoenix server:

- Install dependencies with `mix deps.get`
- Install Node.js dependencies with `npm install` inside the `assets` directory
- Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Making HTTP calls

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

## SSTable Format

A Sorted String Table contains zero or more _gzipped key/value chunks_.

### GZipped key/value chunks

A _sized gzip chunk_ follows this binary specification:

1. First four bytes: length of the gzipped chunk
2. <variable length bytes>: gzipped chunk of key/value pairs, with tombstones.

### Unzipped key/value chunks

Each unzipped chunk contains zero or more key/value records.
Each record describes its own length. Some keys may point to
tombstones.

#### Value records

1. Length of key in bytes
2. Length of value in bytes
3. Raw key, not escaped
4. Raw value, not escaped

#### Tombstone records

1. Length of key in bytes
2. `2^32 - 1` to indicate tombstone
3. Raw key, not escaped

### Example in hex

One can image a simple, uncompressed binary representation of keys to values:

- hey: now
- no: yes
- one: _TOMBSTONE_
- three: four

![binary-sstable-hex](https://user-images.githubusercontent.com/38859656/128165328-736694c2-4342-4a66-b0bb-5e27525902db.png)

In practice you won't ever see this sequence on disk, because the records
will be gzipped.

## Inspiration

[Kleppmann: Designing Data-Intensive Applications](https://dataintensive.net/) gives a fantastic summary of local-node operation for data stores using SSTable, followed by detail on strategies for replication and partitioning. Check it out!

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

## 🔮 The Glorious Future: a distributed system

~~First implement a local key-value store that uses a memtable, SSTables, and a commit log~~. Then implement a replicating data store which syncs via gossip. Then implement partitioning using vnodes. [See the issue tracker](https://github.com/Terkwood/AugustDB/issues/15).
