# uplift-vagrant
This repository contains Vagrant plugin to the uplift project. The vagrant plugin provides a simplified configuration of DC, SQL, SharePoint and VS and designed to be used with uplift packer boxes.

The uplift project offers consistent Packer/Vagrant workflows and Vagrant boxes specifically designed for SharePoint professionals. It heavy lifts low-level details of the creation of domain controllers, SQL servers, SharePoint farms and Visual Studio installs by providing a codified workflow using Packer/Vagrant tooling.

##  Build status
| Branch  | Status | 
| ------------- | ------------- |  
| master| [![Build status](https://ci.appveyor.com/api/projects/status/d0uti257xjwgj5or/branch/master?svg=true)](https://ci.appveyor.com/project/SubPointSupport/uplift-vagrant/branch/master) |  
| beta  | [![Build status](https://ci.appveyor.com/api/projects/status/d0uti257xjwgj5or/branch/beta?svg=true)](https://ci.appveyor.com/project/SubPointSupport/uplift-vagrant/branch/beta) |  
| dev   | [![Build status](https://ci.appveyor.com/api/projects/status/d0uti257xjwgj5or/branch/dev?svg=true)](https://ci.appveyor.com/project/SubPointSupport/uplift-vagrant/branch/dev) |  

## How this works
The uplift project is split into several repositories to address particular a piece of functionality:

* [uplift-powershell](https://github.com/SubPointSolutions/uplift-powershell) - reusable PowerShell modules
* [uplift-packer](https://github.com/SubPointSolutions/uplift-packer) - Packer templates for SharePoint professionals
* [uplift-vagrant](https://github.com/SubPointSolutions/uplift-vagrant) - Vagrant plugin to simplify Windows infrastructure provisioning 

The current repository houses Packer templates and automation which is used to produces Vagrant boxes across the uplift project.

## Before you begin
This vagrant plugin provides a simplified configuration of DC, SQL, SharePoint and VS and designed to be used with uplift packer boxes.

Please be aware that `vagrant-uplift` plugin is designed to work with `uplift-packer` boxes:
* https://github.com/SubPointSolutions/uplift-packer
* https://app.vagrantup.com/SubPointSolutions

The plugin provides **opinionated** infrastructure configuration, therefore, it uses and relies on other `powershell` modules to be already on the box. Otherwise, provision would be much longer than it is right now.

While it is encouraged to use [boxes provides by the uplift project](https://app.vagrantup.com/SubPointSolutions), it is still possible to use this plugin with other vagrant boxes.

A minimal set of things needed to be on the box before using `vagrant-uplift`:
* [Uplift.Core module](https://www.powershellgallery.com/packages/Uplift.Core)
* [InvokeUplift module](https://www.powershellgallery.com/packages/InvokeUplift)
* [chocolatey](https://chocolatey.org/)
* [powershell6 (pwsh)](https://github.com/PowerShell/PowerShell)
* [git, wget, curl](https://github.com/SubPointSolutions/uplift-packer/blob/master/packer/scripts/uplift.packer/image-soe/_choco_packages.ps1)
* [various `powershell` modules](https://github.com/SubPointSolutions/uplift-packer/blob/master/packer/scripts/uplift.packer/image-soe/_install-dsc-modules.ps1)


There are a few ways of getting these on the box:
* using [boxes provides by the uplift project](https://app.vagrantup.com/SubPointSolutions)
* manually installing all the above (using packer, vagrant or your own script)
* using experimental `uplift.provision_uplift_bootstrap(vm_name, vm_config)` method 

Please refer to `provision_uplift_bootstrap()` documentation for more details below.

## Installing `vagrant-uplift` plugin
`vagrant-uplift` is a normal Vagrant plugin distributed via [rubygems.org](https://rubygems.org/gems/vagrant-uplift). Refer to [Vagrant documentation](https://www.vagrantup.com/docs) for additional information.

```powershell
# listing installed plugins
vagrant plugin list

# installing vagrant-uplift plugin
vagrant plugin install vagrant-uplift 

# uninstalling vagrant-uplift plugin
vagrant plugin uninstall vagrant-uplift 
```

Alternatively, `vagrant-uplift` can be built from source code. Refer to the below documentation on the internals or run the following:
```powershell
git clone https://github.com/SubPointSolutions/uplift-vagrant
cd uplift-vagrant

invoke-build
```

## Using `vagrant-uplift` plugin
`vagrant-uplift` provides additional helpers with Vagrant configuration to simplify domain controller creation, SQL servers provision, SharePoint farm provision.

Under the hood, plugin delivers a set of `powershell` scripts and DSC configs wrapped into Ruby helpers. Such helpers are available in the Vagrant configuration files.

The powershell scripts can be found under `uplift-vagrant\vagrant-uplift\lib\scripts\vagrant` folder with the `gem` plugin folder or in the current repository.
All scripts live 

### `vagrant-uplift` helpers
The `vagrant-uplift` plugin provides several entry points which can be used in the Vagrant configuration files. Helper methods are exposed via Ruby class `VagrantPlugins::Uplift::Config()` and organized  into two subsets receiving `box name` and `vagrant box config` parameters:

```ruby
# create uplift configuration helper
uplift = VagrantPlugins::Uplift::Config()

# use 'set-xx' helper to configure Vagrant vm_config object
uplift.set_default_synced_folder("dc", vm_config)
uplift.set_2Gb("dc", vm_config)

uplift.set_hostname("dc", vm_config, "dc")

uplift.set_private_dc_network("dc", vm_config)
uplift.set_client_network("sql", vm_config, "sql")

# use 'provision-xx' helpers to use pre-configured Vagrant provisioners
uplift.provision_win16_dsc_soe("dc", vm_config)
uplift.provision_dc16("dc", vm_config)

uplift.provision_dc_join("client", vm_config)

uplift.provision_sql16_complete_image("client", vm_config)

uplift.provision_sp16_pre_setup("sp16", vm_config)
uplift.provision_sp16_single_server_farm("sp16", vm_config, "sql")
uplift.provision_sp16_farm_post_setup("sp16", vm_config)

```

For example, here are some configuration which can be used. 

### Turning a Vagrant box into a domain controller
```ruby
uplift = VagrantPlugins::Uplift::Config()

config.vm.define "dc" do | vm_config | 

  # .. some usual Vagrant configuration

  # uplift base configuration
  uplift.set_1Gb("dc", vm_config)
  uplift.provision_win16_dsc_soe("dc", vm_config)

  # uplift configuration to create domain controller
  uplift.set_private_dc_network("dc", vm_config)
  uplift.provision_dc16("dc", vm_config)

end
```

### Joining Vagrant box to domain controller
```ruby
config.vm.define "client" do | vm_config | 

  # uplift base configuration
  uplift.set_4Gb("client", vm_config)
  uplift.provision_win16_dsc_soe("client", vm_config)

  # uplift config to join box to the domain controller
  uplift.set_client_network("client", vm_config, "client")
  uplift.provision_dc_join("client", vm_config)

```

### Completing SQL image server
```ruby
config.vm.define "sql" do | vm_config | 

  # uplift base configuration
  uplift.set_4Gb("sql", vm_config)
  uplift.provision_win16_dsc_soe("sql", vm_config)

  # uplift config to join box to the domain controller
  uplift.set_client_network("sql", vm_config, "sql")
  uplift.provision_dc_join("sql", vm_config)
  

  # uplift config to complete SQL image
  uplift.provision_sql16_complete_image("sql", vm_config)

end
```

### Provisioning new SharePoint farm
```ruby
config.vm.define "spdev" do | vm_config | 

  # uplift base configuration
  uplift.set_6Gb("spdev", vm_config)
  uplift.provision_win16_dsc_soe("spdev", vm_config)

  # uplift config to join box to the domain controller
  uplift.set_client_network("spdev", vm_config, "spdev")
  uplift.provision_dc_join("spdev", vm_config)
  

  # uplift config to complete SQL image
  uplift.provision_sp16_pre_setup("spdev", vm_config)
  uplift.provision_sp16_single_server_farm("spdev", vm_config, "sql")
  uplift.provision_sp16_farm_post_setup("spdev", vm_config)

end
```

Additionally, `uplift-vagrant` offers a special provisioner called `:uplift_checkpoint`. Checkpoints ensure that Vagrant box won't be provisioned or rebooted over and over while run with `--provision` flag. This is important for heavy configurations done while configuring DC, SQL or SharePoint servers.

Here is how `:uplift_checkpoint` can be used. Every checkpoint creates a file under `.vagrant\machine\virtualbox\{machine-name}` folder and lives as long as the Vagrant box does. Recreating of the box cleans up ``.vagrant\machine\virtualbox` folder and all checkpoints are gone.

While using checkpoints, pay attention to checkpoint name, vagrant box name, and `has_checkpoint?` condition. It is verbose and typo-prone.

```ruby
uplift = VagrantPlugins::Uplift::Config()

config.vm.define "spdev" do | vm_config | 

  if !uplift.has_checkpoint?(vm_name_spdev, 'sp-farm-post-setup') 
      uplift.provision_sp16_farm_post_setup(vm_name_spdev, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'sp-farm-post-setup'
  end

```

It can be used with general Vagrant configuration as well. Once done, your provision logic will be run only once. `:uplift_checkpoint` provisioner saves the state and further vagrant operations won't be configured due to `uplift.has_checkpoint?` check.

```ruby
uplift = VagrantPlugins::Uplift::Config()

config.vm.define "client" do | vm_config | 

  if !uplift.has_checkpoint?("client", 'custom-provision') 
      vm_config.vm.provision "shell", path: 'scripts/my-custom-provision.ps1',
      vm_config.vm.provision :uplift_checkpoint, name: 'custom-provision'
  end

```

## `vagrant-uplift` helper methods
Prior helper usage, the configuration object needs to be created:
```ruby
uplift = VagrantPlugins::Uplift::Config()
```

All methods receive `box name` and `vagrant box config` parameters.

### `uplift.set_xxx()` methods

```ruby
# configures vagrant vm with giving RAM and CPUs
uplift.set_05Gb(vm_name, vm_config)
uplift.set_1Gb(vm_name, vm_config)
uplift.set_2Gb(vm_name, vm_config)
uplift.set_4Gb(vm_name, vm_config)
uplift.set_6Gb(vm_name, vm_config)
uplift.set_8Gb(vm_name, vm_config)
uplift.set_12Gb(vm_name, vm_config)
uplift.set_16Gb(vm_name, vm_config)

uplift.set_cpu_and_ram(vm_name, vm_config,  cpu, ram) 

# configures default winrm settings (:plaintext with vagrant:vagrant)
uplift.set_winrm(vm_name, vm_config) 

# disables default synced_folder for vagrant box
uplift.set_default_synced_folder(vm_name, vm_config) 

# configures hostname for the vagrant box
uplift.set_hostname(vm_name, vm_config) 

# configures private network for the vagrant box
# use for VMs to be promoted to domain controller
uplift.set_private_dc_network(vm_name, vm_config) 

# configures private network for the vagrant box
# use for VMs to be joined to domain controller.
uplift.set_client_network(vm_name, vm_config) 

# provisions shortcuts to common tools: 
# IE, PowerShell ISE, PS6, Server Manager, VS, SharePoint, SQL and others
uplift.provision_win16_dsc_shortcuts(vm_name, vm_config) 
```

### `uplift.provision_xxx()` - general 

```ruby
# provisions box with standard DSC config 
uplift.provision_win16_dsc_soe(vm_name, vm_config) 

# provisions box with standard shortcuts
uplift.provision_win16_dsc_shortcuts(vm_name, vm_config) 

# provisions domain controller, minimal config
uplift.provision_dc16(vm_name, vm_config) 

# provisions domain join for the giving box
uplift.provision_dc_join(vm_name, vm_config) 
```

### `uplift.provision_xxx()` - SQL specific 

```ruby
# completes SQL Server image
uplift.provision_sql16_complete_image(vm_name, vm_config) 

# optimizes SQL Server instance
# sets min/max memory and other tweaks
provision_sql16_optimize(vm_name, vm_config, min_memory: 1024, max_memory: 4096, instance_name: 'MSSQLSERVER' ) 
```

### `uplift.provision_xxx()` - SharePoint specific 

```ruby

# installs required packages for for SharePoint 2016 setup. 
# normally, should be already done under packer image, this is more of a shortcut for non-uplift boxes      
uplift.provision_sp16_image_packages_setup(vm_name, vm_config) 

# prepares box for SharePoint 2016 setup. 
# ensures CredSSP configs and other box-wide changes
# normally, should be already done under packer image, this is more of a shortcut for non-uplift boxes
uplift.provision_sp16_image_setup(vm_name, vm_config) 

# prepares box for SharePoint 2016 setup
# fixes IIS after sysprep, ensures that needed services are up
uplift.provision_sp16_pre_setup(vm_name, vm_config) 

# prepares SharePoint 2016 setup accounts
# https://absolute-sharepoint.com/2017/03/sharepoint-2016-service-accounts-recommendations.html
uplift.provision_sp16_sp_accounts(vm_name, vm_config) 

# Prepares SharePoint 2016 accounts required for SQL
uplift.provision_sp16_sql_accounts(vm_name, vm_config) 

# provisions SharePoint 2016 SingleServerFarm using SharePoint DSC
# does nothing but ne farm creation
uplift.provision_sp16_single_server_farm(vm_name, vm_config, sql_server, farm_prefix = nil, dsc_verbose: '1')

# provisions SharePoint 2016 minimal services 
# taxonomy, secure store, state service, search, user profile and others
# this is a default, opinionated config
# ! you are encouraged to use your own vagrant provision and DSC !
uplift.provision_sp16_minimal_services(vm_name, vm_config, sql_server, farm_prefix = nil, dsc_verbose: '1')

# provisions SharePoint 2016 post-setup, ensures all services work
uplift.provision_sp16_farm_post_setup(vm_name, vm_config) 

# provisions SharePoint 2016 web application with default settings
# this is a default, opinionated config
# ! you are encouraged to use your own vagrant provision and DSC !
uplift.provision_sp16_web_application(vm_name, vm_config) 
```

## Using `uplift-vagrant` with custom boxes

Originally, `vagrant-uplift` plugin is designed to work with `uplift-packer` boxes:
* https://github.com/SubPointSolutions/uplift-packer
* https://app.vagrantup.com/SubPointSolutions

The plugin provides **opinionated** infrastructure configuration, therefore, it uses and relies on other `powershell` modules to be already on the box. Otherwise, provision would be much longer than it is right now. 

While it is encouraged to use [boxes provides by the uplift project](https://app.vagrantup.com/SubPointSolutions), it is still possible to use this plugin with other vagrant boxes. 

`vagrant-uplift` provides a helper `provision_uplift_bootstrap` which provisions all needed packages on the custom box. Depending on the plugin version, the set of the package might be different. It is suggested to use checkpoints to ensure a single run of the initial provision per the box.

```ruby
  config.vm.define("my-vm") do | vm_config |   

    if !uplift.has_checkpoint?("my-vm", 'uplift-bootstrap') 
      uplift.provision_uplift_bootstrap("my-vm", vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'uplift-bootstrap'
    end

  end
```

## Local development workflow
Local development automation uses [Invoke-Build](https://github.com/nightroman/Invoke-Build) based tasks.

To get started, get the latest `dev` branch or fork the repo on the GitHub:
```shell
# get the source code
git clone https://github.com/SubPointSolutions/uplift-vagrant.git
cd uplift-vagrant

# checkout the dev branch
git checkout dev

# make sure we are on the dev branch
git status

# optionally, pull the latest
git pull
```

Local development experience consists of [Invoke-Build](https://github.com/nightroman/Invoke-Build) tasks. Two main files are `.build.ps1` and `.build-helpers.ps1`. Use the following tasks to get started and refer to `Invoke-Build` documentation for additional help.

Run `invoke-build ?` in the corresponding folder to see available tasks.

```powershell
# show available tasks
invoke-build ?

# executing default build
invoke-build 
invoke-build DefaultBuild

# executing QA workflow
invoke-build QA

# releasing to rubygems.org
invoke-build Release
```

## Feature requests, support and contributions
All contributions are welcome. If you have an idea, create [a new GitHub issue](https://github.com/SubPointSolutions/uplift-vagrant/issues). Feel free to edit existing content and make a PR for this as well.