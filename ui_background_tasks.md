 threads << Thread.new {
        Tk.mainloop   #Error --> Tk.mainloop is allowed on the main thread only
    }



```    
    tick = proc{|o|
        begin #UI event loop.
               UI_progress_bar_download.value = (oDM.files_local.to_f/oDM.files_total.to_f) * 100
       end
    }

    timer = TkTimer.new(500, -1, tick )
    timer.start(0)

    threads = []

    threads << Thread.new {oDM.get_data}

    t_ui = TkRoot.new.mainloop()

    threads << Thread.new {
       t_ui
    }

    threads.each {|thr| thr.join}
```
