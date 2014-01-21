# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'acoc/version'

Gem::Specification.new do |spec|
  spec.name          = "acoc"
  spec.version       = ACOC::VERSION
  spec.authors       = ["Ian Macdonald"]
  spec.email         = ["ian@caliban.org"]
  spec.description   = <<END
`acoc` is a regular expression based colour formatter for programs
that display output on the command-line.

It works as a wrapper around the target program, executing it
and capturing the stdout stream. Optionally, stderr can
be redirected to stdout, so that it, too, can be manipulated.

`acoc` then applies matching rules to patterns in the output
and applies colour sets to those matches.
END
  spec.summary       = 'Arbitrary Command Output Colourer'
  spec.homepage      = "http://caliban.org/ruby/acoc.shtml"
  spec.license       = "GPL-2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "term-ansicolor"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
