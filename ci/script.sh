#!/bin/sh

# This is the main CI script for testing the regex crate and its sub-crates.

set -ex
MSRV="1.20.0"

# If we're building on 1.20, then lazy_static 1.2 will fail to build since it
# updated its MSRV to 1.24.1. In this case, we force the use of lazy_static 1.1
# to build on Rust 1.20.0.
if [ "$TRAVIS_RUST_VERSION" = "$MSRV" ]; then
    cargo update -p lazy_static --precise 1.1.0
    # On older versions of Cargo, this apparently needs to be run twice
    # if Cargo.lock didn't previously exist. Since this command should be
    # idempotent, we run it again unconditionally.
    cargo update -p lazy_static --precise 1.1.0
fi

# Builds the regex crate and runs tests.
cargo build --verbose
cargo doc --verbose

# If we're testing on an older version of Rust, then only check that we
# can build the crate. This is because the dev dependencies might be updated
# more frequently, and therefore might require a newer version of Rust.
#
# This isn't ideal. It's a compromise.
if [ "$TRAVIS_RUST_VERSION" = "$MSRV" ]; then
  exit
fi

# Run tests. If we have nightly, then enable our nightly features.
# Right now there are no nightly features, but that may change in the
# future.
CARGO_TEST_EXTRA_FLAGS=""
if [ "$TRAVIS_RUST_VERSION" = "nightly" ]; then
  CARGO_TEST_EXTRA_FLAGS=""
fi
cargo test --verbose ${CARGO_TEST_EXTRA_FLAGS}

# Run the random tests in release mode, as this is faster.
RUST_REGEX_RANDOM_TEST=1 \
    cargo test --release --verbose \
    ${CARGO_TEST_EXTRA_FLAGS} --test crates-regex

# Run a test that confirms the shootout benchmarks are correct.
ci/run-shootout-test

# Run tests on regex-syntax crate.
cargo test --verbose --manifest-path regex-syntax/Cargo.toml
cargo doc --verbose --manifest-path regex-syntax/Cargo.toml

# Run tests on regex-capi crate.
ci/test-regex-capi

# Make sure benchmarks compile. Don't run them though because they take a
# very long time. Also, check that we can build the regex-debug tool.
if [ "$TRAVIS_RUST_VERSION" = "nightly" ]; then
  cargo build --verbose --manifest-path regex-debug/Cargo.toml
  for x in rust rust-bytes pcre1 onig; do
    (cd bench && ./run $x --no-run --verbose)
  done

  # Test minimal versions.
  cargo +nightly generate-lockfile -Z minimal-versions
  cargo build --verbose
  cargo test --verbose
fi
