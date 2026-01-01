# frozen_string_literal: true

require "yaml"
require "fileutils"

module Gw
  class Config
    CONFIG_DIR = File.expand_path("~/.config/gw")
    CONFIG_FILE = File.join(CONFIG_DIR, "config.yml")
    DEFAULT_WORKSPACE = File.expand_path("~/Repository")

    class << self
      def load
        return default_config unless File.exist?(CONFIG_FILE)

        YAML.load_file(CONFIG_FILE) || default_config
      rescue StandardError => e
        raise ConfigError, "Failed to load config: #{e.message}"
      end

      def save(config)
        FileUtils.mkdir_p(CONFIG_DIR)
        File.write(CONFIG_FILE, YAML.dump(config))
      rescue StandardError => e
        raise ConfigError, "Failed to save config: #{e.message}"
      end

      def get(key)
        load[key]
      end

      def set(key, value)
        config = load
        config[key] = value
        save(config)
      end

      def workspace
        get("workspace") || DEFAULT_WORKSPACE
      end

      def core_dir
        File.join(workspace, "core")
      end

      def tree_dir
        File.join(workspace, "tree")
      end

      def editor
        get("editor") || "cursor"
      end

      def ai
        get("ai") || "claude"
      end

      def github_token
        get("github_token")
      end

      private

      def default_config
        {
          "workspace" => DEFAULT_WORKSPACE,
          "editor" => "cursor",
          "ai" => "claude"
        }
      end
    end
  end
end
