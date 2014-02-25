 threads << Thread.new {
        Tk.mainloop   #Error --> Tk.mainloop is allowed on the main thread only
    }





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

Successfully building a OCRA executable requires a clean and graceful exit of your application. While binding a *Kernal.exit* to your application UI's exit button may not cause any run-time headaches, it will take the OCRA build process down with it. Therefore you need to gracefully end the threaded processes that you've started. For the dmApp code this meant binding the following code to the exit button.

```
def exit_app(oDM, t_ui)
    oDM.exit = true
    t_ui.destroy
end
```


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
'''
