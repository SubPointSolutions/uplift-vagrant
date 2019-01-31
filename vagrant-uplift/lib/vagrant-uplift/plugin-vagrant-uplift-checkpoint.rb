begin
  require "vagrant"
rescue LoadError
  raise "The vagrant-uplift plugin must be run within Vagrant."
end

module VagrantPlugins::UpliftCheckpoint
  
    # https://superuser.com/questions/701735/run-script-on-host-machine-during-vagrant-up/992220#992220
    class Config < Vagrant.plugin("2", :config)
        attr_accessor :name
    end
  
    class Plugin < Vagrant.plugin("2")
        name "vagrant-uplift-checkpoint"
  
        config(:uplift_checkpoint, :provisioner) do
            Config
        end
  
        provisioner(:uplift_checkpoint) do
            Provisioner
        end
    end
  
    class Provisioner < Vagrant.plugin("2", :provisioner)
  
        def provision
            machine_name    = @machine.name
            checkpoint_name = config.name
          
            dir = ".vagrant/machines/#{machine_name}/virtualbox/.uplift/"
            
            FileUtils.mkdir_p dir
            file_name =File.join(dir, ".checkpoint-#{checkpoint_name}")
  
            File.write(file_name, 'ok')
        end
    end
    
  end