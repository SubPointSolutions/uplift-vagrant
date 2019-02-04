
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
#require_relative 'lib\vagrant-uplift\version.rb'

Gem::Specification.new do |spec|
  spec.name          = "vagrant-uplift"
  #spec.version       = VagrantPlugins::Uplift::VERSION
  spec.version       = "0.1.0"
  spec.authors       = ["SubPointSupport"]
  spec.email         = ["support@subpointsolutions.com"]

  spec.summary       = 'Simplifies windows infrastructure management for your Vagrant VM'
  spec.description   = 'Use vagrant-uplift to heavylift common windows installation rounties for DC, SQL, and SharePoint Vagrant VM'
  spec.homepage      = "http://subpointsolutions.com/uplift"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # if spec.respond_to?(:metadata)
  #   spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  # else
  #   raise "RubyGems 2.0 or newer is required to protect against " \
  #     "public gem pushes."
  # end

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir['bin/*'] 
  spec.files += Dir['lib/**/*.rb']
  spec.files += Dir['lib/**/*.ps1']
  spec.files += Dir['lib/.md']

  #spec.bindir        = "exe"
  #spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", '~> 0'
  spec.add_development_dependency "rake", '~> 0'
  spec.add_development_dependency "rspec", '~> 0'

end