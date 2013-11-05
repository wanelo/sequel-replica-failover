# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sequel-replica-failover/version'

Gem::Specification.new do |spec|
  spec.name          = "sequel-replica-failover"
  spec.version       = Sequel::ReplicaFailover::VERSION
  spec.authors       = ["Paul Henry"]
  spec.email         = ["paul@wanelo.com"]
  spec.description   = %q{Automatically failover between replicas when they go down.}
  spec.summary       = %q{Automatically failover when replicas go down.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "sequel", ">= 4.3.0"
  spec.add_dependency "ruby-usdt"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "guard-rspec"
end
