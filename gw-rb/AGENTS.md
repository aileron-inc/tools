# gw - Git Worktree Manager

## Project Overview

`gw` is a Ruby-based CLI tool for managing git worktrees using the bare repository pattern with a convention-over-configuration approach.

## Design Philosophy

### Convention over Configuration (Rails-like)

- **Directory Structure Convention**: Fixed `core/` and `tree/` directories
- **Environment Management**: Uses `direnv` with repository-level `.env` files
- **No File Copying**: Individual `.env` files placed at `tree/{repo-name}/.env` level
- **Multi-Repository Management**: Cross-repository worktree management from anywhere

### Directory Structure

```
~/Repository/                    # Default workspace (configurable)
  core/                          # Bare repositories (fixed name)
    tools/                       # bare repository
    frontend/                    # bare repository
  tree/                          # Worktrees (fixed name)
    tools/
      .env                       # Repository-level config (managed by user)
      .envrc                     # direnv config (managed by user)
      main/                      # worktree
      feature-1/                 # worktree
    frontend/
      .env
      main/
      ui-redesign/
```

## Core Features

### 1. Repository Management
- Clone repositories as bare with custom names
- GitHub integration via Octokit (not dependent on `gh` CLI)
- Support for organization namespace collision (e.g., `org1/app` vs `org2/app`)

### 2. Worktree Operations
- Add worktrees with automatic branch creation
- Remove worktrees
- List all worktrees across repositories
- Navigate to worktrees: `cd $(gw go tools/feature-1)`
- Repository-scoped operations: `gw add tools/feature-1`

### 3. Configuration Management
- Default workspace: `~/Repository`
- Workspace location configurable via `~/.config/gw/config.yml`
- GitHub token hierarchy: `gh auth token` → `GITHUB_TOKEN` env var → config file

### 4. GitHub Integration
- Token priority:
  1. `gh auth token` (if `gh` command available)
  2. `GITHUB_TOKEN` environment variable
  3. `~/.config/gw/config.yml` setting
  4. Error with helpful message

## Command Reference

```bash
# Initialize workspace
gw init

# Clone repository
gw repo clone aileron-inc/tools
gw repo clone org/app --name org-app  # Custom name to avoid collision

# Add worktree (auto-creates branch if not exists)
gw add tools/feature-1

# Remove worktree
gw remove tools/feature-1
gw rm tools/feature-1  # Alias

# List worktrees
gw list              # All repositories
gw list tools        # Specific repository

# Navigate to worktree
cd $(gw go tools/feature-1)

# Configuration
gw config get workspace
gw config set workspace ~/my-workspace
gw config set github_token ghp_xxxxx
```

## Implementation Guidelines

### Code Structure

```
lib/gw/
  version.rb      # Version constant
  errors.rb       # Error classes
  config.rb       # Configuration management
  github.rb       # GitHub API integration (Octokit)
  repository.rb   # Repository operations (bare repos)
  worktree.rb     # Worktree operations
  cli.rb          # Command-line interface
```

### Design Patterns

1. **Class Methods for Operations**: Use class methods for primary operations (e.g., `Repository.clone`, `Worktree.add`)
2. **Instance for State**: Use instances to hold state (e.g., `Repository` instance has `name`, `bare_path`)
3. **Simple Error Handling**: Raise specific errors, catch in CLI layer
4. **No Heavy Dependencies**: Keep dependencies minimal (only Octokit for GitHub API)

### Key Decisions

- **No bare repository auto-creation of main branch**: Keep operations explicit
- **Auto-create branches on `gw add`**: If branch doesn't exist, create from default branch
- **No file copying hooks**: Use direnv convention instead
- **No editor/AI integration yet**: Focus on core worktree management first (can add later)

## Future Enhancements (Not in MVP)

- `gw editor <repo>/<branch>` - Open editor (like gtr)
- `gw ai <repo>/<branch>` - Start AI tool (like gtr)
- `gw run <repo>/<branch> <command>` - Run command in worktree
- `gw status` - Show git status across all worktrees
- `gw prune` - Clean up stale worktrees

## Development Notes

### Dependencies

- `octokit` (~> 9.0) - GitHub API client
- No dependency on `gh` CLI (optional for token retrieval)

### Testing Strategy

- Manual testing for MVP
- Future: RSpec for unit tests
- Integration tests for git operations

### RuboCop

- Some warnings acceptable for rapid development
- Focus on functionality over style compliance initially
- Clean up in refinement phase

## Differences from Similar Tools

### vs git-worktree-runner (gtr)

| Feature | gtr | gw |
|---------|-----|-----|
| Scope | Single repository | Multi-repository |
| Operation | From within repo | From anywhere |
| Config files | Auto-copy | direnv convention |
| Hooks | Post-create, etc. | None (keep simple) |
| GitHub | None | Octokit integration |
| Philosophy | Configuration | Convention |

### vs Manual git worktree

- Higher-level abstractions
- Multi-repository management
- GitHub integration
- Consistent directory structure
- Simplified commands

## Contributing Guidelines

1. Keep it simple - convention over configuration
2. No feature creep - focus on core worktree management
3. Follow existing patterns (see `kc-rb` for reference)
4. Test manually before committing
5. Document new commands in this file

## License

MIT License (same as parent project)
