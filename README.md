# IRSSI Script to show the title in a web page

This is an *old* script I wrote for us in the [irssi] IRC client. It
has a lot of controls and administrative functions to make it as good
a bot citizen on an IRC channel as possible, from completely ignoring
the channel it's in (supposing you're running it in your own instance)
to filtering in only certian URLs.

[irssi]: https://irssi.org/ "IRSSI IRC client"

Documentation for the script is kept as perldoc in the script.

## Contributing

I haven't touched this really much in several years, but if you wish,
I'll accept PRs with bug-fixes and enhancements.

The code is still licensed GPLv2.

## Live testing

To live test the script, start up `irssi` as follows:

    irssi --home=. --config=irssi-config

Load the script: `/script load showtitle.pl`.

Connect to Freenode: `/connect freenode`.

Turn on script debugging: `/stdebug on`.

Join the testing channel `/join ##showtitle-test`.

From another user in the channel, enter a test url.

Watch the debug output in the status window.
