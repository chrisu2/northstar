# Northstar Forge

This folder is the Rust workspace of Northstar Forge, the tool that makes Northstar's leveling
routes: from the installed game and the guides it builds the reference data, prices the walks,
improves each start's route, writes it into the guides and reports the result.

How to install and use it: [docs/FORGE.md](../docs/FORGE.md). How the code is laid out:
[docs/forge/internals.md](../docs/forge/internals.md).

Build it with Rust 1.87 or newer:

```sh
cargo build --release -p forge        # the program is target/release/forge
```

Credits and licences: [NOTICE.md](NOTICE.md) and [THIRD_PARTY.md](../THIRD_PARTY.md).
