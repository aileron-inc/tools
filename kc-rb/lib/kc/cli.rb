module Kc
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      command = @argv[0]
      name = @argv[1]

      case command
      when "save"
        handle_save(name)
      when "load"
        handle_load(name)
      when "delete"
        handle_delete(name)
      when "list"
        handle_list(name)
      else
        show_usage
        exit 1
      end
    end

    private

    def validate_namespace(name)
      unless name&.include?(":")
        puts "Error: Namespace required. Format: <namespace>:<name>"
        puts "Examples: env:myproject, ssh:id_rsa, token:github"
        exit 1
      end

      namespace, key = name.split(":", 2)
      
      if namespace.empty? || key.empty?
        puts "Error: Invalid format. Use <namespace>:<name>"
        exit 1
      end

      # Validate namespace format (alphanumeric and hyphen only)
      unless namespace.match?(/^[a-z0-9-]+$/)
        puts "Error: Namespace must contain only lowercase letters, numbers, and hyphens"
        exit 1
      end
    end

    def handle_save(name)
      unless name
        puts "Error: name is required"
        show_usage
        exit 1
      end

      validate_namespace(name)

      # Read from stdin
      if STDIN.tty?
        puts "Error: No input provided. Use: cat file | kc save <namespace>:<name>"
        exit 1
      end

      content = STDIN.read
      if content.empty?
        puts "Error: Input is empty"
        exit 1
      end

      Keychain.save(name, content)
      puts "Successfully saved to keychain as '#{name}'"
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def handle_load(name)
      unless name
        puts "Error: name is required"
        show_usage
        exit 1
      end

      validate_namespace(name)

      content = Keychain.load(name)
      puts content
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def handle_delete(name)
      unless name
        puts "Error: name is required"
        show_usage
        exit 1
      end

      validate_namespace(name)

      Keychain.delete(name)
      puts "Successfully deleted '#{name}' from keychain"
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def handle_list(prefix)
      items = Keychain.list(prefix)
      
      if items.empty?
        if prefix
          puts "No items found with prefix '#{prefix}'"
        else
          puts "No items found in keychain"
        end
      else
        items.each { |item| puts item }
      end
    rescue => e
      puts "Error: #{e.message}"
      exit 1
    end

    def show_usage
      puts <<~USAGE
        Usage:
          kc save <namespace>:<name>      Save from stdin to keychain
          kc load <namespace>:<name>      Load from keychain to stdout
          kc delete <namespace>:<name>    Delete from keychain
          kc list [prefix]                List all items (optionally filter by prefix)

        Examples:
          cat .env | kc save env:myproject
          kc load env:myproject > .env
          kc save ssh:id_rsa < ~/.ssh/id_rsa
          kc list                          # List all
          kc list env:                     # List all env: items
          kc delete env:myproject
      USAGE
    end
  end
end
