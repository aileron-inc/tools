# kc - Keychain Manager

A secure CLI tool to manage secrets in macOS Keychain with namespace support.

## Implementations

- **[kc-rb](./kc-rb/)** - Ruby implementation (FFI-based, production ready)
- **kc-rs** - Rust implementation (planned)

## Features

- 🔐 Securely store any secrets in macOS Keychain
- 🏷️ **Namespace support** - organize secrets by type (env, ssh, token, etc.)
- 🚀 Native implementation using FFI (no shell command overhead)
- 🎯 Designed for direnv integration
- 📦 Simple CLI interface
- 📋 List and filter secrets by namespace

## Quick Start

```bash
# Install Ruby version
gem install kc

# Save secrets with namespace
kc save env:myproject < .env
kc save ssh:id_rsa < ~/.ssh/id_rsa
echo "token123" | kc save token:github

# Load secrets
kc load env:myproject > .env
kc load ssh:id_rsa > ~/.ssh/id_rsa

# List secrets
kc list              # All secrets
kc list env:         # Only env: namespace

# Delete secrets
kc delete env:myproject
```

## Documentation

See individual implementation directories for detailed documentation:
- [Ruby implementation](./kc-rb/README.md)

## License

MIT License - see individual implementations for details.
