begin
  require "vagrant"
rescue LoadError
  raise "The vagrant-uplift plugin must be run within Vagrant."
end

require_relative 'plugin-vagrant-uplift-checkpoint'
require_relative 'config_builder'

module VagrantPlugins::Uplift
    
    class Plugin < Vagrant.plugin("2")
      name "vagrant-uplift"
    end

end