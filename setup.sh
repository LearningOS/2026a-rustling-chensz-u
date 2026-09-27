#!/usr/bin/env bash
# Keep setup environment variables inside this process, even when sourced.
(
set -eu
cd "$(dirname "${BASH_SOURCE[0]}")"

version=$(sed -n 's/^channel = "\([0-9][0-9.]*\)"$/\1/p' rust-toolchain.toml)
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'Expected an exact Rust version in rust-toolchain.toml.' >&2
    exit 1
fi
export RUSTUP_DIST_SERVER=https://rsproxy.cn
export RUSTUP_UPDATE_ROOT=https://rsproxy.cn/rustup
export RUSTUP_TOOLCHAIN="$version"
mkdir -p tmp/setup .cargo
export TMPDIR="$PWD/tmp/setup"
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"

if ! command -v cc >/dev/null; then
    echo 'Install the system C compiler first: macOS Command Line Tools, or Linux build-essential.' >&2
    exit 1
fi
if ! command -v rustup >/dev/null; then
    curl --fail --location --retry 2 --output tmp/setup/rustup-init.sh https://rsproxy.cn/rustup-init.sh
    sh tmp/setup/rustup-init.sh -y --default-toolchain none --profile minimal
fi
rustup toolchain install "$version" --profile minimal --component clippy --no-self-update --no-update

# This file stays local; existing personal Cargo settings are preserved.
if [ ! -e .cargo/config.toml ]; then
    cat > .cargo/config.toml <<'CONFIG'
[build]
target-dir = "tmp/target"

[source.crates-io]
replace-with = "rsproxy-sparse"

[source.rsproxy-sparse]
registry = "sparse+https://rsproxy.cn/index/"
CONFIG
fi

echo 'Environment ready. Starting exercises; enter quit to exit.'
cargo run -- watch
)
