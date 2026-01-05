# kc - Secure Secrets Manager with iCloud Sync

A CLI tool to securely store and retrieve secrets with automatic iCloud Drive synchronization across all your Macs.

## Features

- 🔐 **AES-256 encryption** - military-grade encryption for your secrets
- ☁️ **iCloud Drive sync** - automatically sync encrypted secrets across all your Macs
- 🔑 **Master password in local keychain** - password stored securely, never synced
- 🏷️ **Namespace support** - organize secrets by type (env, ssh, token, etc.)
- 📝 **Append-only log** - automatic conflict resolution for concurrent edits
- 🚀 **Simple CLI interface** - easy to use command-line tool
- 📋 **Filter and search** - list secrets by namespace prefix

## Installation

```bash
gem install kc
```

Or add to your Gemfile:

```ruby
gem 'kc'
```

## Quick Start

### First Time Setup

Initialize kc with a master password:

```bash
$ kc init
Enter master password: ****
Confirm master password: ****

✓ Master password saved to local keychain
✓ iCloud Drive sync enabled at:
  ~/Library/Mobile Documents/com~apple~CloudDocs/kc

Your secrets will be encrypted and synced across your Macs!
```

**Important**: You'll need to run `kc init` on each Mac with the same master password.

## Usage

All commands use the format `<namespace>:<name>`. Namespaces help organize different types of secrets.

### Save Secrets

Read from stdin and save to keychain with namespace:

```bash
# Environment variables
kc save env:myproject < .env
cat .env | kc save env:production

# SSH keys
kc save ssh:id_rsa < ~/.ssh/id_rsa
kc save ssh:deploy-key < deploy_key

# API tokens
echo "ghp_xxxxxxxxxxxx" | kc save token:github
kc save token:openai < api_token.txt

# Certificates
kc save cert:ssl-cert < certificate.pem

# Custom namespaces
kc save my-app:config < config.json
```

### Load from Keychain

Output to stdout or redirect to file:

```bash
kc load env:myproject
kc load env:myproject > .env
kc load ssh:id_rsa > ~/.ssh/id_rsa
```

### List Entries

```bash
# List all entries
kc list

# List entries in specific namespace
kc list env:
kc list ssh:
kc list token:
```

### Delete from Keychain

```bash
kc delete env:myproject
kc delete ssh:id_rsa
kc delete token:github
```

### Use with direnv

In your `.envrc`:

```bash
# Load from keychain and export all variables
eval "$(kc load env:myproject | sed 's/^/export /')"

# Or restore .env file
kc load env:myproject > .env
source_env .env
```

## Commands

- `kc init` - Initialize with master password (first time setup)
- `kc save <namespace>:<name>` - Read from stdin and save encrypted
- `kc load <namespace>:<name>` - Decrypt and output to stdout  
- `kc delete <namespace>:<name>` - Mark entry as deleted
- `kc list [prefix]` - List all current entries (optionally filter by prefix)

## Namespaces

Namespaces must contain only lowercase letters, numbers, and hyphens.

**Common namespaces:**
- `env:` - Environment variable files
- `ssh:` - SSH keys
- `token:` - API tokens
- `cert:` - Certificates
- `key:` - Encryption keys
- `secret:` - General secrets

You can create custom namespaces as needed.

## How it works

### Architecture

`kc` uses a hybrid approach combining local keychain security with iCloud Drive synchronization:

1. **Master Password**: Stored securely in your local macOS Keychain (never synced)
2. **Encrypted Secrets**: Stored in `~/Library/Mobile Documents/com~apple~CloudDocs/kc/secrets.jsonl`
3. **Encryption**: AES-256-CBC with PBKDF2 key derivation (10,000 iterations)
4. **Sync**: iCloud Drive automatically syncs the encrypted file across your Macs

### Data Format

Secrets are stored in an append-only JSONL (JSON Lines) file:

```json
{"ts":"2026-01-05T10:00:00.123Z","op":"set","ns":"aws","key":"ACCESS_KEY","val":"<encrypted>"}
{"ts":"2026-01-05T11:30:00.456Z","op":"set","ns":"hubot","key":"TOKEN","val":"<encrypted>"}
{"ts":"2026-01-05T12:00:00.789Z","op":"del","ns":"aws","key":"OLD_KEY"}
```

- **Append-only**: New entries are always appended, never modified
- **Timestamps**: ISO8601 format with millisecond precision
- **Operations**: `set` (save/update) or `del` (delete)
- **Conflict Resolution**: Automatic merge based on timestamps

### Security

- ✅ **Master password** stored in local keychain (not synced)
- ✅ **AES-256 encryption** for all secret values
- ✅ **Unique salt and IV** for each encrypted value
- ✅ **PBKDF2 key derivation** with 10,000 iterations
- ✅ **End-to-end encryption** - iCloud only sees encrypted data
- ❌ **Metadata not encrypted** - namespace and key names are visible (but not values)

### Conflict Resolution

If you edit secrets on multiple Macs simultaneously:

1. iCloud Drive creates "conflicted copy" files
2. `kc` automatically detects and merges them
3. Entries are sorted by timestamp (oldest first)
4. Latest value for each key wins
5. Conflicted copies are deleted after merge

## Full Workflow Example

```bash
# Save environment variables for different environments
kc save env:development < .env.development
kc save env:staging < .env.staging
kc save env:production < .env.production

# Save SSH keys
kc save ssh:personal < ~/.ssh/id_rsa
kc save ssh:work < ~/.ssh/id_rsa_work

# Save API tokens
echo "ghp_xxxxxxxxxxxx" | kc save token:github
echo "sk-xxxxxxxxxxxxxx" | kc save token:openai

# List all secrets
kc list
# => env:development
# => env:production
# => env:staging
# => ssh:personal
# => ssh:work
# => token:github
# => token:openai

# List only environment files
kc list env:
# => env:development
# => env:production
# => env:staging

# Load and use in direnv
# .envrc file:
eval "$(kc load env:development | sed 's/^/export /')"

# Or check if exists before loading
if kc list env:production > /dev/null 2>&1; then
  kc load env:production > .env
else
  echo "No production env found"
fi

# Clean up when done
kc delete env:development
kc delete ssh:personal
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests.

```bash
bundle install
bundle exec rspec
```

## Requirements

- **macOS** - uses macOS Keychain for master password storage
- **iCloud Drive** - enabled in System Settings for sync
- **Ruby 2.5 or later**

**Note**: Each Mac needs to run `kc init` with the same master password to decrypt synced secrets.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/aileron-inc/tools.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Kc project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/aileron-inc/tools/blob/main/CODE_OF_CONDUCT.md).
