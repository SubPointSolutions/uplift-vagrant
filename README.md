# uplift-vagrant
This repository contains Vagrant plugin to the uplift project. The vagrant plugin provides a simplified configuration of DC, SQL, SharePoint and VS and designed to be used with uplift packer boxes.

The uplift project offers consistent Packer/Vagrant workflows and Vagrant boxes specifically designed for SharePoint professionals. It heavy lifts low-level details of the creation of domain controllers, SQL servers, SharePoint farms and Visual Studio installs by providing a codified workflow using Packer/Vagrant tooling.

## How this works
The uplift project is split into several repositories to address particular a piece of functionality:

* [uplift-powershell](https://github.com/SubPointSolutions/uplift-powershell) - reusable PowerShell modules
* [uplift-packer](https://github.com/SubPointSolutions/uplift-packer) - Packer templates for SharePoint professionals
* [uplift-vagrant](https://github.com/SubPointSolutions/uplift-vagrant) - Vagrant plugin to simplify Windows infrastructure provisioning 

The current repository houses Packer templates and automation which is used to produces Vagrant boxes across the uplift project.

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
`vagrant-uplift` provides additional helpers with Vagrant configuration to simplify domain controller creation, SQL servers provision, SharePoint farm provision and VS install.

Under the hood, plugin delivers a set of `powershell` scripts and DSC configs wrapped into Ruby helpers. All scripts live under `uplift-vagrant\vagrant-uplift\lib\scripts\vagrant` folder. 

The plugin enables the following Vagrant configuration possible:

### Turning a Vagrant box into a domain controller
```ruby
uplift = VagrantPlugins::Uplift::Config()

config.vm.define "dc" do | vm_config | 

  # .. some usual Vagrant configuration

  # uplift base configuration
  uplift.uplift_1Gb("dc", vm_config)
  uplift.uplift_win16_dsc_base("dc", vm_config)

  # uplift configuration to create domain controller
  uplift.uplift_private_dc_network("dc", vm_config)
  uplift.uplift_dc16("dc", vm_config)

end
```

### Joining Vagrant box to domain controller
```ruby
config.vm.define "client" do | vm_config | 

  # uplift base configuration
  uplift.uplift_4Gb("client", vm_config)
  uplift.uplift_win16_dsc_base("client", vm_config)

  # uplift config to join box to the domain controller
  uplift.uplift_client_network("client", vm_config, "client")
  uplift.uplift_dc_join("client", vm_config)

```

### Completing SQL image server
```ruby
config.vm.define "sql" do | vm_config | 

  # uplift base configuration
  uplift.uplift_4Gb("sql", vm_config)
  uplift.uplift_win16_dsc_base("sql", vm_config)

  # uplift config to join box to the domain controller
  uplift.uplift_client_network("sql", vm_config, "sql")
  uplift.uplift_dc_join("sql", vm_config)
  

  # uplift config to complete SQL image
  uplift.uplift_sql("sql", vm_config)

end
```

### Provisioning new SharePoint farm
```ruby
config.vm.define "spdev" do | vm_config | 

  # uplift base configuration
  uplift.uplift_6Gb("spdev", vm_config)
  uplift.uplift_win16_dsc_base("spdev", vm_config)

  # uplift config to join box to the domain controller
  uplift.uplift_client_network("spdev", vm_config, "spdev")
  uplift.uplift_dc_join("spdev", vm_config)
  

  # uplift config to complete SQL image
  uplift.uplift_sp16_pre_setup("spdev", vm_config)
  uplift.uplift_sp16_farm_only("spdev", vm_config, "sql")
  uplift.uplift_sp16_farm_post_setup("spdev", vm_config)

end
```

Additionally, `uplift-vagrant` offers a special provisioner called `:uplift_checkpoint`. Checkpoints ensure that Vagrant box won't be provisioned or rebooted over and over while run with `--provision` flag. This is important for heavy configurations done while configuring DC, SQL or SharePoint servers.

Here is how `:uplift_checkpoint` can be used. Every checkpoint creates a file under `.vagrant\machine\virtualbox\{machine-name}` folder and lives as long as the Vagrant box does. Recreating of the box cleans up ``.vagrant\machine\virtualbox` folder and all checkpoints are gone.

While using checkpoints, pay attention to checkpoint name, vagrant box name, and `has_checkpoint?` condition. It is verbose and typo-prone.

```ruby
uplift = VagrantPlugins::Uplift::Config()

config.vm.define "spdev" do | vm_config | 

  if !uplift.has_checkpoint?(vm_name_spdev, 'sp-farm-post-setup') 
      uplift.uplift_sp16_farm_post_setup(vm_name_spdev, vm_config)
      vm_config.vm.provision :uplift_checkpoint, name: 'sp-farm-post-setup'
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