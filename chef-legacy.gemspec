Gem::Specification.new do |s|
  s.name          = "chef-legacy"
  s.homepage      = "https://github.com/gofullstack/chef-legacy"
  s.version       = "1.0.0"
  s.summary       = "Legacy Opscode Community Data"
  s.description   = "Rake tasks to import legacy Opscode Community Site data"
  s.authors       = ["Tristan O'Neil", "Brian Cobb"]
  s.email         = ["tristan@gofullstack.com", "brian@gofullstack.com"]
  s.files         = Dir["lib/**/*"] + ["LICENSE", "README.md"]
  s.test_files    = []
  s.require_paths = ["lib"]
  s.license    = 'MIT'

  s.add_runtime_dependency "mysql2"
  s.add_runtime_dependency "ruby-progressbar"
  s.add_runtime_dependency "connection_pool"
end
