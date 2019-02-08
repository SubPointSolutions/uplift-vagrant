require 'logger'

module VagrantPlugins::Uplift
    module Log

        extend self

        # adding custom log levels
        # https://stackoverflow.com/questions/2281490/how-to-add-a-custom-log-level-to-logger-in-ruby
        class UpliftLogger < Logger

            SEVS = %w(DEBUG INFO WARN ERROR FATAL VERBOSE INFO_LIGHT)
            def format_severity(severity)
                SEVS[severity] || 'ANY'
            end
            
            def verbose(progname = nil, &block)
                add(5, nil, progname, &block)
            end

            def info_light(progname = nil, &block)
                add(6, nil, progname, &block)
            end
        end

        def get_logger

            $stdout.sync = true
            logger = UpliftLogger.new($stdout)

            _configure_logging(logger)                

            return logger
        end

        private

        def _configure_logging(logger)
            _set_formatting(logger)
            _set_log_level(logger)
        end

        def _set_log_level(logger) 
            logger.level = Logger::INFO
          
            case ENV['UPLF_LOG_LEVEL']
            when 'DEBUG'
                logger.level = Logger::DEBUG
            when 'INFO'
                logger.level = Logger::INFO
            end
        end

        def _set_formatting(logger) 
            logger.formatter= proc do |severity, datetime, progname, message|
                _format_message(severity, datetime, progname, message)
            end
        end

        def _logger_name 
            'vagrant-uplift'
        end

        def _format_message(severity, datetime, progname, message)
            
            result = ''
            color_code = _get_message_color_code(severity: severity, message: message)
            
            if severity == "DEBUG"
                message = "   #{message}"
            end
            
            case ENV['UPLF_LOG_FORMAT'].to_s.upcase
            when 'SHORT'
                result = "#{_logger_name}: #{message}"
            when 'TIME'
                result = "#{_logger_name}: #{datetime} #{message}"
            when 'FULL'
                result = "#{_logger_name}: #{datetime} #{severity} #{message}"
            else 
                result = "#{_logger_name}: #{message}"
            end

            # add/remove colors, useful for CI based output
            if ENV['UPLF_LOG_NO_COLOR'].to_s.empty? 
                result = "\e[#{color_code}m#{result}\e[0m\n"
            else 
                result = "#{result}\n"
            end

            return result
        end

        def _get_message_color_code(severity:, message:)
            color = _white
            
            case severity
            when "INFO"
                color =  _light_blue
            when "INFO_LIGHT"
                color =  _light_light_blue
            when "WARNING"
                color =  _yellow
            when "WARN"
                color =  _yellow
            when "DEBUG"
                color =  _light_blue
            when "ERROR"
                color =  _red
            when "FATAL"
                color =  _red
            when "VERBOSE"
                color = _gray
            end
        end

        def _white 
            37
        end
    
        def _red
            31
        end
    
        def _green
            "2;32"
        end

        def _green_light
            "1;32"
        end
    
        def _yellow
            33
        end
    
        def _blue
            34
        end

        def _pink
            35
        end
    
        def _light_blue
            "2;36"
        end

        def _light_light_blue
            "1;36"
        end
    
        def _gray
            37
        end
    end
end