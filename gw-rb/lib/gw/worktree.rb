# frozen_string_literal: true

module Gw
  class Worktree
    attr_reader :repository, :branch, :path

    def initialize(repository, branch, path = nil)
      @repository = repository
      @branch = branch
      @path = path || File.join(repository.tree_dir, branch)
    end

    def self.add(repo_name, branch)
      repo = Repository.find(repo_name)
      worktree = new(repo, branch)

      raise WorktreeAlreadyExistsError, "Worktree '#{branch}' already exists" if worktree.exist?

      # Check if branch exists (locally or remotely)
      branch_exists = system("git -C #{repo.bare_path} show-ref --verify --quiet refs/heads/#{branch}") ||
                      system("git -C #{repo.bare_path} show-ref --verify --quiet refs/remotes/origin/#{branch}")

      if branch_exists
        # Branch exists, checkout
        success = system("git -C #{repo.bare_path} worktree add #{worktree.path} #{branch}")
      else
        # Branch doesn't exist, create from default branch
        default_branch = repo.default_branch
        puts "Branch '#{branch}' not found. Creating from '#{default_branch}'..."
        success = system("git -C #{repo.bare_path} worktree add -b #{branch} #{worktree.path} #{default_branch}")
      end

      raise Error, "Failed to create worktree" unless success

      worktree
    end

    def self.remove(repo_name, branch, force: false)
      repo = Repository.find(repo_name)
      worktree = new(repo, branch)

      raise Error, "Worktree '#{branch}' not found" unless worktree.exist?

      # Remove worktree
      force_flag = force ? "--force" : ""
      success = system("git -C #{repo.bare_path} worktree remove #{force_flag} #{worktree.path}")

      raise Error, "Failed to remove worktree" unless success

      worktree
    end

    def self.list(repository)
      return [] unless Dir.exist?(repository.tree_dir)

      Dir.children(repository.tree_dir).map do |branch|
        new(repository, branch)
      end.select(&:exist?)
    end

    def exist?
      Dir.exist?(path) && File.exist?(File.join(path, ".git"))
    end
  end
end
