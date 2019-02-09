# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.require_version ">= 2.2.3"

box_name        = ENV['UPLF_VAGRANT_BOX_NAME']        || "SubPointSolutions/win-2016-datacenter-sp2016latest-sql16-vs17" 
box_name_custom = ENV['UPLF_VAGRANT_CUSTOM_BOX_NAME'] || "gusztavvargadr/w16s" 

linked_clone   =  ENV['UPLF_VAGRANT_LINKED_CLONE'].to_s.empty? == false
machine_folder =  ENV['UPLF_VBMANAGE_MACHINEFOLDER'] || nil

# two vm topology: dc and client, minimal testing
# - dc box gets promoted to minimal domain controller
# - client box gets a dc join. SQL/SharePoint cases are tested within uplift-packer project
# https://github.com/SubPointSolutions/uplift-packer

# additionally, bootstrap dc on the custom box
# that ensures that uplift-vagrant can detedt non-uplift box and bootstrap from there
# https://app.vagrantup.com/mwrock/boxes/Windows2016

vm_dc     = "dc"
vm_client = "dc-cl"

vm_dc_custom     = "custom-dc"
vm_client_custom = "custom-dc-cl"

# this configuration is driven by the ENV variables
# use the following variables to change default RAM/CPU allocation
# 
# UPLF_DC_MEMORY      / UPLF_DC_CPUS 
# UPLF_CLIENT_MEMORY / UPLF_CLIENT_CPUS 

# UPLF_DC_CST_MEMORY      / UPLF_DC_CST_CPUS 
# UPLF_CLIENT_CST_MEMORY  / UPLF_CLIENT_CST_CPUS 

# uplift helper for vagrant configurations
uplift = VagrantPlugins::Uplift::Config()

uplift.set_network_range("192.168.15")

def configure_dc(uplift, vm_dc, vm_config, box_name, linked_clone) 
    vm_config.vm.box = box_name

    # standard config
    uplift.set_default_synced_folder(vm_dc, vm_config)
    uplift.set_2Gb(vm_dc, vm_config)
    uplift.set_hostname(vm_dc, vm_config, vm_dc)
    
    # always setup correct networking
    uplift.set_private_dc_network(vm_dc, vm_config)
    
    # uplift baseline
    if !uplift.has_checkpoint?(vm_dc, 'dsc-soe') 
      uplift.provision_win16_dsc_soe(vm_dc, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'dsc-soe'
    end

    # uplift dc creation
    if !uplift.has_checkpoint?(vm_dc, 'dc-creation') 
      uplift.provision_dc16(vm_dc, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'dc-creation'
    end

    # additional virtualbox tweaks
    vm_config.vm.provider "virtualbox" do |v|
      v.gui  = false
     
      v.cpus   = uplift.get_vm_cpus(vm_dc, 4)
      v.memory = uplift.get_vm_memory(vm_dc, 2 * 1024)

      v.customize ['modifyvm', :id, '--cpuexecutioncap', '100'] 
      v.customize ["modifyvm", :id, "--ioapic", "on"]

      v.linked_clone = linked_clone
    end
end

def configure_client(uplift, vm_client, vm_config, box_name, linked_clone) 
    # box config
    vm_config.vm.box = box_name
    vm_config.vm.box_check_update = false

    # uplift - base config
    uplift.set_default_synced_folder(vm_client, vm_config)
    uplift.set_2Gb(vm_client, vm_config)
    uplift.set_hostname(vm_client, vm_config, vm_client)   

    # uplift - network, base provision + dc join
    uplift.set_client_network(vm_client, vm_config, vm_client)

    if !uplift.has_checkpoint?(vm_client, 'dsc-soe') 
      uplift.provision_win16_dsc_soe(vm_client, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'dsc-soe'
    end

    if !uplift.has_checkpoint?(vm_client, 'dc-join') 
      uplift.provision_dc_join(vm_client, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'dc-join'
    end

    if !uplift.has_checkpoint?(vm_client, 'dsc-shortcuts') 
      uplift.provision_win16_dsc_shortcuts(vm_client, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'dsc-shortcuts'
    end

    # virtualbox tuning
    vm_config.vm.provider "virtualbox" do |v|
      v.gui  = false
      
      v.cpus   = uplift.get_vm_cpus(vm_client, 4)
      v.memory = uplift.get_vm_memory(vm_client, 2 * 1024)

      v.customize ['modifyvm', :id, '--cpuexecutioncap', '100'] 
      v.customize ["modifyvm", :id, "--ioapic", "on"]

      v.linked_clone = linked_clone
    end
end

Vagrant.configure("2") do |config|
  
  # additional plugins to be used with this vagrant config
  config.vagrant.plugins = [
    "vagrant-reload",
    "vagrant-uplift"
  ]

  # -- uplift box config

  # domain controller box
  config.vm.define(vm_dc) do | vm_config |      

    # -- UPLIFT CONFIG START --
    # there should not be a need to modify core uplift configration
    # avoid making changes to it, add your own provision at the end

    configure_dc(uplift, vm_dc, vm_config, box_name, linked_clone)    

    # -- UPLIFT CONFIG END --
    # add your custom vagrant configuration here

  end  

  # client box
  config.vm.define "#{vm_client}" do | vm_config |   
    
    # -- UPLIFT CONFIG START --
    # there should not be a need to modify core uplift configration
    # avoid making changes to it, add your own provision at the end

    configure_client(uplift, vm_client, vm_config, box_name, linked_clone)    

    # -- UPLIFT CONFIG END --

    # add your custom vagrant configuration here

  end  

  # -- custom box config

  # domain controller box
  config.vm.define(vm_dc_custom) do | vm_config |      

    # -- UPLIFT CONFIG START --
    # there should not be a need to modify core uplift configration
    # avoid making changes to it, add your own provision at the end

    if !uplift.has_checkpoint?(vm_dc_custom, 'uplift-bootstrap') 
      uplift.provision_uplift_bootstrap(vm_dc_custom, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'uplift-bootstrap'
    end

    configure_dc(uplift, vm_dc, vm_config, box_name_custom, linked_clone)    

    # -- UPLIFT CONFIG END --
    # add your custom vagrant configuration here

  end  

  # client box
  config.vm.define(vm_client_custom) do | vm_config |   
    
    # -- UPLIFT CONFIG START --
    # there should not be a need to modify core uplift configration
    # avoid making changes to it, add your own provision at the end

    # if !uplift.has_checkpoint?(vm_client_custom, 'uplift-bootstrap') 
    #   uplift.provision_uplift_bootstrap(vm_client_custom, vm_config)
    #   vm_config.vm.provision :uplift_checkpoint, name: 'uplift-bootstrap'
    # end

    configure_client(uplift, vm_client_custom, vm_config, box_name_custom, linked_clone)    

    # -- UPLIFT CONFIG END --

    # add your custom vagrant configuration here

  end  

end