# frozen_string_literal: true

module Gw
  class Error < StandardError; end

  class TokenNotFoundError < Error; end
  class RepositoryNotFoundError < Error; end
  class WorktreeAlreadyExistsError < Error; end
  class BranchNotFoundError < Error; end
  class ConfigError < Error; end
end
