# frozen_string_literal: true

require "octokit"

module Gw
  class GitHub
    class << self
      def token
        # 1. gh auth token (if gh is available)
        if system("which gh > /dev/null 2>&1")
          gh_token = `gh auth token 2>/dev/null`.strip
          return gh_token unless gh_token.empty?
        end

        # 2. Environment variable
        return ENV["GITHUB_TOKEN"] if ENV["GITHUB_TOKEN"]

        # 3. Config file
        config_token = Config.github_token
        return config_token if config_token

        # 4. Error
        raise TokenNotFoundError, <<~MSG
          GitHub token not found. Please use one of:
          1. gh auth login (recommended)
          2. export GITHUB_TOKEN=your_token
          3. gw config set github_token your_token
        MSG
      end

      def client
        @client ||= Octokit::Client.new(access_token: token)
      end

      def repository(full_name)
        client.repository(full_name)
      end

      def default_branch(full_name)
        repo = repository(full_name)
        repo.default_branch
      end
    end
  end
end
