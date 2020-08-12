module VagrantPlugins::Uplift
    module AppInsights

        extend self

        class AppInsightsHelper

            require 'date'
            require 'uri'
            require 'net/http'
            require 'openssl'
            require 'json'            

            @key = nil
            
            @endpoint = nil
            @endpoint_api = nil

            @client_id = nil

            def initialize(key) 
                @key = key

                @endpoint     = 'https://dc.services.visualstudio.com'
                @endpoint_api = '/v2/track'

                @client_id = 'uplift-vagrant:ruby:1.0.0'
            end

            def track_event(event_name, event_properties) 

                _log_debug("tracking event: #{event_name}")

                result = {
                    :success => false
                }
            
                begin
                    time = DateTime.now.to_time.utc.strftime('%Y-%m-%dT%H:%M:%S.%7N%z')
            
                    data = {
                        "name" =>  "Microsoft.ApplicationInsights.Event",
                        
                        "time" =>  time,
                        "iKey" =>  @key,
                
                        "tags" =>  {
                            "ai.internal.sdkVersion":  @client_id
                        },
                    
                        "data" =>  {
                            "baseType" =>  "EventData",
                            "baseData" =>  {
                                "ver":  2,
                                "name":  event_name ,
                                "properties":  event_properties 
                            }
                        }
                    }
            
                    _log_debug("sending data: #{data}")
                    _send_data_async(data)
                rescue => e 
                    result[:exception] = e;
                    result[:success] = false
                ensure 
            
                end
            
                return result
            end

            private 

            def _log_debug(message) 
                if ENV['UPLF_LOG_LEVEL'] == 'DEBUG' 
                    puts "  AppInsights DEBUG: #{message}"
                end
            end

            def _send_data(data_hash) 
                thread = _send_data_async
                thread.join
            end

            def _write_appinsight_usage_warning(message = nil, error = nil) 
                _log_debug "[!] Cannot use AppInsight, please report this error or use UPLF_NO_APPINSIGHT env variable to disable it."
                
                if !message.to_s.empty?
                    _log_debug message
                end

                if !error.nil? 
                    _log_debug e
                end
            end

            def _send_data_async(data_hash) 
                
                thr = Thread.new {

                    begin

                        _log_debug(" - creating http client")
                        http = _get_http_client
                
                        _log_debug(" - crafting request")
                        request = Net::HTTP::Post.new(@endpoint_api)
                        request.body = data_hash.to_json

                        _log_debug(" - http.request(request)")
                        response = http.request(request)
                
                        result = {}

                        _log_debug(" - response: #{response.inspect}")

                        result[:success]  = response != nil && response.code.to_s == '200'
                        result[:response] = response
                
                        result[:response_code]    = response.code
                        result[:response_message] = response.message
                        result[:response_body]    = response.body()

                        if  response != nil && response.code.to_s != '200'
                            _log_debug(" [!] FAIL!")
                            _write_appinsight_usage_warning("response code: #{response.code}", nil)
                        else 
                            _log_debug(" [+] OK!")
                        end

                    rescue => e
                        _log_debug(" [!] FAIL!")
                        _write_appinsight_usage_warning(nil, e)
                    end

                    return result
                }

                return thr
            end

            def _get_http_client() 
                
                uri = URI.parse(@endpoint)
                http = Net::HTTP.new(uri.host, uri.port)
        
                http.use_ssl = true
                http.verify_mode = OpenSSL::SSL::VERIFY_NONE

                return http
            end

        end

        def get_client(key)

            client = AppInsightsHelper.new(key)

            _configure_client(client)                

            return client
        end

        private

        def _configure_client(client)                

        end

    end

end
