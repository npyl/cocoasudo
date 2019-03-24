#  cocoasudo

This is a re-incarnation of [cocoasudo](http://www.performantdesign.com/2009/10/26/cocoasudo-a-graphical-cocoa-based-alternative-to-sudo/) based on this [fork](https://github.com/PowerOlive/cocoasudo) (which is slightly more up-to-date...)!

## How is this any different than the original?

This version uses [NSAuthenticatedTask](https://github.com/npyl/NSAuthenticatedTask) which is like Apple's NSTask but with the ability to launch a task as root and uses newest, and recommended way of doing this (using SMJobBlessHelper and XPC).

## Project State

Theoretically, this project is ready, though NSAuthenticatedTask is not...  This means that the project will wait until NSAuthenticatedTask is fully functional.  At the meantime though, you can actually run scripts/apps as root -but only that- :).

## LICENCE

See [license.txt](license.txt)

## SUPPORTING 💰

[![paypal](https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=NSV636CUWX754)

[![Become a Patron!](http://npyl.github.io/img/become_a_patron_button.png)](https://www.patreon.com/bePatron?u=11783784)
