#dmApp (Download Manager app) 


+ A prototype for deploying Ruby/Tk Applications as Windows 7 Executables.
+ This Ruby/Tk code can be run from the terminal on Mac OS/Linux with the native Ruby interpreter.

To use:
* Fill in your credentials.
* Specify either a full HPT Data URL or a Job UUID.
* Select  folder to store the data.
* Specify whether you want the GZIPPED files uncompressed (can get big...).
* Hit the 'Download Data' button.

If you need to stop a download cycle, it will pick up where you left off if you leave the downloaded files in the data directory.

This Ruby app is deployed as a Windows executable using the OCRA gem:
+ http://ocra.rubyforge.org/
+ http://rubyonwindows.blogspot.com/2009/05/ocra-one-click-ruby-application-builder.html

If you want to make code changes, you can re-create the Windows executable with these commands:
Ruby\bin\ocra dmApp.rb --windows --no-autoload

Have found that to end up with a successful dmApp executable it is important to go through an actual download cycle. When I didn’t do this the executable would throw an error when downloading the file. 
Error: LoadError:cannot load such file -- tempfile

###Secure Socket Layer (SSL) Support
After initial prototyping of the download process on MacOS, I immediately hit a problem with https downloading on Windows. I quickly learned that there is a fundamental issue with the standard Ruby Windows install and it knowing where to look for SSL certificate files (here and here are some example discussions of the issue).

```
OpenSSL::SSL::SSLError: SSL_connect returned=1 errno=0 state=SSLv3 read server certificate B: certificate verify failed
```

Fortunately there are many discussion threads and workaround recipes around this issue, including gems (such as this one) dedicated to solving the problem. Since a general goal was to reduce the number of dependencies for this prototype, a decision was made to look in a local directory for a certificate file, and to pull one down from a trusted source and create the file if needed. See [HERE] (https://github.com/jimmoffitt/dmApp/blob/master/distilled_code/RubySSL_Win7.md) for a compilation of code written to implement this strategy. 

### Event Programming and Background Tasks  
A general proof-of-concept goal was to develop a standalone application with a simple user-interface to enable users to manage long-running data processes. The user-interface needed to interact with these background processes, raising events to start them and monitoring their progress. And since it needed to run on both Windows and Mac OS/Linux, I set off to make it as simple (primitive is an appropriate description) and ‘native’ as possible. By native I mean I wanted to rely on Ruby native threads and minimize the use of ‘third-party’ gems that potentially have Windows installation issues. (This goal was driven by having attended a Rails course and witnessing the Windows students struggle to get their environments set-up.) A review of the project’s Gemfile reveals that the required gems are pretty standard for an application based on HTTP, parses JSON, manages GZipped files, and provides a Tk user-interface.  Getting both the Mac OS and Windows environments built up was easy.

Development started with a simple design of building the Tk user-interface, binding widgets to the download ‘worker’ class, and invoking the Tk main event loop. That results in essentially a single-threaded application, complete with unwanted event blocking during the downloading process. Instead a responsive user-interface was implemented by hosting both the Tk mainloop and background process in separate threads. 

```
threads << Thread.new {oDM.get_data}
t_ui = TkRoot.new.mainloop()
threads << Thread.new { t_ui }
```

See [HERE] (https://github.com/jimmoffitt/dmApp/blob/master/distilled_code/ui_background_tasks.md) for more details on how this simple design was implemented.





