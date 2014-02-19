#Application gems.
require 'json' 
require 'zlib' 
require 'thread'

#Common Gnip classes.
require_relative './dm_http'
require_relative './dm_config'

class Dm
    require 'rbconfig'
    require 'open-uri'  

    #Helper objects: HTTP, Config
    attr_accessor :config, :http,
                  #Transient values managed during execution.
                  :link_list, :files_total, :files_to_get, :file_got, #@files_total = @files_to_get + @files_got
                  :os

    def initialize()
        @config = DMConfig.new    #Helper object to hold and manage app settings.
        @http = DmHttp.new     #Set up a HTTP object. Historical API is REST based (currently).
        os                        #Determine what OS we are on.
    end

    def get_config

        @config.get_config

        #After fetching the DMConfig details, we can now wrap-up the HTTP object settings.
        @http.publisher = @config.publisher
        @http.user_name = @config.user_name unless @config.user_name.nil? #Set the info needed for authentication.
        @http.password = @config.password unless @config.password.nil?  #HTTP class can decrypt password if you set password_encrypted.
        @http.url=@http.get_historical_data_url(@config.account_name, @config.job_uuid) unless @config.account_name.nil?  #Pass the URL to the HTTP object.

        #Check OS and if Windows, set the HTTPS certificate file (see method for the sad story).
        #This call also sets @http.set_cert_file = true
        if @os == :windows
            @http.set_cert_file_location( File.dirname(__FILE__) )
        end

    end

    def os
        @os ||= (
        host_os = RbConfig::CONFIG['host_os']
        case host_os
            when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
                :windows
            when /darwin|mac os/
                :macosx
            when /linux/
                :linux
            when /solaris|bsd/
                :unix
            else
                raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
        end
        )
    end

    '''
    A simple wrapper to the gunzip command.  Provides a simplistic mechanism for uncompressing gz files on Linux or
    Mac OS.  For Windows developers, this should be replaced with more appropriate code.
    '''
    def uncompress_data

        begin
            Dir.glob(@config.data_dir + "/*.gz") do |file_name|
                Zlib::GzipReader.open(file_name) { |gz|
                    new_name = File.dirname(file_name) + "/" + File.basename(file_name, ".*")
                    g = File.new(new_name, "w")
                    g.write(gz.read)
                    g.close
                }

                File.delete(file_name)
            end
        rescue => e
            p "Error msg: #{e.message} || Backtrace: #{e.backtrace}"
        end
    end

    #-------------------------------------------------------------------------------------------------------------------
    #Downloading based on dm_http.

    def download

        begin_time = Time.now

        @url_list.each do |item|

            p "Downloading #{item[0]}..."

            File.open(@config.data_dir + "/" + item[0], "wb") do |new_file|
                @http.url = item[1]
                response = @http.GET(true)  #These HPT urls are elf-authenticating...
                new_file.write(response.body)
            end
        end

        p "Took #{Time.now - begin_time} seconds to download files.  "

        if @config.uncompress_data == true or @config.uncompress_data == "1" then
            uncompress_data
        end
    end


    #-------------------------------------------------------------------------------------------------------------------
    #Downloading based on open-uri
    def download_openuri()
        #Since there could be thousands of files to fetch, let's throttle the downloading.
        #Let's process a slice at a time, then multiple-thread the downloading of that slice.

        begin_time = Time.now

        @url_list.each do |item|

            p "Downloading #{item[0]}..."

            File.open(@config.data_dir + "/" + item[0], "wb") do |new_file|
                # the following "open" is provided by open-uri

                #if Windows, switch to HTTP from HTTPS
                url = item[1]

                #if @os == :windows then
                #    url.gsub!("https", "http")
                #end

                open(url, 'rb') do |read_file|
                    new_file.write(read_file.read)
                end
            end

        end

        if @config.uncompress_data == true or @config.uncompress_data == "1" then
            uncompress_data
        end

        p "Took #{Time.now - begin_time} seconds to download files.  "
    end

    def download_multithread_openuri()
        #Since there could be thousands of files to fetch, let's throttle the downloading.
        #Let's process a slice at a time, then multiple-thread the downloading of that slice.
        slice_size = 10
        thread_limit = 10
        sleep_seconds = 1

        threads = []

        begin_time = Time.now

        @url_list.each_slice(slice_size) do |these_items|
            for item in these_items

                threads << Thread.new(item[1]) do |url|

                    until threads.map { |t| t.status }.count("run") < thread_limit do
                        print "."
                        sleep sleep_seconds
                    end

                    File.open(@config.data_dir + "/" + item[0], "wb") do |new_file|
                        # the following "open" is provided by open-uri
                        open(url, 'rb') do |read_file|
                            new_file.write(read_file.read)
                        end
                    end

                    #$p.value = 25

                end
                threads.each { |thr| thr.join}
            end
        end

        if @config.uncompress_data == true or @config.uncompress_data == "1" then
            uncompress_data
        end

        p "Took #{Time.now - begin_time} seconds to download files.  "
    end


    '''
    The *.json payload has this form:
    {"urlCount":24,
    "urlList":["https://s3-us-west-1.amazonaws.com/archive.replay.snapshots/snapshots/twitter/track/activity_streams/jim/2013/07/24/20130722-20130722_tf4kfhrtb8/2013/07/22/15/00_activities.json.gz?AWSAccessKeyId=AKIAIWTH5AP7S5RCSOBQ&Expires=1377296627&Signature=zs6%2B1dk%2FaL1lM9Slq2yilBnmmCY%3D"],
    "expiresAt":"2013-08-08T22:10:22Z",
    "totalFileSizeBytes":63969459}

    Take that and load up a hash of [file_name][link] key-value pairs.
    20130722-20130722_tf4kfhrtb8_2013_07_22_15_00_activities.json.gz
    https://s3-us-west-1.amazonaws.com/archive.replay.snapshots/snapshots/twitter/track/activity_streams/jim/2013/07/24/20130722-20130722_tf4kfhrtb8/2013/07/22/15/00_activities.json.gz?AWSAccessKeyId=AKIAIWTH5AP7S5RCSOBQ&Expires=1377296627&Signature=zs6%2B1dk%2FaL1lM9Slq2yilBnmmCY%3D

    '''
    def parse_url_list(data_url_json)

        data_files = Hash.new

        data = JSON.parse(data_url_json)

        if data["status"] != "error" then

            urlList = data["urlList"]

            urlList.each { |item|

                #Parse the file name from the link.
                begin
                    file_name = ((item.split(@config.account_name)[1]).split("/")[4..-1].join).split("?")[0]
                rescue #in case the link format changes, try this...
                    file_name = item[item.index(@config.job_uuid)..(item.index(".gz?")+2)].gsub!("/","_")
                end

                data_files[file_name] = item
            }

            data_files
        end
    end


    def get_filelist
        p "Getting data file list for job #{@config.job_uuid}..."

        response = @http.GET()
        data_url_json = response.body
        @url_list = parse_url_list(data_url_json)
        @files_total = @url_list.length

        p "Got data file list for job #{@config.job_uuid}..."
        p "This Historical PowerTrack job has #{@files_total} data files "
    end

    '''
    Look in the output folder, and make sure not to download any files already there.
    '''
    def look_before_leap

        files_downloaded = 0

        Dir.foreach(@config.data_dir) do |f|
            if @url_list.has_key?(f)
                @url_list.delete(f)
                files_downloaded = files_downloaded + 1
            end
        end

        @files_got = files_downloaded

    end

    def get_data

        #go get the file list from Gnip server.
        get_filelist

        #Filter out any files that have already been downloaded!
        look_before_leap

        p "Starting downloads..."

        if not @url_list.nil? then
            download
        else
            p "All file already downloaded!"
        end
    end
end

