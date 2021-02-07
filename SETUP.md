# Setup

Follow these steps to build the iOS app:

1. Install [Rust](https://www.rust-lang.org/)
2. Install [`cbindgen`](https://github.com/eqrion/cbindgen):

```
cargo install cbindgen
```

3. Add needed targets via rustup:

```
rustup target add aarch64-apple-ios x86_64-apple-ios
```

4. Install [`mint`](https://github.com/yonaskolb/mint):

```
brew install mint
```

5. Setup tooling with mint:

```
cd swift
mint bootstrap
```

After performing the above steps, open the XCode project in XCode and build the `Minecraft Status` scheme.

If you're running Big Sur you may need to perform the workaround described in [this comment](https://github.com/TimNN/cargo-lipo/issues/41#issuecomment-745623541) before building.
