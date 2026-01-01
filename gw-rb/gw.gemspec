lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "gw/version"

Gem::Specification.new do |spec|
  spec.name          = "gw"
  spec.version       = Gw::VERSION
  spec.authors       = ["AILERON"]
  spec.email         = ["masa@aileron.cc"]

  spec.summary       = "Git worktree manager with bare repository pattern"
  spec.description   = "A CLI tool to manage git worktrees using bare repository pattern (core/ and tree/ structure)"
  spec.homepage      = "https://github.com/aileron-inc/tools"
  spec.license       = "MIT"

  if spec.respond_to?(:metadata)
    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/aileron-inc/tools"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "octokit", "~> 9.0"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
end
