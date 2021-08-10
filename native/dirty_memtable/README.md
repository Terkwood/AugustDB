# NIF for Elixir.Memtable.Dirty

SOURCED FROM: https://gist.github.com/tylergannon/b15d56121982415d5fd1f9987ae13f34

There's no explicit license here, so we should acquire
one before merging this to main. ⚠️

## To build the NIF module:

- Your NIF will now build along with your project.

## To load the NIF:

```elixir
defmodule Memtable.Dirty do
    use Rustler, otp_app: :august_db, crate: :dirty_memtable

    # define all your functions here, they will be overridden
end
```

## Examples

[This](https://github.com/hansihe/NifIo) is a complete example of a NIF written in Rust.
