require "ffi"

module Kc
  class Keychain
    SERVICE_NAME = "kc"

    module SecurityFramework
      extend FFI::Library
      ffi_lib "/System/Library/Frameworks/Security.framework/Security"

      # OSStatus SecKeychainAddGenericPassword(
      #   SecKeychainRef keychain,
      #   UInt32 serviceNameLength,
      #   const char *serviceName,
      #   UInt32 accountNameLength,
      #   const char *accountName,
      #   UInt32 passwordLength,
      #   const void *passwordData,
      #   SecKeychainItemRef *itemRef
      # )
      attach_function :SecKeychainAddGenericPassword, [
        :pointer,  # keychain (NULL for default)
        :uint32,   # serviceNameLength
        :string,   # serviceName
        :uint32,   # accountNameLength
        :string,   # accountName
        :uint32,   # passwordLength
        :pointer,  # passwordData
        :pointer   # itemRef (can be NULL)
      ], :int

      # OSStatus SecKeychainFindGenericPassword(
      #   CFTypeRef keychainOrArray,
      #   UInt32 serviceNameLength,
      #   const char *serviceName,
      #   UInt32 accountNameLength,
      #   const char *accountName,
      #   UInt32 *passwordLength,
      #   void **passwordData,
      #   SecKeychainItemRef *itemRef
      # )
      attach_function :SecKeychainFindGenericPassword, [
        :pointer,  # keychainOrArray (NULL for default)
        :uint32,   # serviceNameLength
        :string,   # serviceName
        :uint32,   # accountNameLength
        :string,   # accountName
        :pointer,  # passwordLength (output)
        :pointer,  # passwordData (output)
        :pointer   # itemRef (output, can be NULL if not needed)
      ], :int

      # OSStatus SecKeychainItemDelete(SecKeychainItemRef itemRef)
      attach_function :SecKeychainItemDelete, [:pointer], :int

      # void SecKeychainItemFreeContent(SecKeychainAttributeList *attrList, void *data)
      attach_function :SecKeychainItemFreeContent, [:pointer, :pointer], :int

      # Constants for attribute tags
      KSecAccountItemAttr = 0x61636374  # 'acct' in FourCC

      # Attribute structure
      class SecKeychainAttribute < FFI::Struct
        layout :tag, :uint32,
               :length, :uint32,
               :data, :pointer
      end

      class SecKeychainAttributeList < FFI::Struct
        layout :count, :uint32,
               :attr, :pointer  # Array of SecKeychainAttribute
      end

      # OSStatus SecKeychainSearchCreateFromAttributes(
      #   CFTypeRef keychainOrArray,
      #   SecItemClass itemClass,
      #   const SecKeychainAttributeList *attrList,
      #   SecKeychainSearchRef *searchRef
      # )
      attach_function :SecKeychainSearchCreateFromAttributes, [
        :pointer,  # keychainOrArray
        :uint32,   # itemClass (kSecGenericPasswordItemClass = 'genp')
        :pointer,  # attrList
        :pointer   # searchRef (output)
      ], :int

      # OSStatus SecKeychainSearchCopyNext(
      #   SecKeychainSearchRef searchRef,
      #   SecKeychainItemRef *itemRef
      # )
      attach_function :SecKeychainSearchCopyNext, [
        :pointer,  # searchRef
        :pointer   # itemRef (output)
      ], :int

      # OSStatus SecKeychainItemCopyAttributesAndData(
      #   SecKeychainItemRef itemRef,
      #   SecKeychainAttributeInfo *info,
      #   SecItemClass *itemClass,
      #   SecKeychainAttributeList **attrList,
      #   UInt32 *length,
      #   void **outData
      # )
      attach_function :SecKeychainItemCopyAttributesAndData, [
        :pointer,  # itemRef
        :pointer,  # info (NULL for default keychain)
        :pointer,  # itemClass (can be NULL)
        :pointer,  # attrList (output)
        :pointer,  # length (can be NULL)
        :pointer   # outData (can be NULL)
      ], :int

      # OSStatus SecKeychainItemFreeAttributesAndData(
      #   SecKeychainAttributeList *attrList,
      #   void *data
      # )
      attach_function :SecKeychainItemFreeAttributesAndData, [:pointer, :pointer], :int

      # void CFRelease(CFTypeRef cf)
      attach_function :CFRelease, [:pointer], :void
    end

    class << self
      def save(account_name, content)
        # Try to delete existing entry first
        delete(account_name) rescue nil

        # Add new entry
        status = SecurityFramework.SecKeychainAddGenericPassword(
          nil,                        # default keychain
          SERVICE_NAME.bytesize,      # service name length
          SERVICE_NAME,               # service name
          account_name.bytesize,      # account name length
          account_name,               # account name
          content.bytesize,           # password length
          FFI::MemoryPointer.from_string(content),  # password data
          nil                         # don't need item ref
        )

        unless status.zero?
          raise Error, "Failed to save to keychain (status: #{status})"
        end
      end

      def load(account_name)
        password_length = FFI::MemoryPointer.new(:uint32)
        password_data = FFI::MemoryPointer.new(:pointer)

        status = SecurityFramework.SecKeychainFindGenericPassword(
          nil,                        # default keychain
          SERVICE_NAME.bytesize,      # service name length
          SERVICE_NAME,               # service name
          account_name.bytesize,      # account name length
          account_name,               # account name
          password_length,            # password length (output)
          password_data,              # password data (output)
          nil                         # don't need item ref
        )

        unless status.zero?
          raise Error, "Failed to load from keychain (status: #{status})"
        end

        # Read the password data
        length = password_length.read_uint32
        data_ptr = password_data.read_pointer
        password = data_ptr.read_string(length)

        # Free the memory allocated by Security framework
        SecurityFramework.SecKeychainItemFreeContent(nil, data_ptr)

        password
      end

      def delete(account_name)
        item_ref = FFI::MemoryPointer.new(:pointer)

        status = SecurityFramework.SecKeychainFindGenericPassword(
          nil,
          SERVICE_NAME.bytesize,
          SERVICE_NAME,
          account_name.bytesize,
          account_name,
          nil,
          nil,
          item_ref
        )

        unless status.zero?
          raise Error, "Entry '#{account_name}' not found in keychain"
        end

        delete_status = SecurityFramework.SecKeychainItemDelete(item_ref.read_pointer)
        
        unless delete_status.zero?
          raise Error, "Failed to delete from keychain (status: #{delete_status})"
        end
      end

      def list(prefix = nil)
        accounts = []
        
        # Use security dump-keychain and parse output
        # We need to look for entries with service="kc"
        output = `security dump-keychain login.keychain-db 2>/dev/null`
        
        # Split by keychain entries
        entries = output.split(/^keychain:/).drop(1)
        
        entries.each do |entry|
          # Check if this entry has svce="kc"
          if entry =~ /"svce"<blob>="#{SERVICE_NAME}"/
            # Extract account name
            if entry =~ /"acct"<blob>="([^"]+)"/
              account_name = $1
              # Filter by prefix if provided
              if prefix.nil? || account_name.start_with?(prefix)
                accounts << account_name
              end
            end
          end
        end

        accounts.sort.uniq
      end
    end
  end
end
