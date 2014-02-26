 
The <b> *dmApp* </b> application is segregated into two main files:
 
+ *dm.rb*: headless 'worker' class that encapsulates the downloading process. Knows nothing about how the UI is implemented.  
+ *dmApp.rb*: Tk code that provides a wrapper around the *dm* class. Loads a *dm.get_data* method as a thread, and manipulates *dm* state attributes @go and @exit. 

The code below distills how the these two files interact. *dmApp* creates an instance of the *dm* class.  The *dm* class has a *get_data* method which is added as a threaded process. A second thread hosts the Tk.mainloop (Tk's event thread). *dmApp* also uses a timer that queries the *dm* object about its download status for updaing the user-interface.

*dmApp* also manipulates two *dm* state attributes (@go and @exit). A "download data" button binds to the @go attribute, while an 'exit' button to the @exit attribute.  Note that a real-world application should have a mechanism to 'pause' a download cycle, but that is not implemented in this prototype.

```   
    oDM = Dm.new()

    timer_proc = proc{|o|
        begin #UI event loop.
               UI_progress_bar_download.value = (oDM.files_local.to_f/oDM.files_total.to_f) * 100
       end
    }

    timer = TkTimer.new(500, -1, timer_proc )
    timer.start(0)

    threads = []

    threads << Thread.new {oDM.get_data}

    t_ui = TkRoot.new.mainloop()

    threads << Thread.new {
       t_ui
    }

    threads.each {|thread| thread.join}
```
Note that an error is thrown if you attempt to thread the Tk mainloop in the following way:    
    
    threads << Thread.new {
        Tk.mainloop   #Error --> Tk.mainloop is allowed on the main thread only
    }



Successfully building an OCRA executable requires a clean and graceful exit of your application. While binding a *Kernel.exit* to your application UI's exit button may not cause any run-time headaches, it will take the OCRA build process down with it. Therefore you need to gracefully end the threaded processes that you've started. For the dmApp code this meant binding the following code to the exit button.

```
def exit_app(oDM, t_ui)
    oDM.exit = true
    t_ui.destroy
end
```

*dm* object has a get_data method that is loaded as a thread in the *dmApp* code.  

```
class Dm

    attr_accessor :http,  #Helper object that knows http.
                  :go,  #UI gatekeepers (booleans).
                  :exit,
                  :file_stats #simple hash of file stats.
                  
     def get_data

        while @exit == false
            if @go then
                get_filelist
                look_before_leap
                download
                @go = false
            else
                sleep 1 
            end
        end
    end
end
```

After developing the dmApp prototype, new classes were written to manage JSON-to-CSV data conversions and file consolidation (10-minutes files into hourly, daily or set-size files).  

It was decided to keep these as completely separate headless objects that could be marshalled by a common user-interface or instead used individually as simple scripts.  Or even launched as a Rake task from a Rails app.  

To implement this a headless *process* script was written that is driven by a configuration file.  This configuration file, along with a status file, provide a primative, cross-platform mechanism for managing background tasks from the user-interface.  

+ On Windows, we "shell" to the dm_process.exe, built from dm_process with OCRA gem.
+ On Linux/Mac OS, we call .\ruby dm_process.rb.


In the user-interface code, 'launch' buttons update a configuration file and then the *process* code is triggered.  The *process* code references the configuration file and know what to do there. As the long-duration tasks are running they check for pause/stop events from the UI, via the common file. 

```
def trigger_process
    if $os == :windows then #OS #Windows
        process_name = 'dm_process.exe' 
    else
        process_name = 'ruby ./dm_process.rb'
    end

    pid = spawn process_name #Launching an external process.
    Process.detach(pid) #tell the OS we're not interested in the exit status
end
```

