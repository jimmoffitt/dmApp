#=======================================================================================================================
# A simple RESTful HTTP class.
# Knows a bunch about HTTP, and a little about the PowerTrack family of products.
#
#NOTES
#Based on Ruby 1.92. which has an issue with HTTPS commands on Windows.
#Accordingly, this class has methods that are used on the Windows Platform only.

class DmHttp

    require "net/https"     #HTTP gem.
    require "uri"
    require "base64" #Used for password encryption, may not be needed (?)

    #Object attributes.
    attr_accessor :product,
                  :url,
                  :account_name, :publisher,
                  :user_name, :password, :password_encoded,
                  #HTTP
                  :uri,
                  :base_url,
                  :headers, :data, :data_agent,
                  :job_uuid,

                  #HTTPS on Windows
                  :os,
                  :set_cert_file,  #Set SSL certificate file on Windows.
                  :app_path #Needed on Windows for finding SSL certificate file.
                  :cert_source_uri #Like http://curl.haxx.se/ca/cacert.pem

    def initialize(url=nil, user_name=nil, password=nil, headers=nil)

        @cert_source_uri = "http://curl.haxx.se/ca/cacert.pem"

        if not url.nil?
            @url = url
        end

        if not user_name.nil?
            @user_name = user_name
        end

        if not password.nil?
            @password = password
        end

        if not headers.nil?
            @headers = headers
        end
    end

    #Attributes.
    def url=(value)
        @url = value
        @uri = URI.parse(@url)
    end

    def password_encoded=(value)
        @password_encoded=value
        @password = Base64.decode64(@password_encoded) unless @password_encoded.nil?
    end

    def password=(value)
        @password = value
    end

    #Helper functions for building URLs
    def get_historical_url(account_name=nil)
        @url = "https://historical.gnip.com:443/accounts/" #Root url for Historical PowerTrack API.

        if account_name.nil? then #using object account_name attribute.
            if @account_name.nil?
                p "No account name set.  Can not set url."
            else
                @url = @url + @account_name + "/jobs.json"
            end
        else #account_name passed in, so use that...
            @url = @url + account_name + "/jobs.json"
        end
    end


    '''
    URL has this form:
       https://historical.gnip.com:443/accounts/<account>/publishers/twitter/historical/track/jobs/<job_uuid>/results.json
    '''
    def get_historical_data_url(account_name=nil, job_uuid=nil)

        @url = "https://historical.gnip.com:443/accounts/" #Root url for Historical PowerTrack API.

        if account_name.nil?
            if @account_name.nil?
                p "No account name set.  Can not set url."
                return
            else
                @url = @url + @account_name
            end
        else
            @url = @url + account_name
        end

        if job_uuid.nil? then
            if @job_uuid.nil?
                p "No job uuid set.  Can not set url."
                return

            else
                @url = @url + "/publishers/twitter/historical/track/jobs/#{@job_uuid}/results.json"
            end
        else
            @url = @url + "/publishers/twitter/historical/track/jobs/#{job_uuid}/results.json"
        end
    end

    #Ruby file HTTPS i/o on Windows.
    #
    #Ruby net/https on Windows needs some extra help to authenticate SSL certificates.
    #ssl_certifier gem claims to fix this issue, but could not get it to work.
    #For this to work, you need to have a cacert.pem file in the app root directory.
    #If that file is not found, one will be fetched from http://curl.haxx.se/ca/cacert.pem.

    def set_https_cert_file(app_path)
        # Fixes SSL Connection Error in Windows execution of Ruby
        # Based on fix described at: https://gist.github.com/fnichol/867550
        #Note: this has not been successfully tested, but left in for future reference.
        ENV['SSL_CERT_FILE'] = File.join(@app_path, "cacert.pem")
    end

    def set_cert_file_location(app_path)
        @set_cert_file = true
        @app_path = app_path
    end

    #On Windows, set these extra http attributes.
    def set_cert_file(http)
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        cert_file = File.join(@app_path, "cacert.pem")

        #If cert file is not found, create one.
        if not File.exist?(cert_file)
            make_ssl_cert_file(cert_file)
        end
        http.ca_file = cert_file
        http
    end

    #Retrieve http://curl.haxx.se/ca/cacert.pem and write as a file
    def make_ssl_cert_file(cert_file)

        uri = URI(@cert_source_uri)

        Net::HTTP.start(uri.host) { |http|
            resp = http.get(uri.path)
                open(cert_file, "w") { |file|
                    file.write(resp.body)
            }
        }
    end


    #Fundamental REST API methods:
    def POST(data=nil)

        if not data.nil? #if request data passed in, use it.
            @data = data
        end

        uri = URI(@url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        if @set_cert_file
            http = set_cert_file(http)
        end
        request = Net::HTTP::Post.new(uri.path)
        request.body = @data
        request.basic_auth(@user_name, @password)

        response = http.request(request)
        return response
    end

    def PUT(data=nil)

        if not data.nil? #if request data passed in, use it.
            @data = data
        end

        uri = URI(@url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        if @set_cert_file
            http = set_cert_file(http)
        end
        request = Net::HTTP::Put.new(uri.path)
        request.body = @data
        request.basic_auth(@user_name, @password)

        response = http.request(request)
        return response
    end

    def GET(url_self_auth=nil)  #Some urls will have authentication embedded in them.
        uri = URI(@url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        if @set_cert_file
            http = set_cert_file(http)
        end

        request = Net::HTTP::Get.new(uri.request_uri)

        if url_self_auth != true then
            request.basic_auth(@user_name, @password)
        end

        response = http.request(request)
        return response
    end

    def DELETE(data=nil)
        if not data.nil?
            @data = data
        end

        uri = URI(@url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        if @set_cert_file
            http = set_cert_file(http)
        end
        request = Net::HTTP::Delete.new(uri.path)
        request.body = @data
        request.basic_auth(@user_name, @password)

        response = http.request(request)
        return response
    end
end #DmHttp class.

