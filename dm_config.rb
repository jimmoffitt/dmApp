
#OK, the crazy thing here is that these Application attributes are TkVariables.
#This class is tied to the Download Manager Application UI...

class DMConfig

    require 'base64'

    CONFIG_FILE = "dm_config"  #App-specific.  A config file we create and manage, stores our UI configuration...

    #These are TkVariables... Code typically references the .value attribute, as in account_name.value.
    attr_accessor :account_name, :user_name, :password,
                  :publisher, :product, :stream_type,
                  :job_info, :job_uuid,  #User can enter Data URL or UUID as job_info.  We use either to set job_uuid.
                  :data_dir, :consolidate_dir, :uncompress_data, :convert_csv, :data_span

    def initialize
        #Defaults.
        @publisher = "twitter"
        @product = "historical"
        @stream_type = "track"
    end

    def set_uuid
        #Determine @job_uuid from @job_info
        if @job_info.value.include?("historical.gnip.com") #then Data URL was entered
            @job_uuid.value = @job_info.value.split("/")[-2]
        else
            @job_uuid.value = @job_info.value
        end
    end

    def save_config

        config = DMConfig.new

        config.account_name=@account_name.value
        config.user_name=@user_name.value
        config.password=Base64.encode64(@password.value)
        config.data_dir=@data_dir.value
        config.job_info=@job_info.value
        set_uuid

        config.uncompress_data=1

        #write to file
        File.open("dm_config", "wb") do |f|
            Marshal.dump(config,f)
        end
    end

    def get_config
        config = DMConfig.new

        if File.exist?(CONFIG_FILE) then

            begin
                #Load from Config file.
                File.open(CONFIG_FILE, "rb") do |f|
                    config = Marshal.load(f)
                end

                #p config
                @account_name.value = config.account_name
                @user_name.value = config.user_name
                @password.value = Base64.decode64(config.password) unless config.password.nil?
                @data_dir.value = config.data_dir
                @job_info.value  = config.job_info
                set_uuid

            rescue
                p "Failed to load configuration."
            end
        else
            p "No configuration file to load..."
        end
    end
end