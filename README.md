dmApp
=====

A prototype for deploying Ruby/Tk Applications as Windows 7 Executables.




This Ruby app is deployed on Windows using the Ocra gem:
+ http://ocra.rubyforge.org/
+ http://rubyonwindows.blogspot.com/2009/05/ocra-one-click-ruby-application-builder.html


If you want to make code changes, you can re-create the Windows executable with these commands:
Ruby\bin\ocra dmApp.rb --windows --no-autoload

Have found that to end up with a successful dmApp executable it is important to go through an actual download cycle. When I didn’t do this the executable would throw an error when downloading the file. 
Error: LoadError:cannot load such file -- tempfile



