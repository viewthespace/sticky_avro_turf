require_relative "lib/sticky_avro_turf/version"

Gem::Specification.new do |spec|
  spec.name = "sticky_avro_turf"
  spec.version = StickyAvroTurf::VERSION
  spec.authors = ["Tamim Mansour"]
  spec.email = ["tamim.mansour@vts.com"]

  spec.summary =
    "Library for serializing/deserializing Avro records using AWS Glue Schema Registry."
  spec.required_ruby_version = ">= 2.6.0"

  spec.files =
    Dir.chdir(__dir__) do
      `git ls-files -z`.split("\x0")
        .reject do |f|
          (f == __FILE__) ||
            f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
        end
    end
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.11"
  spec.add_development_dependency "libxml-ruby"
  spec.add_development_dependency "prettier", "~> 3.2"
  spec.add_development_dependency "rake", "~> 13.0"

  spec.add_dependency "avro_turf", "~> 1.7"
  spec.add_dependency "aws-sdk-glue", "~> 1.118"
end
