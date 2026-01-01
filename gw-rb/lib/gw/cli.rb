# frozen_string_literal: true

module Gw
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      command = @argv[0]

      case command
      when "init"
        handle_init
      when "repo"
        handle_repo
      when "add"
        handle_add
      when "remove", "rm"
        handle_remove
      when "list", "ls"
        handle_list
      when "go"
        handle_go
      when "config"
        handle_config
      else
        show_usage
        exit 1
      end
    rescue StandardError => e
      puts "Error: #{e.message}"
      exit 1
    end

    private

    def handle_init
      workspace = Config.workspace
      core_dir = Config.core_dir
      tree_dir = Config.tree_dir

      FileUtils.mkdir_p(core_dir)
      FileUtils.mkdir_p(tree_dir)

      puts "Initialized gw workspace at #{workspace}"
      puts "  core: #{core_dir}"
      puts "  tree: #{tree_dir}"
    end

    def handle_repo
      subcommand = @argv[1]

      case subcommand
      when "clone"
        handle_repo_clone
      else
        puts "Usage: gw repo clone <owner/repo> [--name <custom-name>]"
        exit 1
      end
    end

    def handle_repo_clone
      full_name = @argv[2]
      custom_name = nil

      # Parse --name option
      custom_name = @argv[4] if @argv[3] == "--name" && @argv[4]

      unless full_name
        puts "Error: repository name is required"
        puts "Usage: gw repo clone <owner/repo> [--name <custom-name>]"
        exit 1
      end

      repo = Repository.clone(full_name, custom_name: custom_name)
      puts "Successfully cloned #{full_name} as '#{repo.name}'"
      puts "  bare: #{repo.bare_path}"
      puts "  tree: #{repo.tree_dir}"
    end

    def handle_add
      target = @argv[1]

      unless target
        puts "Error: target is required"
        puts "Usage: gw add <repo-name>/<branch>"
        exit 1
      end

      # Parse repo-name/branch
      parts = target.split("/")
      if parts.length != 2
        puts "Error: invalid format. Use: <repo-name>/<branch>"
        exit 1
      end

      repo_name, branch = parts

      worktree = Worktree.add(repo_name, branch)
      puts "Successfully created worktree '#{branch}' for #{repo_name}"
      puts "  path: #{worktree.path}"
    end

    def handle_remove
      target = @argv[1]

      unless target
        puts "Error: target is required"
        puts "Usage: gw remove <repo-name>/<branch>"
        exit 1
      end

      # Parse repo-name/branch
      parts = target.split("/")
      if parts.length != 2
        puts "Error: invalid format. Use: <repo-name>/<branch>"
        exit 1
      end

      repo_name, branch = parts

      Worktree.remove(repo_name, branch)
      puts "Successfully removed worktree '#{branch}' for #{repo_name}"
    end

    def handle_list
      filter = @argv[1]

      repos = if filter
                [Repository.find(filter)]
              else
                Repository.list
              end

      if repos.empty?
        puts "No repositories found"
        return
      end

      puts "REPOSITORY  BRANCH      PATH"
      repos.each do |repo|
        worktrees = repo.worktrees
        if worktrees.empty?
          puts "#{repo.name.ljust(12)}(no worktrees)"
        else
          worktrees.each do |wt|
            puts "#{repo.name.ljust(12)}#{wt.branch.ljust(12)}#{wt.path}"
          end
        end
      end
    end

    def handle_go
      target = @argv[1]

      unless target
        puts "Error: target is required"
        puts "Usage: gw go <repo>/<branch>"
        exit 1
      end

      # Parse repo-name/branch
      parts = target.split("/")
      if parts.length != 2
        puts "Error: invalid format. Use: <repo>/<branch>"
        exit 1
      end

      repo_name, branch = parts

      # Find repository and worktree
      repo = Repository.find(repo_name)
      worktree = Worktree.new(repo, branch)

      unless worktree.exist?
        puts "Error: Worktree '#{branch}' not found for #{repo_name}"
        exit 1
      end

      # Output path only (for cd command)
      puts worktree.path
    end

    def handle_config
      subcommand = @argv[1]
      key = @argv[2]
      value = @argv[3]

      case subcommand
      when "get"
        unless key
          puts "Error: key is required"
          puts "Usage: gw config get <key>"
          exit 1
        end
        result = Config.get(key)
        puts result if result
      when "set"
        unless key && value
          puts "Error: key and value are required"
          puts "Usage: gw config set <key> <value>"
          exit 1
        end
        Config.set(key, value)
        puts "Successfully set #{key} = #{value}"
      else
        puts "Usage: gw config {get|set} <key> [value]"
        exit 1
      end
    end

    def show_usage
      puts <<~USAGE
        Usage:
          gw init                              Initialize gw workspace
          gw repo clone <owner/repo>           Clone repository
          gw repo clone <owner/repo> --name <name>   Clone with custom name
          gw add <repo>/<branch>               Add worktree
          gw remove <repo>/<branch>            Remove worktree
          gw list [repo]                       List worktrees
          gw go <repo>/<branch>                Print worktree path (for cd)
          gw config get <key>                  Get config value
          gw config set <key> <value>          Set config value

        Examples:
          gw init
          gw repo clone aileron-inc/tools
          gw repo clone org/app --name custom-app
          gw add tools/feature-1
          gw list
          gw list tools
          cd $(gw go tools/feature-1)
          gw remove tools/feature-1
          gw config set workspace ~/my-workspace
      USAGE
    end
  end
end
