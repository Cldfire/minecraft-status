# Setup

1. Install [Rust](https://www.rust-lang.org/)
2. Install [`cbindgen`](https://github.com/eqrion/cbindgen):

```
cargo install cbindgen
```

3. Install [`homebrew`](https://brew.sh/)

4. Run `swift/scripts/bootstrap.sh`

```
sh swift/scripts/bootstrap.sh
```

After performing the above steps, open the XCode project in XCode and build the `Minecraft Status` scheme.

If you're running Big Sur you may need to perform the workaround described in [this comment](https://github.com/TimNN/cargo-lipo/issues/41#issuecomment-745623541) before building.
