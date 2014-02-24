#Application gems.
require 'json' #Needed at a higher level, for any data transferring/storing.
require 'zlib' #Needs to live in File Manager class.

#App UI code.  Based on Tk.  Requires a download manager object (oDM)

#Common classes.
require_relative "./dm"  #Manages the downloading, knows nothing about the dmApp UI and Tk.


#=======================================================================================================================

#User Interface gems
#module TkCore
#    RUN_EVENTLOOP_ON_MAIN_THREAD = true
#end
require 'tk'
require 'tkextlib/tile'

#UI actions that update app settings.
def select_data_dir(oDM)
    #try to get rid of these globals, tweak call-backs on 'other' side
    oDM.config.data_dir.value = Tk::chooseDirectory
    p "Data folder set to #{oDM.config.data_dir.value}"
    oDM.config.data_dir.value
end

def exit_app
    Kernel.exit
end

#-------------------------------------------------
# Application UI code:
if __FILE__ == $0  #This script code is executed when running this file.
    p "Creating Application object..."

    oDM = Dm.new()

    #Create Tk variables.
    # These are encapsulated in the DMConfig object.
    oDM.config.user_name = TkVariable.new
    oDM.config.password = TkVariable.new
    oDM.config.account_name = TkVariable.new
    oDM.config.job_info = TkVariable.new
    oDM.config.job_uuid = TkVariable.new
    oDM.config.data_dir = TkVariable.new
    oDM.config.uncompress_data = TkVariable.new
    UI_progress_bar_download = TkVariable.new
    oDM.get_config #Load settings.

    #Start building user interface.
    root = TkRoot.new {title "Gnip Historical PowerTrack Download Manager"}
    content = Tk::Tile::Frame.new(root) {padding "3 3 12 12"}
    #------------------------------------------------------------

    current_row = -1
    current_row = current_row + 1
    #Account
    Tk::Tile::Label.new(content) {text 'Account'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(content) {width 20; textvariable oDM.config.account_name}.grid( :column => 1, :columnspan => 1, :row => current_row, :sticky => 'w' )
    #Username
    Tk::Tile::Label.new(content) {text 'Username'}.grid( :column => 2, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(content) {width 30; textvariable oDM.config.user_name}.grid( :column => 3,  :columnspan => 3, :row => current_row )
    #Password
    Tk::Tile::Label.new(content) {text 'Password'}.grid( :column => 6, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(content) {width 20; textvariable oDM.config.password; show "*"}.grid( :column => 7,  :columnspan => 1, :row => current_row, :sticky => 'e' )

    #---------------------------------------------
    current_row = current_row + 1
    lbl_space_1 = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    sep_1 = Tk::Tile::Separator.new(content) { orient 'horizontal'}.grid( :row => current_row, :columnspan => 8, :sticky => 'we')

    current_row = current_row + 1
    #Long textbox for Data URL.  Also supports entry of job UUID.
    Tk::Tile::Label.new(content) {text 'Job UUID or Data URL'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(content) {width 70; textvariable oDM.config.job_info}.grid( :column => 1, :columnspan => 7, :row => current_row, :sticky => 'we' )

    current_row = current_row + 1
    #Data folder widgets. Label, TextBox, and Button that activates the ChooseDir standard dialog.
    Tk::Tile::Label.new(content) {text 'Data Directory'}.grid( :column => 0, :row => current_row, :sticky => 'e')
    Tk::Tile::Entry.new(content) {textvariable oDM.config.data_dir}.grid( :column => 1, :columnspan => 7, :row => current_row, :sticky => 'we' )
    Tk::Tile::Button.new(content) {text 'Select Dir'; width 10; command {oDM.config.data_dir.value=select_data_dir(oDM)}}.grid( :column => 7, :row => current_row, :sticky => 'e')

    current_row = current_row + 1
    #Uncompress data?
    Tk::Tile::CheckButton.new(content) {text 'Uncompress data files'; variable oDM.config.uncompress_data; set_value oDM.config.uncompress_data.to_s}.grid( :column => 1, :row => current_row, :sticky => 'w')

    #Download Progress Bar details.
    progress_bar_download = Tk::Tile::Progressbar.new(content) {orient 'horizontal'; }
    progress_bar_download.maximum = 100
    progress_bar_download.variable = UI_progress_bar_download
    progress_bar_download.grid :row => current_row, :column => 3, :columnspan => 6,:sticky => 'we'


    #---------------------------------------------
    current_row = current_row + 1
    lbl_space_2 = Tk::Tile::Label.new(content) {text ' '}.grid( :row => current_row, :column => 0)
    current_row = current_row + 1
    sep_2 = Tk::Tile::Separator.new(content) { orient 'horizontal'}.grid( :row => current_row, :columnspan => 8, :sticky => 'we')

    #-----------------------------------------
    #app_buttons = Tk::Tile::Frame.new(content) {padding "3 3 12 12"; borderwidth 4; relief 'sunken'}.grid( :sticky => 'nsew')
    #app_buttons.grid :column=>0, :row=>4, :columnspan => 6, :rowspan => 1
    current_row = current_row + 1
    Tk::Tile::Button.new(content) {text 'Save Settings'; width 12; command {oDM.config.save_config}}.grid( :column => 0, :columnspan => 1, :row => current_row, :sticky => 'w')
    Tk::Tile::Button.new(content) {text 'Exit'; width 12; command {exit_app}}.grid( :column => 1, :columnspan => 1, :row => current_row)
    Tk::Tile::Button.new(content) {text 'Download Data'; width 12; command {oDM.go = true }}.grid( :column => 7, :columnspan => 1, :row => current_row, :sticky => 'e')

    #-----------------------------------------
    content.grid :column => 0, :row => 0, :sticky => 'nsew'

    TkGrid.columnconfigure root, 0, :weight => 1
    TkGrid.rowconfigure root, 0, :weight => 1


    tick = proc{|o|
        begin #UI event loop.
              #p "oDM.files_local = #{oDM.files_local}"
              UI_progress_bar_download.value = (oDM.files_local.to_f/oDM.files_total.to_f) * 100

        end
    }

    #-------------------------------------------------------------------------------------------------------------------
    #Timer hits tick loop every interval--------------------------------------------------------------------------------
    timer = TkTimer.new(500, -1, tick )
    timer.start(0)

    #This script code is executed when running this file.
    p "Starting Download Manager application..."

    #--------------------------------
    #Attempting some simple threading for running download
    #while having UI update file status.

    threads = []

    threads << Thread.new {oDM.get_data}

    t_ui = TkRoot.new.mainloop()

    threads << Thread.new {
       t_ui
        #Tk.mainloop   #Error --> Tk.mainloop is allowed on the main thread only
    }

    threads.each {|thr| thr.join}

end