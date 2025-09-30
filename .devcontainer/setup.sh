#!/usr/bin/env bash
set -euo pipefail

# Install pnpm via corepack
if ! command -v pnpm >/dev/null 2>&1; then
  corepack enable || true
  corepack prepare pnpm@8.15.1 --activate
fi

# Install Rust (Move compiler requirement)
if ! command -v cargo >/dev/null 2>&1; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal
  source "$HOME/.cargo/env"
fi

# Install Sui CLI if missing
if ! command -v sui >/dev/null 2>&1; then
  SUI_VERSION="1.24.1"
  ARCHIVE=""
  case "$(uname -sm)" in
    "Linux x86_64")
      ARCHIVE="sui-linux-x86_64.tgz"
      ;;
    "Linux aarch64")
      ARCHIVE="sui-linux-aarch64.tgz"
      ;;
    "Darwin arm64")
      ARCHIVE="sui-macos-aarch64.tgz"
      ;;
    "Darwin x86_64")
      ARCHIVE="sui-macos-x86_64.tgz"
      ;;
    *)
      echo "Unsupported platform for automatic Sui CLI install" >&2
      exit 1
      ;;
  esac

  curl -L "https://github.com/MystenLabs/sui/releases/download/mainnet-v${SUI_VERSION}/${ARCHIVE}" -o /tmp/sui.tgz
  mkdir -p "$HOME/.local/bin"
  tar -xzf /tmp/sui.tgz -C "$HOME/.local/bin" --strip-components=1 sui
  rm /tmp/sui.tgz
fi

# Install node dependencies (cached across launches)
if [ -f /workspaces/nft-mint-sample/app/package.json ]; then
  cd /workspaces/nft-mint-sample/app
  pnpm install
fi
