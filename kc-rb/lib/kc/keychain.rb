require 'ffi'
require 'json'
require 'openssl'
require 'base64'
require 'fileutils'
require 'time'

module Kc
  class Keychain
    MASTER_PASSWORD_SERVICE = 'kc-master-password'
    MASTER_PASSWORD_ACCOUNT = 'default'
    ICLOUD_DRIVE_PATH = File.expand_path('~/Library/Mobile Documents/com~apple~CloudDocs/kc')
    SECRETS_FILE = File.join(ICLOUD_DRIVE_PATH, 'secrets.jsonl')

    module SecurityFramework
      extend FFI::Library
      ffi_lib '/System/Library/Frameworks/Security.framework/Security'

      # OSStatus SecKeychainAddGenericPassword(...)
      attach_function :SecKeychainAddGenericPassword, %i[
        pointer uint32 string uint32 string
        uint32 pointer pointer
      ], :int

      # OSStatus SecKeychainFindGenericPassword(...)
      attach_function :SecKeychainFindGenericPassword, %i[
        pointer uint32 string uint32 string
        pointer pointer pointer
      ], :int

      # OSStatus SecKeychainItemDelete(...)
      attach_function :SecKeychainItemDelete, [:pointer], :int

      # void SecKeychainItemFreeContent(...)
      attach_function :SecKeychainItemFreeContent, %i[pointer pointer], :int

      ErrSecSuccess = 0
      ErrSecItemNotFound = -25_300
    end

    class << self
      # Initialize master password
      def init(password)
        # Delete existing if any
        begin
          delete_master_password
        rescue StandardError
          nil
        end

        # Save new master password to local keychain
        status = SecurityFramework.SecKeychainAddGenericPassword(
          nil,
          MASTER_PASSWORD_SERVICE.bytesize,
          MASTER_PASSWORD_SERVICE,
          MASTER_PASSWORD_ACCOUNT.bytesize,
          MASTER_PASSWORD_ACCOUNT,
          password.bytesize,
          FFI::MemoryPointer.from_string(password),
          nil
        )

        unless status == SecurityFramework::ErrSecSuccess
          raise Error, "Failed to save master password (status: #{status})"
        end

        # Ensure iCloud Drive directory exists
        FileUtils.mkdir_p(ICLOUD_DRIVE_PATH)

        # Create empty secrets file if it doesn't exist
        File.write(SECRETS_FILE, '') unless File.exist?(SECRETS_FILE)
      end

      # Get master password from local keychain
      def master_password
        password_length = FFI::MemoryPointer.new(:uint32)
        password_data = FFI::MemoryPointer.new(:pointer)

        status = SecurityFramework.SecKeychainFindGenericPassword(
          nil,
          MASTER_PASSWORD_SERVICE.bytesize,
          MASTER_PASSWORD_SERVICE,
          MASTER_PASSWORD_ACCOUNT.bytesize,
          MASTER_PASSWORD_ACCOUNT,
          password_length,
          password_data,
          nil
        )

        if status == SecurityFramework::ErrSecItemNotFound
          raise Error, "Master password not found. Please run 'kc init' first."
        end

        unless status == SecurityFramework::ErrSecSuccess
          raise Error, "Failed to load master password (status: #{status})"
        end

        length = password_length.read_uint32
        data_ptr = password_data.read_pointer
        password = data_ptr.read_string(length)

        SecurityFramework.SecKeychainItemFreeContent(nil, data_ptr)

        password
      end

      # Delete master password
      def delete_master_password
        item_ref = FFI::MemoryPointer.new(:pointer)

        status = SecurityFramework.SecKeychainFindGenericPassword(
          nil,
          MASTER_PASSWORD_SERVICE.bytesize,
          MASTER_PASSWORD_SERVICE,
          MASTER_PASSWORD_ACCOUNT.bytesize,
          MASTER_PASSWORD_ACCOUNT,
          nil,
          nil,
          item_ref
        )

        return if status == SecurityFramework::ErrSecItemNotFound

        unless status == SecurityFramework::ErrSecSuccess
          raise Error, "Failed to find master password (status: #{status})"
        end

        delete_status = SecurityFramework.SecKeychainItemDelete(item_ref.read_pointer)
        return if delete_status == SecurityFramework::ErrSecSuccess

        raise Error, "Failed to delete master password (status: #{delete_status})"
      end

      # Encrypt data with master password
      def encrypt(data)
        password = master_password
        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.encrypt

        # Derive key from password
        salt = OpenSSL::Random.random_bytes(16)
        key = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 10_000, cipher.key_len, 'sha256')
        cipher.key = key

        iv = cipher.random_iv
        encrypted = cipher.update(data) + cipher.final

        # Return: salt + iv + encrypted_data (all base64 encoded)
        result = {
          salt: Base64.strict_encode64(salt),
          iv: Base64.strict_encode64(iv),
          data: Base64.strict_encode64(encrypted)
        }
        Base64.strict_encode64(result.to_json)
      end

      # Decrypt data with master password
      def decrypt(encrypted_str)
        password = master_password

        # Decode outer base64
        payload = JSON.parse(Base64.strict_decode64(encrypted_str))

        salt = Base64.strict_decode64(payload['salt'])
        iv = Base64.strict_decode64(payload['iv'])
        encrypted_data = Base64.strict_decode64(payload['data'])

        cipher = OpenSSL::Cipher.new('AES-256-CBC')
        cipher.decrypt

        key = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 10_000, cipher.key_len, 'sha256')
        cipher.key = key
        cipher.iv = iv

        cipher.update(encrypted_data) + cipher.final
      end

      # Append entry to JSONL
      def append_entry(namespace, key, value, operation: 'set')
        ensure_secrets_file

        entry = {
          ts: Time.now.utc.iso8601(3),
          op: operation,
          ns: namespace,
          key: key
        }

        entry[:val] = encrypt(value) if operation == 'set'

        File.open(SECRETS_FILE, 'a') do |f|
          f.puts(entry.to_json)
        end
      end

      # Detect and merge conflicted copies
      def detect_and_merge_conflicts
        return unless File.exist?(SECRETS_FILE)

        dir = File.dirname(SECRETS_FILE)
        base = File.basename(SECRETS_FILE, '.jsonl')

        # Find all conflicted copies
        conflicted = Dir.glob(File.join(dir, "#{base} (*conflicted copy*).jsonl"))
        return if conflicted.empty?

        # Read all files
        all_entries = []

        # Main file
        if File.exist?(SECRETS_FILE)
          File.readlines(SECRETS_FILE).each do |line|
            line = line.strip
            next if line.empty?

            begin
              all_entries << JSON.parse(line, symbolize_names: true)
            rescue JSON::ParserError
              # Skip malformed lines
            end
          end
        end

        # Conflicted files
        conflicted.each do |file|
          File.readlines(file).each do |line|
            line = line.strip
            next if line.empty?

            begin
              all_entries << JSON.parse(line, symbolize_names: true)
            rescue JSON::ParserError
              # Skip malformed lines
            end
          end
        end

        # Sort by timestamp (oldest first)
        all_entries.sort_by! { |e| e[:ts] }

        # Write merged entries back to main file
        File.open(SECRETS_FILE, 'w') do |f|
          all_entries.each { |e| f.puts(e.to_json) }
        end

        # Delete conflicted copies
        conflicted.each { |file| File.delete(file) }
      end

      # Read all entries from JSONL
      def read_entries
        # First, detect and merge any conflicts
        detect_and_merge_conflicts

        return [] unless File.exist?(SECRETS_FILE)

        entries = []
        File.readlines(SECRETS_FILE).each do |line|
          line = line.strip
          next if line.empty?

          begin
            entries << JSON.parse(line, symbolize_names: true)
          rescue JSON::ParserError
            # Skip malformed lines
          end
        end

        entries
      end

      # Get current state (latest values for each key)
      def current_state
        entries = read_entries
        state = {}

        entries.each do |entry|
          ns_key = "#{entry[:ns]}:#{entry[:key]}"

          if entry[:op] == 'set'
            state[ns_key] = {
              namespace: entry[:ns],
              key: entry[:key],
              encrypted_value: entry[:val],
              timestamp: entry[:ts]
            }
          elsif entry[:op] == 'del'
            state.delete(ns_key)
          end
        end

        state
      end

      # Save a secret
      def save(account_name, content)
        namespace, key = parse_account_name(account_name)
        append_entry(namespace, key, content, operation: 'set')
      end

      # Load a secret
      def load(account_name)
        namespace, key = parse_account_name(account_name)
        state = current_state
        ns_key = "#{namespace}:#{key}"

        entry = state[ns_key]
        raise Error, "Entry '#{account_name}' not found" unless entry

        decrypt(entry[:encrypted_value])
      end

      # Delete a secret
      def delete(account_name)
        namespace, key = parse_account_name(account_name)

        # Check if exists
        state = current_state
        ns_key = "#{namespace}:#{key}"
        raise Error, "Entry '#{account_name}' not found" unless state[ns_key]

        append_entry(namespace, key, nil, operation: 'del')
      end

      # List secrets
      def list(prefix = nil)
        state = current_state
        keys = state.keys

        keys = keys.select { |k| k.start_with?(prefix) } if prefix

        keys.sort
      end

      private

      def parse_account_name(account_name)
        raise Error, 'Invalid format. Use <namespace>:<name>' unless account_name&.include?(':')

        namespace, key = account_name.split(':', 2)

        raise Error, 'Invalid format. Use <namespace>:<name>' if namespace.empty? || key.empty?

        [namespace, key]
      end

      def ensure_secrets_file
        FileUtils.mkdir_p(ICLOUD_DRIVE_PATH) unless Dir.exist?(ICLOUD_DRIVE_PATH)
        File.write(SECRETS_FILE, '') unless File.exist?(SECRETS_FILE)
      end
    end
  end
end
