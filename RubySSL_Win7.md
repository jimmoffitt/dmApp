###Secure Socket Layer (SSL) Support

After initial prototyping of the download process on MacOS, a problem was immediately hit with https downloading on Windows. It was quickly learned that there is a fundamental issue with the standard Ruby Windows install and it knowing where to look for SSL certificate files.
[Show native error that is thrown]

Luckily there are many discussion threads and workaround recipes around this issue, including gems (such as this one) dedicated to solving the problem.   

Since a general goal was to reduce the number of dependencies for this prototype, a decision was made to look in the local directory for a certificate file, and to pull one down from a trusted source and create the file if needed.  

The following code illustrates the methods for doing that:

```
#Check OS and if Windows, set the HTTPS certificate file (see method for the sad story).
#This call also sets @http.set_cert_file = true
if @os == :windows
      @http.set_cert_file_location( File.dirname(__FILE__) )
end
```

Windows 7 code from the HTTP pt_restful class:

```
    @cert_source_uri = "http://curl.haxx.se/ca/cacert.pem"
```

```
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
```
