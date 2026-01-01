# frozen_string_literal: true

require "fileutils"

module Gw
  class Repository
    attr_reader :name, :full_name, :bare_path

    def initialize(name, full_name = nil)
      @name = name
      @full_name = full_name
      @bare_path = File.join(Config.core_dir, name)
    end

    def self.clone(full_name, custom_name: nil)
      repo_name = custom_name || full_name.split("/").last
      repo = new(repo_name, full_name)

      raise Error, "Repository '#{repo_name}' already exists" if repo.exist?

      FileUtils.mkdir_p(Config.core_dir)

      # Clone as bare repository
      clone_url = GitHub.repository(full_name).clone_url
      success = system("git clone --bare #{clone_url} #{repo.bare_path}")

      raise Error, "Failed to clone repository" unless success

      # Create tree directory for this repo
      FileUtils.mkdir_p(File.join(Config.tree_dir, repo_name))

      repo
    end

    def self.list
      return [] unless Dir.exist?(Config.core_dir)

      Dir.children(Config.core_dir).map do |name|
        new(name)
      end.select(&:exist?)
    end

    def self.find(name)
      repo = new(name)
      raise RepositoryNotFoundError, "Repository '#{name}' not found" unless repo.exist?

      repo
    end

    def exist?
      Dir.exist?(bare_path) && File.exist?(File.join(bare_path, "HEAD"))
    end

    def tree_dir
      File.join(Config.tree_dir, name)
    end

    def worktrees
      Worktree.list(self)
    end

    def default_branch
      return @default_branch if @default_branch

      # Try to get from GitHub if full_name is available
      if full_name
        @default_branch = GitHub.default_branch(full_name)
      else
        # Fallback: read from bare repository
        head_file = File.join(bare_path, "HEAD")
        content = File.read(head_file).strip
        @default_branch = content.match(%r{ref: refs/heads/(.+)})&.[](1) || "main"
      end

      @default_branch
    end
  end
end
