require_relative "log"
require 'fileutils'

module VagrantPlugins
  module Uplift
    
    class UpliftConfigBuilder

      @@logger = nil
      
      @@network_range    = '192.168.4'
      @@config_file_path = './.vagrant/uplift-vagrant'

      # initialize
      def initialize() 
        supported_version = '2.2.3'

        if(Vagrant::VERSION != supported_version) 
          log_warn "WARN! - detected vagrant v#{Vagrant::VERSION}, uplift is tested on vagrant v#{supported_version}"
        end

        # disabple this warning
        # WARNING: Vagrant has detected the `vagrant-winrm` plugin.
        ENV['VAGRANT_IGNORE_WINRM_PLUGIN'] = '1'

        log_info_light "vagrant-uplift v0.1.0"
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

      # state configs
      def get_uplift_config_folder
        path = File.expand_path(@@config_file_path)
        FileUtils.mkdir_p path

        return path
      end

      def get_uplift_config_file 
        config_dir_path = get_uplift_config_folder
        file_name = ".vagrant-network.yaml"

        return  File.join(config_dir_path, file_name) 
      end

      # uplift_vbmanage_machinefolder helper
      def uplift_set_vbmanage_machinefolder(vm_name, vm_config, value = nil) 
        value = value || ENV['UPLF_VBMANAGE_MACHINEFOLDER'] 
        
        if !value.to_s.empty?
          log_info("#{vm_name}: vboxmanage machinefolder: #{value}")
          system("vboxmanage setproperty machinefolder #{value}")
        end
      end

      def uplift_set_default_vbmanage_machinefolder()
        system("vboxmanage setproperty machinefolder default")
      end

      # network helpers
      def get_network_range
        @@network_range
      end

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

      def get_env_variable(name, default_value) 
        var_name  = name.upcase
        var_value = ENV[var_name]

        if var_value.to_s.empty? 
          return default_value
        end

        return var_value
      end
      
      def get_vm_cpus(vm_name, default_value) 
        require_string(vm_name)
        require_integer(default_value)

        return get_env_variable("UPLF_#{vm_name}_CPUS", default_value)
      end

      def get_vm_memory(vm_name, default_value) 
        require_string(vm_name)
        require_integer(default_value)

        return get_env_variable("UPLF_#{vm_name}_MEMORY", default_value)
      end
      
      # checkpoint helper
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

      # RAM configs for VM
      def uplift_05Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        uplift_make_cpu_and_ram(vm_config,  2, 512)
      end

      def uplift_1Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)
        
        uplift_make_cpu_and_ram(vm_name, vm_config,  2, 1024)
      end

      def uplift_2Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)
        
        uplift_make_cpu_and_ram(vm_name, vm_config,  2, 1024 * 2)
      end

      def uplift_4Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        uplift_make_cpu_and_ram(vm_name, vm_config,  4, 1024 * 4)
      end

      def uplift_6Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        uplift_make_cpu_and_ram(vm_name, vm_config,  4, 1024 * 6)
      end

      def uplift_8Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        uplift_make_cpu_and_ram(vm_name, vm_config,  4, 1024 * 8)
      end

      def uplift_12Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        uplift_make_cpu_and_ram(vm_name, vm_config,  4, 1024 * 12)
      end

      def uplift_16Gb(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)
        
        uplift_make_cpu_and_ram(vm_name, vm_config,  4, 1024 * 16)
      end

      def uplift_make_cpu_and_ram(vm_name, vm_config,  cpu, ram) 

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
      end

      def require_integer(value)
        if value.is_a?(Integer) != true
          log_error_and_raise("expected integer value, got #{value.class}, #{value.inspect}")
        end
      end

      def require_string(value)
        if value.nil? == true || value.to_s.empty?
          log_error_and_raise("expected string value, got nil or empty string")
        end

        if value.is_a?(String) != true
          log_error_and_raise("expected string value, got #{value.class}, #{value.inspect}")
        end

      end

      def require_vagrant_config(value)
        if value.nil? == true 
          log_error_and_raise("expected string value, got nil or empty string")
        end

        if value.is_a?(Vagrant::Config::V2::Root) != true
          log_error_and_raise("expected Vagrant::Config::V2::Root value, got #{value.class}, #{value.inspect}")
        end

      end
 
      # winrm
      def uplift_winrm(vm_name, vm_config) 
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
      end

      # synch folders
      def uplift_synced_folder(vm_name, vm_config) 
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: synced folders config")
        
        vm_config.vm.synced_folder ".", "/vagrant", disabled: true
      end

      # test helpers
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

      # hostname and network
      def uplift_hostname(vm_name, vm_config, hostname)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        require_string(hostname)

        log_info_light("#{vm_name}: setitng hostname: #{hostname}")
        vm_config.vm.hostname = hostname
      end

      def uplift_private_network(vm_name, vm_config, ip: '', gateway: '') 
        
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info(" - ip: #{ip}, gateway: #{gateway}")

        vm_config.vm.network :private_network, ip: ip, gateway: gateway
      end

      def uplift_client_network(vm_name, vm_config, hostname) 

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

      def uplift_private_dc_network(vm_name, vm_config)
        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: private dc network")
        
        network_range = get_network_range

        uplift_private_network(
          vm_name,
          vm_config,
          :ip      => "#{network_range}.5",
          :gateway => "#{network_range}.1"
        )
      
      end

      # DSC - base configs
      def uplift_win16_dsc_base(vm_name, vm_config) 

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

      def uplift_win16_dsc_shortcuts(vm_name, vm_config) 

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

       # DSC - domain controller
      def uplift_win16_dsc_dc(vm_name, vm_config) 

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
      end

      def uplift_win16_dsc_dc_users(vm_name, vm_config) 

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

      end

      def uplift_dc16(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: domain controller setup")
       
        uplift_win16_dsc_dc(vm_name, vm_config)
        uplift_win16_dsc_dc_users(vm_name, vm_config)
      end

      def uplift_dc_join(vm_name, vm_config)
        
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
      end

      # DSC - SharePoint configs
      def uplift_sp16_pre_setup(vm_name, vm_config) 
      
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
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.pre_setup1.dsc.ps1"

        vm_config.vm.provision "reload"

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.pre_setup2.dsc.ps1"
      end

      def uplift_sp16_farm_post_setup(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: farm post-setup")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.post_setup.dsc.ps1"
      end

      def uplift_sp16_print_info(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SharePoint 2016: print info")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sharepoint/sp2016.info.ps1"
      end

      def uplift_sp16_farm_only(vm_name, vm_config, sql_server, farm_prefix = nil, dsc_verbose: '1') 

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
      end

      # DSC - sql configs
      def uplift_sql(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SQL 2016: image completion")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sql12/sql.complete.dsc.ps1"
               
        execute_tests(
          vm_config: vm_config, 
          paths: "#{vagrant_script_path}/vagrant/uplift.vagrant.sql12/tests/sql16.dsc.*"
        )

      end

      def uplift_sql_optimize(vm_name, vm_config) 

        require_string(vm_name)
        require_vagrant_config(vm_config)

        log_info_light("#{vm_name}: SQL 2016: optimization")

        vm_config.vm.provision "shell",
            path: "#{vagrant_script_path}/vagrant/uplift.vagrant.sql12/sql.optimize.dsc.ps1",
            env: {
              # UPLF_SQL_SERVER_NAME
              # UPLF_SQL_INSTNCE_NAME
              # UPLF_SQL_MIN_MEMORY
              # UPLF_SQL_MAX_MEMORY
            }
               
      end

      def uplift_sql_config(vm_name:, vm_config:, resource_name: 'sql2016_rtm') 
        log_info("SQL16")

        uplift_sql(
          vm_config, 
          resource_name: 'sql2016_rtm'
        )
        
        log_info("SQL16 completed!")
      end

      def uplift_sql16(vm_name:, vm_config:) 
        uplift_sql_config(
          vm_config,
          resource_name: 'sql2016_rtm'
        )
      end

      def uplift_sql14(vm_name:, vm_config:) 
        uplift_sql_config(
          vm_config,
          resource_name: 'sql2016_rtm'
        )
      end

      def uplift_sql12(vm_name:, vm_config:) 
        uplift_sql_config(
          vm_config,
          resource_name: 'sql2016_rtm'
        )
      end

      # DSC - Visual Studio 17 configs
      def uplift_visual_studio_17(vm_name:, vm_config:, 
        resource_name: 'ms-visualstudio-2017.ent-dist-office-dev', 
        bin: true, 
        install: true) 

        log_info("  - vs17 config for resource: #{resource_name}") 

        vm_config.vm.provision "shell",
          path: "#{vagrant_script_path}/vagrant/uplift.vagrant.visual_studio17/vs17.dsc.ps1",
          env: {
            "UPLF_VS_EXECUTABLE_PATH"   => "c:/_uplift_resources/ms-visualstudio-2017.ent-dist-office-dev/latest/vs_enterprise.exe",
            "UPLF_RESOURCE_NAME"          => [
              'Microsoft.VisualStudio.Workload.Office',
              'Microsoft.VisualStudio.Workload.ManagedDesktop',
              'Microsoft.VisualStudio.Workload.NetCoreTools',
              'Microsoft.VisualStudio.Workload.NetWeb',
              'Microsoft.VisualStudio.Workload.Node',
              'Microsoft.VisualStudio.Workload.VisualStudioExtension'
            ].join(";")
        }
       
      end

      private

      def _logger 
        @@logger = @@logger || VagrantPlugins::Uplift::Log.get_logger
        @@logger
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

    end

    def self.Config
      return UpliftConfigBuilder.new
    end

  end
  
end
