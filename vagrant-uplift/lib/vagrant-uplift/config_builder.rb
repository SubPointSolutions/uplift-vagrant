require_relative "log"
require_relative "appinsights"

require 'fileutils'
require 'securerandom'

module VagrantPlugins
  module Uplift
    
    class UpliftConfigBuilder

      @@logger = nil
      
      @@network_range    = '192.168.4'
      @@config_file_path = './.vagrant/uplift-vagrant'

      @@ai_client    = nil
      @@ai_config_id = nil

      @@plugin_version = 'v0.1.20190207.235938'

      @@supported_version = nil

      # initialize
      def initialize() 

        @@supported_version = '2.2.3'
        @@ai_config_id = SecureRandom.uuid.to_s

        if(Vagrant::VERSION != @@supported_version) 
          log_warn "WARN! - detected vagrant v#{Vagrant::VERSION}, uplift is tested on vagrant v#{@@supported_version}"
        end

        # disable warning:
        # WARNING: Vagrant has detected the `vagrant-winrm` plugin.
        ENV['VAGRANT_IGNORE_WINRM_PLUGIN'] = '1'

        log_info_light "vagrant-uplift #{@@plugin_version}"

        _track_ai_event('initialize')

        # track only first time initialization for the vagrantfile
        # further initializations won't be tracked
        # _track_first_initialize
      end

      def vagrant_script_path
        current_dir = File.dirname(__FILE__)
        File.expand_path(File.join(current_dir, "/../scripts"))
      end

      def get_config_path
        return @@config_file_path
      end

      def set_config_path(value)
        @@config_file_path = value
      end

      # Returns path to uplift config folder
      #
      # @return [String] path to uplift config folder
      def get_uplift_config_folder
        path = File.expand_path(@@config_file_path)
        FileUtils.mkdir_p path

        return path
      end

      # Returns path to uplift config file
      #
      # @return [String] path to uplift config file
      def get_uplift_config_file 
        config_dir_path = get_uplift_config_folder
        file_name = ".vagrant-network.yaml"

        return File.join(config_dir_path, file_name) 
      end

      # Sets 'machinefolder' property using 'vboxmanage' util
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param value [String] path to use for virtualbx vms
      def set_vbmanage_machinefolder(vm_name, vm_config, value = nil) 
        value = value || ENV['UPLF_VBMANAGE_MACHINEFOLDER'] 
        
        if !value.to_s.empty?
          log_info("#{vm_name}: vboxmanage machinefolder: #{value}")
          system("vboxmanage setproperty machinefolder #{value}")

          _track_ai_event(__method__, {
            'vm_name': vm_name
          })
        end
      end

      # Resets 'machinefolder' property to default using 'vboxmanage' util
      def set_vbmanage_machinefolder_default()
        system("vboxmanage setproperty machinefolder default")
        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # network helpers
      def get_network_range
        @@network_range
      end

      # Sets network range to be used in the multi-vm setup
      #
      # @param value [String] network range such as '192.168.10'
      def set_network_range(value)
        @@network_range = value
      end

      def get_ip_for_host(host_name) 
        start_index = 6

        file_path = get_uplift_config_file
        
        if(!File.exist? file_path)
            File.open(file_path,"w") do |f|
                f.write({}.to_yaml)
            end
        end

        map = YAML.load_file(file_path)

        if map.nil?
            map = {}
        end

        network_range = get_network_range

        ip_ranges_key = network_range 
        machine_key = host_name.downcase

        ips = map.fetch(ip_ranges_key, { }) 
        machine_ip = ips.fetch(machine_key, nil) 

        if machine_ip.nil? 
            machine_ip = network_range + "." + (start_index + ips.count).to_s
        end

        ips[machine_key]   = machine_ip
        map[ip_ranges_key] = ips

        File.open(file_path,"w") do |f|
            f.write(map.to_yaml)
        end        
      
        machine_ip
      end
      
      # log helpers
      def log_warn(message) 
        _logger.warn(message)
      end

      def log_warning(message) 
        _logger.warn(message)
      end

      def log_info(message) 
        _logger.info(message)
      end

      def log_info_light(message) 
        _logger.info_light(message)
      end

      def log_debug(message) 
        _logger.debug(message)
      end

      def log_error(message) 
        _logger.error(message)
      end

      def log_error_and_raise(message) 
        log_error(message)
        raise(message)
      end

      # Returns env variable value by name or default value
      #
      # @param name [String] env value name
      # @param default_value [object] default value
      # @return [object] env value
      def get_env_variable(name, default_value) 
        var_name  = name.upcase
        var_value = ENV[var_name]

        if var_value.to_s.empty? 
          return default_value
        end

        return var_value
      end
      
      # Returns cpus count for the giving vm name
      #
      # @param vm_name [String] vm name
      # @param default_value [object] default value
      # @return [String] cpus count
      def get_vm_cpus(vm_name, default_value) 
        require_string(vm_name)
        require_integer(default_value)

        return get_env_variable("UPLF_#{vm_name}_CPUS", default_value)
      end

      # Returns memory value for the giving vm name
      #
      # @param vm_name [String] vm name
      # @param default_value [object] default value
      # @return [String] memory value
      def get_vm_memory(vm_name, default_value) 
        require_string(vm_name)
        require_integer(default_value)

        return get_env_variable("UPLF_#{vm_name}_MEMORY", default_value)
      end
      
      # Returns checkpoint flag for the giving vm
      #
      # @param vm_name [String] vm name
      # @param checkpoint_name [String] checkpoint name
      # @return [Boolean] memory value
      def has_checkpoint?(vm_name, checkpoint_name) 

        if !ENV['UPLF_NO_VAGRANT_CHECKPOINTS'].nil?
          _log.info("#{vm_name}: [-] provision checkpoint: #{checkpoint_name} (UPLF_NO_VAGRANT_CHECKPOINTS is set)")
      
          return false 
        end
      
        file_name = ".vagrant/machines/#{vm_name}/virtualbox/.uplift/.checkpoint-#{checkpoint_name}"
        exists = File.exist?(file_name)
      
        if exists == true 
          _log.info_light("#{vm_name}: [+] provision checkpoint: #{checkpoint_name}")
        else 
          _log.info("#{vm_name}: [-] provision checkpoint: #{checkpoint_name}")
        end
      
        return exists
      end

      # Configures vagrant vm with 0.5G and 2 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_05Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        set_cpu_and_ram(vm_name, vm_config,  2, 512)
      end

      # Configures vagrant vm with 1G and 2 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_1Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)
        
        set_cpu_and_ram(vm_name, vm_config,  2, 1024)
      end

      # Configures vagrant vm with 2G and 2 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_2Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)
        
        set_cpu_and_ram(vm_name, vm_config,  2, 1024 * 2)
      end

      # Configures vagrant vm with 4G and 4 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_4Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        set_cpu_and_ram(vm_name, vm_config,  4, 1024 * 4)
      end

      # Configures vagrant vm with 6G and 4 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_6Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        set_cpu_and_ram(vm_name, vm_config,  4, 1024 * 6)
      end

      # Configures vagrant vm with 8G and 4 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_8Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        set_cpu_and_ram(vm_name, vm_config,  4, 1024 * 8)
      end

      # Configures vagrant vm with 12G and 4 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_12Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        set_cpu_and_ram(vm_name, vm_config,  4, 1024 * 12)
      end

      # Configures vagrant vm with 16G and 4 CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_16Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)
        
        set_cpu_and_ram(vm_name, vm_config,  4, 1024 * 16)
      end

      # Configures vagrant vm with giving RAM and CPUs
      #
      # @param vm_name [String] vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param cpu [String] amount of cpu
      # @param ram [String] amount of ram
      def set_cpu_and_ram(vm_name, vm_config,  cpu, ram) 

        ram_in_gb = (ram / 1024.0)

        # round evertything that bigger that 1
        if ram_in_gb >= 1
          ram_in_gb = ram_in_gb.round
        end

        log_info_light("#{vm_name}: #{ram_in_gb}Gb RAM, #{cpu} CPU")

          vm_config.vm.provider "virtualbox" do |v|
              
              v.linked_clone = false
        
              v.memory = ram
              v.cpus   = cpu
        
              v.gui  = false
              
              v.customize ['modifyvm', :id, '--clipboard', 'bidirectional'] 
              v.customize ["modifyvm", :id, "--vram", 32]

              v.customize ["modifyvm", :id, "--audio", "none"]
              v.customize ["modifyvm", :id, "--usb", "off"]
              
              # if Vagrant::VERSION >= '2.2.3'
              #   # Vagrant has detected a configuration issue which exposes a vulnerability with the installed version of VirtualBox
              #   # Ensure the guest is trusted to use this configuration or update the NIC type using one of the methods below:
              #   # https://www.vagrantup.com/docs/virtualbox/configuration.html#default-nic-type
              
              #   v.default_nic_type = "82543GC"
              # end

              # https://github.com/hashicorp/vagrant/issues/6812#issuecomment-171981576
              # Vagrant is reconnecting from scratch, sometimes literally before each command in negotiating loop
              v.customize ['modifyvm', :id, "--natdnshostresolver1", "off"]
          end
          
          # tracking only our own boxes
          # subpoint | uplift
          box_name    = 'other'
          box_version = 'other'

          begin
            box_name = vm_config.vm.box()
          rescue => e
            box_name = 'not_set'
          end

          if( box_name.to_s.downcase.start_with?('subpoint') || box_name.to_s.downcase.start_with?('uplift') ) 
            begin
              box_version = vm_config.vm.box_version()
            rescue => e
              box_version = 'not_set'
            end
          else 
            box_name    = 'other'
            box_version = 'other'
          end

          data = {
            'vm_name': vm_name,
            'cpus': cpu,
            'memory': ram,
            'box_name': box_name,
            'box_version': box_version
          }

          _track_ai_event(__method__, data)
      end

      # Requires value to be integer
      #
      # @param value [object] value
      def require_integer(value)
        if value.is_a?(Integer) != true
          log_error_and_raise("expected integer value, got #{value.class}, #{value.inspect}")
        end
      end

      # Requires value to be string
      #
      # @param value [String] value
      def require_string(value)
        if value.nil? == true || value.to_s.empty?
          log_error_and_raise("expected string value, got nil or empty string")
        end

        if value.is_a?(String) != true
          log_error_and_raise("expected string value, got #{value.class}, #{value.inspect}")
        end

      end

      # Requires value to be [Vagrant::Config::V2::Root]
      #
      # @param value [object] value
      def require_vagrant_config(value)
        if value.nil? == true 
          log_error_and_raise("expected string value, got nil or empty string")
        end

        if value.is_a?(Vagrant::Config::V2::Root) != true
          log_error_and_raise("expected Vagrant::Config::V2::Root value, got #{value.class}, #{value.inspect}")
        end

      end
 
      # Configures vagrant vm with the default winrm settings
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_winrm(vm_name, vm_config) 
        require_string(vm_name)
        require_vagrant_config(vm_config)
     
        log_info_light("#{vm_name}: winrm config")

        # https://www.vagrantup.com/docs/vagrantfile/winrm_settings.html

        vm_config.vm.guest = :windows

        vm_config.vm.boot_timeout = 300

        vm_config.vm.communicator = "winrm"
        vm_config.winrm.transport = :plaintext
        vm_config.winrm.basic_auth_only = true

        vm_config.winrm.ssl_peer_verification = false

        vm_config.winrm.username = "vagrant"
        vm_config.winrm.password = "vagrant"

        # HTTPClient::KeepAliveDisconnected: An existing connection was forcibly closed by the remote host #6430
        # https://github.com/hashicorp/vagrant/issues/6430
        # https://github.com/hashicorp/vagrant/issues/8323
        vm_config.winrm.retry_limit = 30
        vm_config.winrm.retry_delay = 10
      end

      # Disables default synced_folder for vagrant box
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_default_synced_folder(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: synced folders config")
        
        vm_config.vm.synced_folder ".", "/vagrant", disabled: true
      end

      def execute_tests?(vm_config:)
        return true
      end

      def execute_tests(vm_config:, paths:, env: {}, privileged: false)

        if !execute_tests?(vm_config: vm_config)
            _log.info "   - pester: skipping test execition due to false flag in properties"
            return
        end

        if !paths.is_a?(Array)
            paths = [paths]
        end

        paths.each do | path |
          test_path_value = File.basename(path)

          _log.debug "   - pester test path: #{test_path_value}"
        end

        paths.each do |src_test_path|
    
            test_files = Dir[src_test_path]
            test_files_string = "\n - " + test_files.join("\n - ")
            _log.debug "  - scanned: #{src_test_path}, found: #{test_files_string}"
            
            if test_files.empty?
                _log.warn "[!] cannot find any test files under path: #{src_test_path} - mostlikely, wrong location/pattern"
            end

            test_files.each do |fname|

                test_path_value = File.basename(fname)

                _log.info  "   - pester test: #{test_path_value}"
                _log.debug "adding test file: #{fname}"
               
                src_path = fname
                dst_path = "c:/windows/temp/tests/" + File.basename(fname)
    
                vm_config.vm.provision :file do |file|
                    file.source = fname
                    file.destination = dst_path
                end
    
                vm_config.vm.provision "shell", 
                  inline: "Invoke-Pester -EnableExit -Script #{dst_path}", 
                  name: dst_path,
                  env: env
            end
        end
    
      end

      # Configures hostname for the vagrant box
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param hostname [String] hostname
      def set_hostname(vm_name, vm_config, hostname)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        require_string(hostname)

        log_info_light("#{vm_name}: setitng hostname: #{hostname}")
        vm_config.vm.hostname = hostname
      end

      # Configures private network for the vagrant box. Use for VMs to be promoted to domain controller.
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param ip [String] ip value
      # @param gateway [String] gateway value
      def set_private_network(vm_name, vm_config, ip: '', gateway: '') 
        
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info(" - ip: #{ip}, gateway: #{gateway}")

        vm_config.vm.network :private_network, ip: ip, gateway: gateway
      end

      # Configures client network for the vagrant box. Use for VMs to be joined to domain controller.
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param ip [String] ip value
      # @param gateway [String] gateway value
      def set_client_network(vm_name, vm_config, hostname) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        require_string(hostname)

        network_range = get_network_range

        dc_ip      = "#{network_range}.5"
        machine_ip = get_ip_for_host(hostname)
        
        log_info("  - private network: ip: #{machine_ip} gateway: #{network_range}.1") 
        vm_config.vm.network :private_network, 
            ip: machine_ip, gateway: "#{network_range}.1"

        log_info("  - fixing secondary network interface: ip: #{machine_ip} dns: #{dc_ip}") 
        vm_config.vm.provision "shell", 
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.core/uplift.fix-second-network.ps1", 
            args: "-ip #{machine_ip} -dns #{dc_ip}"
      end

      # Configures private network for the vagrant box to be promoted to domain controller.
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def set_private_dc_network(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: private dc network")
        
        network_range = get_network_range

        set_private_network(
          vm_name,
          vm_config,
          :ip      => "#{network_range}.5",
          :gateway => "#{network_range}.1"
        )
      
      end

      # Provisions box with standard config
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_win16_dsc_soe(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: dsc soe config")

        vm_config.vm.provision "shell", 
          name: "soe.dsc.ps1",
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.win12soe/soe.dsc.ps1",
          env: {
            "UPLF_DSC_CHECK" => 1
          }

          execute_tests(
            vm_config: vm_config, 
            paths: "#{vagrant_script_path}/vagrant/uplift.vagrant.win12soe/tests/soe.dsc.*"
          )
      end

      # Provisions box with standard shortcuts
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_win16_dsc_shortcuts(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: dsc soe shortcuts")

        vm_config.vm.provision "shell", 
          name: "soe.shortcuts.dsc.ps1",
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.win12soe/soe.shortcuts.dsc.ps1",
          env: {
            "UPLF_DSC_CHECK" => 1
          }
      end

      # Provisions domain controller, minimal config
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_win16_dsc_dc(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info(" - dc provision")
        
        # just in case there are outstanding tasks
        vm_config.vm.provision "reload"

        vm_config.vm.provision "shell", 
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.dc12/dc.dsc.ps1", 
          name: "dc.dsc.ps1",
          env: {
            "UPLF_DC_DOMAIN_NAME"           => "uplift.local",
            "UPLF_DC_DOMAIN_ADMIN_NAME"     => "admin",
            "UPLF_DC_DOMAIN_ADMIN_PASSWORD" => "uplift!QAZ",

            "UPLF_DSC_CHECK_SKIP"           => 1
          }

        vm_config.vm.provision "reload"

        execute_tests(
          vm_config: vm_config, 
          paths: "#{vagrant_script_path}/vagrant/uplift.vagrant.dc12/tests/dc.dsc.*"
        )

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions domain controller users, minimal config
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_win16_dsc_dc_users(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info(" - domain users")

        vm_config.vm.provision "shell", 
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.dc12/dc.users.dsc.ps1",
          name: 'dc.users.dsc.ps1', 
          env: {
            "UPLF_DC_DOMAIN_NAME"           => "uplift",
            "UPLF_DC_DOMAIN_ADMIN_NAME"     => "admin",
            "UPLF_DC_DOMAIN_ADMIN_PASSWORD" => "uplift!QAZ",

            "UPLF_VAGRANT_USER_NAME"        => "vagrant",
            "UPLF_VAGRANT_USER_PASSWORD"    => "vagrant"
          }

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions domain controller and users, minimal config
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_dc16(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: domain controller setup")
       
        provision_win16_dsc_dc(vm_name, vm_config)
        provision_win16_dsc_dc_users(vm_name, vm_config)

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions domain join for the giving box
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_dc_join(vm_name, vm_config)
        
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: domain join")

        network_range = get_network_range
        dc_ip      = "#{network_range}.5"

        log_info("  - dc_ip: #{dc_ip}")
        
        vm_config.vm.provision "shell", 
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.dcjoin/dc.join.dsc.ps1", 
            env: {
                "UPLF_DC_DOMAIN_NAME"        => "uplift",
                
                "UPLF_DC_JOIN_USER_NAME"     => "admin",
                "UPLF_DC_JOIN_USER_PASSWORD" => "uplift!QAZ",

                "UPLF_DC_DOMAIN_HOST_IP"     => "#{dc_ip}"
            }
            
        vm_config.vm.provision "reload"
       
        vm_config.vm.provision "shell",
            name: "dc.join.hostname.ps1",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.dcjoin/dc.join.hostname.ps1"

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })         
      end

      # Provisions SharePoint 2016 pre-setup, prepares box for SharePoint 2016 setup.
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_pre_setup(vm_name, vm_config) 
      
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: farm pre-setup")

        # shared scripts
        vm_config.vm.provision "file", 
                source: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/shared/sp.helpers.ps1", 
                destination: "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

        # presetup sharepoint farm
        # - fix iss
        # - reboot
        # - restore all services
        vm_config.vm.provision "shell",
          name: 'sp-pre_setup1',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.pre_setup1.dsc.ps1"

        vm_config.vm.provision "reload"

        vm_config.vm.provision "shell",
          name: 'sp-pre_setup2',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.pre_setup2.dsc.ps1"

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Prepares box for SharePoint 2016 setup. 
      # Ensures CredSSP configs and other box-wide changes
      # Normally, should be already done under packer image, this is more of a shortcut for non-uplift boxes

      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_image_setup(vm_name, vm_config) 
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: image setup")

        vm_config.vm.provision "shell",
          name: 'image-setup',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.sp-image-setup.dsc.ps1"

        vm_config.vm.provision "reload"

        vm_config.vm.provision "shell",
          name: 'image-setup-dsc-check',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.sp-image-setup.dsc.ps1",
          env: {
            "UPLF_DSC_CHECK" => 1
          }

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Installs required packages for for SharePoint 2016 setup. 
      # Normally, should be already done under packer image, this is more of a shortcut for non-uplift boxes
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_image_packages_setup(vm_name, vm_config) 
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: image setup")

        vm_config.vm.provision "shell",
          name: 'image-packages-setup',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/_sp2013_image_packages.dsc.ps1"

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Prepares SharePoint 2016 setup accounts
      # https://absolute-sharepoint.com/2017/03/sharepoint-2016-service-accounts-recommendations.html
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_sp_accounts(vm_name, vm_config) 
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: image setup")

        vm_config.vm.provision "shell",
          name: 'sp-accounts-setup',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.sp-accounts.dsc.ps1",
          env: {
            "UPLF_DSC_CHECK" => 1
          }

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Prepares SharePoint 2016 accounts required for SQL
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_sql_accounts(vm_name, vm_config) 
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: image setup")

        vm_config.vm.provision "shell",
          name: 'sp-sql-accounts-setup',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.sp-accounts.dsc.ps1",
          env: {
            "UPLF_DSC_CHECK" => 1
          }

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions SharePoint 2016 post-setup, ensures all services work
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_farm_post_setup(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: farm post-setup")

        vm_config.vm.provision "shell",
            name: 'sp-post-setup',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.post_setup.dsc.ps1"

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions SharePoint 2016 information gatherer
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sp16_print_info(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: print info")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.info.ps1"

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions SharePoint 2016 SingleServerFarm using SPFarm DSC
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param sql_server [String] sql server host name
      # @param farm_prefix [String] sql server DBs prefix to use for the current SharePoint farm install
      def provision_sp16_single_server_farm(vm_name, vm_config, sql_server, farm_prefix = nil, dsc_verbose: '1') 

        if farm_prefix.nil? 
          farm_prefix = "#{vm_name}_"
        end

        require_string(vm_name)
        require_vagrant_config(vm_config)

        require_string(sql_server)
        require_string(farm_prefix)

        log_info_light("#{vm_name}: SharePoint 2016: farm creation only")

        # shared scripts
        vm_config.vm.provision "file", 
                source: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/shared/sp.helpers.ps1", 
                destination: "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

        env = {
            "UPLF_sp_farm_sql_server_host_name"  => sql_server,
            "UPLF_sp_farm_sql_db_prefix"         => "#{farm_prefix}_",
            "UPLF_sp_farm_passphrase"            => "uplift!QAZ",
            
            "UPLF_sp_setup_user_name"     => "uplift\\vagrant",
            "UPLF_sp_setup_user_password" => "vagrant",
            "UPLF_DSC_VERBOSE" => dsc_verbose
        }

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.farm-only.dsc.ps1",
            env: env     
            
        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions SharePoint 2016 minimal services: taxonomy, secure store, state service, search, user profile service and others
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param sql_server [String] sql server host name
      # @param farm_prefix [String] sql server DBs prefix to use for the current SharePoint farm install
      def provision_sp16_minimal_services(vm_name, vm_config, sql_server, farm_prefix = nil, dsc_verbose: '1', dsc_check: '1') 
        
        if farm_prefix.nil? 
          farm_prefix = "#{vm_name}_"
        end
        
        require_string(vm_name)
        require_vagrant_config(vm_config)

        require_string(sql_server)
        require_string(farm_prefix)

        log_info_light("#{vm_name}: SharePoint 2016: minimal services: taxonomy, secure store, state service, search, user profile service")

        # shared scripts
        vm_config.vm.provision "file", 
          source: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/shared/sp.helpers.ps1", 
          destination: "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

        env = {
            "UPLF_sp_farm_sql_server_host_name"  => sql_server,
            "UPLF_sp_farm_sql_db_prefix"         => "#{farm_prefix}_",
            
            "UPLF_sp_setup_user_name"     => "uplift\\vagrant",
            "UPLF_sp_setup_user_password" => "vagrant",
            
            "UPLF_DSC_VERBOSE" => dsc_verbose,
            "UPLF_DSC_CHECK" => dsc_check,
        }

        vm_config.vm.provision "shell",
            name: 'sp-minimal-services',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.farm-minimal-services.dsc.ps1",
            env: env   
        
        execute_tests(
          vm_config: vm_config, 
          paths: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/tests/sp2016.minimal-services.Tests.ps1"
        )  
            
        _track_ai_event(__method__, {
          'vm_name': vm_name
        })

      end 

      def provision_sp16_web_application(vm_name, vm_config, dsc_verbose: '1', dsc_check: '1') 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        env = {
          "UPLF_SP_SETUP_USER_NAME"     => "uplift\\vagrant",
          "UPLF_SP_SETUP_USER_PASSWORD" => "vagrant",
          
          "UPLF_DSC_VERBOSE" => dsc_verbose,
          "UPLF_DSC_CHECK" => dsc_check,

          "UPLF_SP_WEB_APP_PORT" => "80"
        }

      vm_config.vm.provision "shell",
          name: 'sp-web-application',
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.web-application.dsc.ps1",
          env: env   
      end

      # Completes SQL Server image
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_sql16_complete_image(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SQL 2016: image completion")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sql12/sql.complete.dsc.ps1"
               
        execute_tests(
          vm_config: vm_config, 
          paths: "#{vagrant_script_path}/vagrant/uplift.vagrant.sql12/tests/sql16.dsc.*"
        )

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions SQL server optimization
      # Sets min/max memory and other tweaks
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      # @param min_memory [String] min memory, default 1024
      # @param max_memory [String] max memory, default 4096
      def provision_sql16_optimize(vm_name, vm_config, 
        min_memory: 1024, max_memory: 4096, instance_name: 'MSSQLSERVER',
        dsc_verbose: '1', dsc_check: '1' ) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SQL 2016: optimization")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sql12/sql.optimize.dsc.ps1",
            env: {
              "UPLF_SQL_SERVER_NAME"  => vm_name,
              "UPLF_SQL_INSTANCE_NAME" => instance_name,
              "UPLF_SQL_MIN_MEMORY"   => min_memory,
              "UPLF_SQL_MAX_MEMORY"   => max_memory,

              "UPLF_DSC_VERBOSE" => dsc_verbose,
              "UPLF_DSC_CHECK" => dsc_check,
            }
             
        _track_ai_event(__method__, {
          'vm_name': vm_name
        })
      end

      # Provisions box with the minimal oconfiguration to enable uplift
      # That allows uplift usage on custom vagrant boxes
      # - installs uplift.core ps module
      # - installs various dsc modules
      #
      # @param vm_name [String] vagrant vm name
      # @param vm_config [Vagrant::Config::V2::Root] vagrant vm config
      def provision_uplift_bootstrap(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: Uplift bootstrap")

        vm_config.vm.provision "shell",
            name: 'uplift.bootstrap',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.bootstrap/uplift.bootstrap.ps1"

        vm_config.vm.provision "shell",
            name: 'uplift.choco',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.bootstrap/uplift.bootstrap.choco.ps1"

        vm_config.vm.provision "shell",
            name: 'uplift.choco-packages',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.bootstrap/uplift.bootstrap.choco-packages.ps1"            

        vm_config.vm.provision "shell",
            name: 'uplift.dsc.bootstrap',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.bootstrap/uplift.bootstrap.ps-modules.ps1"            
               
        vm_config.vm.provision "shell",
            name: 'uplift.resource-modul',
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.bootstrap/uplift.resource.bootstrap.ps1"                        
            

        _track_ai_event(__method__, {
          'vm_name': vm_name
        })

      end

      private

      def _logger 
        @@logger = @@logger || VagrantPlugins::Uplift::Log.get_logger
        @@logger
      end

      def _ai_client 
        ai_key = ENV['UPLF_APPINSIGHTS_KEY'] || 'c297a2cc-8194-46ac-bf6b-46edd4c7d2c9'

        @@ai_client = @@ai_client || VagrantPlugins::Uplift::AppInsights.get_client(ai_key)
        @@ai_client
      end

      def _log
        _logger
      end

      def _is_privileged_shell?
        # https://github.com/hashicorp/vagrant/issues/9138#issuecomment-444408251
        # https://github.com/clong/DetectionLab/issues/172
  
        result = Vagrant::VERSION < '2.2.1'
  
        log_debug "_is_privileged_shell: #{result}"
  
        result
      end
  
      def _is_powershell_elevated_interactive?
        # https://github.com/hashicorp/vagrant/issues/9138#issuecomment-444408251
        # https://github.com/clong/DetectionLab/issues/172
  
        result = Vagrant::VERSION < '2.2.1'
  
        # join to dc issue
        # workgroup 'WORKGROUP' with following error message: Unable to update the password. The value
        # Computer 'WIN-SN2UMLHU29M' failed to join domain 'uplift' from its current workgroup 'WORKGROUP' with following error message: Unable to update the password. 
        # The value provided as the current password is incorrect.
        
        # http://www.gi-architects.co.uk/2017/01/powershell-add-computer-error-when-executed-remotely/
  
        log_debug "is_powershell_elevated_interactive: #{result}"
  
        result
      end

      def _track_first_initialize()
        path = File.expand_path(@@config_file_path)
        FileUtils.mkdir_p path

        first_initialize_file = "#{@@config_file_path}/.appinsights-first-init-#{@@plugin_version}"

        if(File.exist?(first_initialize_file) == false)
          log_debug("AppInsight: tracking first initialize event")
          track_ai_event('initialize')

          File.open(first_initialize_file, "w") do |f|
            f.write("ok")
          end  
        end
      end

      def _track_ai_event(name, properties = {}) 
        uplift_vagrant_event = 'uplift-vagrant.func'
        
        log_debug("AppInsight: tracking event: #{name}")
        _ai_client.track_event(
          uplift_vagrant_event, 
          properties.merge(_get_default_ai_properties(name))
        )

      end

      def _get_default_ai_properties(name)
        {
          'plugin_version' => @@plugin_version,
          'success' => true,
          'ruby_platform' => RUBY_PLATFORM,
          'vagrant_version' => Vagrant::VERSION,
          'config_id' => @@ai_config_id,
          'name' => name
        }
      end

    end

    def self.Config
      return UpliftConfigBuilder.new
    end

  end
  
end
