#  cocoasudo

This is a re-incarnation of [cocoasudo](http://www.performantdesign.com/2009/10/26/cocoasudo-a-graphical-cocoa-based-alternative-to-sudo/) based on this [fork](https://github.com/PowerOlive/cocoasudo) (which is slightly more up-to-date...)!

## How is this any different than the original?

This version uses [NSAuthenticatedTask](https://github.com/npyl/NSAuthenticatedTask) which is like Apple's NSTask but with the ability to launch a task as root and uses newest, and recommended way of doing this (using SMJobBlessHelper and XPC).

## Project State

Theoretically, this project is ready, though NSAuthenticatedTask is not...  This means that the project will wait until NSAuthenticatedTask is fully functional.  At the meantime though, you can actually run scripts/apps as root -but only that- :).

## LICENCE

See [license.txt](license.txt)
