# showtitle3.pl -- Irssi script to show <title> of URLs
## Copyright (c) 2010 Tamara Temple <tamouse@gmail.com>
## Time-stamp: <2011-12-30 14:59:54 jessica>
## VERSION: 3.0.4-r1
#   - Copyright (C) 2012 Tamara Temple Web Development
#   - 
#   - This program is free software; you can redistribute it and/or
#   - modify it under the terms of the GNU General Public License
#   - as published by the Free Software Foundation; either version 2
#   - of the License, or (at your option) any later version.
#   - 
#   - This program is distributed in the hope that it will be useful,
#   - but WITHOUT ANY WARRANTY; without even the implied warranty of
#   - MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   - GNU General Public License for more details.
#   - 
#   - You should have received a copy of the GNU General Public License
#   - along with this program; if not, write to the Free Software
#   - Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# CHANGED using external curl program instead of LWP
# CHANGED added ignore feature (affects many places)
# TODO do version checking on the database
# TODO (maybe) SQLite database?
# CHANGED 2011-06-18 added two new function: shownotice and showerror. Added level tags to various printing options. Now all printing done from these three functions: DebugPring, shownotice and showerror.
# CHANGED 2011-10-19 - added all the perldoc you could want.
# CHANGED 2011-10-20 tamara - made curl timeout values and line prefix configurable.
# CHANGED 2011-10-20 jessica - reasonable defaults deermined for curl, no certificate check enabled
# CHANGED 2011-12-30 jessica - updated url filter code to remove whitespace at beginning and end of urls (as part of 
# the double space removal section).

=pod

=head1 Showtitle Irssi Bot Script

Showtitle is an Irssi script that scans the current private, public or
action message for a string matching a URL specification. If it
finds one, it then tries to get the beginning of the URL contents
in order to parse out the <title></title> tag, and then attempts
to show it either to the channel, or to the script user.

Showtitle is an active bot script, i.e, it responds to certain types
of text on channels it is listening on.

The channel text to invoke showtitle commands is "!st" at the
beginning of the line.

=head2 !st subcommands:

=head3 B<listen> I<(on|off|list)>

Determines whether showtitle will be listening to a particular channel.

=over

=item *
    C<on> - turn listening on for this chatnet/channel

=item *
    C<off> - turn listening off for this chatnet/channel

=item *
    C<list> - show current channels listened to on this chatnet

=item *
    C<help> - send help info about listen command to nick that entered
    the !st command

=back

=head3 B<filter> I<(add|delete|list|help)>

Modifies the filters for the current chatnet/channel.  If no filters
are specified, and listening is on for this chatnet/channel, then all
URL title are sent to the channel.  Filters are pass filters, rather
than no-pass filters, i.e. they determine what is allowed to send to
the channel.

=over

=item *
    C<add> C<< <regex> >> -- add the regex to the filter list

=item *
    C<delete> C<< <regex> >> -- remove the regex from the filter list

=item *
    C<list> -- show current set of filters on this chatnet/channel

=item *
    C<help> -- display help info to the calling nick

=back

=head3 B<user> I<(add|delete|request [address]|list|help)>

Deal with eligible users for managing the showtitle bot. Eligible
users are determined by the address part of their hostmask.

=over

=item *
    C<add> -- add a user to the showtitle bot's user list

=item *
    C<delete> -- delete a user from showtitle bot's user list

=item *
    C<request> I<[address]> -- make a request to the bot owner to add
    someone to the list. If address is not specified, then the calling
    user's address is used.

=item *
    C<list> -- list the current users

=item *
    C<help> -- send a help message to calling nick

=back

=head3 B<help>

send general help to calling user.


=head2 UI Commands

These commands are available to the user running the showtitle script.

=head3 B</stuser> I<(add|delete|list)>

modify user list

=head3 B</stfilter> I<(add|delete|list)>

modify filter list

=head3 B</stlisten> I<(on|off|list)>

modify listening list

=head3 B</stignore> I<(on|off|list)>

Completely ignore any C<^!> input from the channel. This has the effect of essentially hiding showtitle from anyone attempting to determine if there are any bots listening

=over

=item *
    C<on> - turn on ignore on this chatnet/channel

=item *
    C<off> - turn off ignore on this chatnet/channel

=item *
    C<list> - show ignored channels on this chatnet

=back

=head3 B</stsave>

save current configuration

=head3 B</ststatus>

show current status across all chatnets/channels

=head3 B</stdebug> I<[on|off]>

turns debugging for showtitle script on or off, or reports status

=cut




# ############################### #
# ------------- Code ------------ #
# ############################### #

=head1 Internal Documentation

=cut

use Irssi qw();
use Data::Dumper::Names;
use strict;
use vars qw($VERSION %IRSSI);

$VERSION = "3.0.4";

%IRSSI = (
	  'authors'	=> 'Tamara Temple, Jess',
	  'contact'	=> 'tamouse\@gmail.com',
	  'name'	=> 'showtitle',
	  'description'	=> 'Show the <title> from a URL in the given window. this version has channel specificity and filters, adds in-channel !commands, user management',
	  'license'	=> 'GPLv2',
	  'url'		=> 'http://public.tamaratemple.com/irssi/showtitle-'.$VERSION.'.pl.txt'
	 );

=head2 Irssi Configurable Settings

=over

=item *
C<$st_line_prefix> - the text shown by showtitle when it writes to the channel before the title is given

=cut

Irssi::settings_add_str('misc','st_line_prefix','<URL> ');

=item *
C<$st_connect_timeout> - time in seconds before curl connection attempt times out

=cut

Irssi::settings_add_int('misc','st_connect_timeout',15);

=item *
C<$st_max_timeout> - time in seconds before curl operation times out

=cut

Irssi::settings_add_int('misc','st_max_timeout',30);

=back


=head2 Global Declarations

The following globals are used to enable useful error messages from deep inside some of the functions.

=over

=item *
C<$current_chatnet> - stores the name of the current chatnet that the signal was triggered from..

=item *
C<$current_channel> - stores the name of the current channel that the signal was triggered from.

=item *
C<$current_url> - the matching URL in the signal's data, if any

=cut

use vars qw{$current_chatnet $current_channel $current_uri}; # define some globals that can be used for such things as printing error messages

=pod

=item *
C<$empty_re> - a regular expression that matches an empty line

=cut

my $empty_re = qr/^\s*$/; # CHANGED create compiled regex for checking empty strings

=pod

=item *
C<$debug> - flag used to check if debugging output should be sent or not

=cut

my $debug = 0;


=pod


=item *
C<%listen_on> - determines where we are listening = (chatnet => {channel => listening,})

=cut

my %listen_on = ();

=pod

=item *
C<%filters> - filters to apply on a per-channel basis = (chatnet => {channel => (filter_regexp)})

=cut

my %filters = ();

=pod

=item *
C<%validusers> - which users are allowed to do certain commands = (chatnet => {channel => (address)})

=cut

my %validusers = ();

=pod

=item *
C<%ignores> - enforces ignore on specific chatnet channels = (chatnet  => {channel => ignoring (on/off)})

=cut

my %ignores = (); 


=pod

=item *
C<$major>, C<$minor>, and C<$subminor>

=cut

# CHANGED made the database name reflect the version major number, and use package name
my ($major, $minor, $subminor) = split(/\./,$VERSION);


=pod

=item *
C<$database_basename> - the name of the data base used to store information, suffixed by major version number

=cut

my $database_basename = $IRSSI{'name'}.'-'.$major;

=pod

=item *
C<$irssi_dir> - the directory containing current irssi session's parameters, set by --home command line paramter

=cut

my $irssi_dir = Irssi::get_irssi_dir();

=pod

=item *
C<$database> - full database path name

=item *
C<$database_tmp> - full temporary database path name

=item *
C<$database_old> - full backup database path name

=cut

my $database     = $irssi_dir . "/".$database_basename.".dat";
my $database_tmp = $irssi_dir . "/".$database_basename.".tmp";
my $database_old = $irssi_dir . "/".$database_basename.".dat~";



=back

=cut

# ====================
# = UTILITY ROUTINES =
# ====================

=head2 Utility Routines

=head3 DebugPrint

Print a message to the current window with some debugging information
    if $debug is true.

=over

=item *
param string $debugmsg - message to print

=item *
global boolean $debug - test whether debug is on or off

=item *
returns void

=back

=cut

sub DebugPrint { 
	my $debugmsg = shift;
	return undef unless $debug; # CHANGED check for debug flag at top and return if false. 2011-06-10
	return undef if (!$debugmsg || $debugmsg =~ $empty_re); # CHANGED check for empty debug message 2011-06-10
	Irssi::print("%Y[$IRSSI{name}]%n %R[debug]%n " . irssi_safe($debugmsg)); # CHANGED make debug message safe for irssi printing 2011-06-10
}


=head3 irssi_safe

Prepare a message for output to Irssi by making sure anything needed
is escaped. Currently, that's only the percent sign (%).

=over

=item *
param string $s - message to clean

=item *
returns string - cleaned up string

=back

=cut

sub irssi_safe {
	my $s = shift;
	return '' if (!$s || $s =~ $empty_re); # CHANGED check if string is set, return empty string 2011-06-10
	
	$s =~ s/%/%%/g;
	return $s;
}

=head3 shownotice

Nicely format a string to show up on the user's current window

=over

=item *
param string $s - message to show

=item *
returns void

=back

=cut

sub shownotice {
	my $msg = shift;
	return if (!$msg || $msg =~ $empty_re);
	Irssi::print("%Y[$IRSSI{name}]%n $msg");
	
}

=head3 showerror

Nicely format an error messge string to show up on the user's current window

=over

=item *
param string $s - message to show

=item *
returns void

=back

=cut

sub showerror {
	my $msg = shift;
	return if (!$msg || $msg =~ $empty_re);
	Irssi::print("%Y[$IRSSI{name}]%n %RERROR!! $msg");
}

=head3 say_message

Say a message to the specified server/channel

=over

=item *
param object $server - current server object

=item *
param string $target - current channel/query window name

=item *
param string $msg - message to send

=item *
returns void

=back

=cut

sub say_message {
	my ($server, $target, $msg) = @_;
	$server->command("msg $target [$IRSSI{name}] $msg");
}

=head3 me_action

send an action message to the current chatnet/channel

=over    

=item *
param object $server - current server object

=item *
param string $target - name of current channel

=item *
param string $msg - message to send

=item *
returns void

=back    

=cut

sub me_action {
	my ($server, $target, $msg) = @_;
	$server->command("ACTION $target $msg");
}

=head3 printOnThisWindow

send a string to the current window

=over

=item *
param object $server - current server object

=item *
param string $target - name of current channel

=item *
param string $msg - message to send

=item *
returns void

=back

=cut

sub printOnThisWindow {
	my ($server, $target, $msg) = @_;
	my $witem = $server->window_find_item($target);
	$witem->print("[$IRSSI{name}] $msg");
}

=head3 lc_irc

convert the passed string to lower case, special for irc

=over

=item *
param string $str - string to convert

=item *
returns string - convert string

=back

=cut

sub lc_irc($) {
    my ($str) = @_;
    $str =~ tr/A-Z[\\]/a-z{|}/;
    return $str;
}

=head3 uc_irc

convert the passed string to upper case, special for irc

=over

=item *
param string $str - string to convert

=item *
returns string - convert string

=back

=cut

sub uc_irc($) {
    my ($str) = @_;
    $str =~ tr/a-z{|}/A-Z[\\]/;
    return $str;
}


shownotice("Database is $database");



=head2 Database handling functions

=head3 do_listen

Process a listen database entry

=over

=item *
param string $chatnet - the chat network to apply the listen item to

=item *
param string $channel - the channel to apply the listen item to

=item *
param string $status - which status to apply (on or off)

=back

=cut

sub do_listen {
	my ($chatnet, $channel, $status) = @_;
	if ($status eq "on") {
		$listen_on{$chatnet}{$channel} = $status;
	} else {
		delete $listen_on{$chatnet}{$channel};
	}
}

=head3 do_filter

process the filter database entry

=over

=item *
param string $chatnet - chatnet to apply the filter string to

=item *
param string $channel - channel to apply the filter string to

=item *
param string $filter - filter to apply

=back

=cut

# TODO check to see if filter is already in filter list. if it is, skip it
sub do_filter {
	my ($chatnet, $channel, $filter) = @_;
	@{$filters{$chatnet}{$channel}} = () unless defined $filters{$chatnet}{$channel};
	push @{$filters{$chatnet}{$channel}}, $filter; # TODO why is this not a list?
}


=head3 do_user

process a user database entry

=over

=item *
param string $chatnet - chatnet to apply the user string to

=item *
param string $channel - channel to apply the user string to

=item *
param string $user - user string to apply

=back

=cut

# TODO check to see if user is already in user list, if they are, skip them
sub do_user {
	my ($chatnet, $channel, $user) = @_;
	@{$validusers{$chatnet}{$channel}} = () unless defined $validusers{$chatnet}{$channel};
	push @{$validusers{$chatnet}{$channel}}, ($user);
}


=head3 do_ignore

process an ignore database entry

=over

=item *
param string $chatnet - chatnet to apply the ignore directive to

=item *
param string $channel - channel to apply the ignore directive to

=item *
param string $status - ignore directive (or or off)

=back

=cut

sub do_ignore {
	my ($chatnet, $channel, $status) = @_;
	if ($status eq "on") {
		$ignores{$chatnet}{$channel} = $status;
	} else {
		delete $ignores{$chatnet}{$channel};
	}
}

=head3 syntax_error

Report a syntax error reading and processing the database

=cut

sub syntax_error {
	die "%R[$IRSSI{name} Syntax error reading database";
}


=head3 %parse_database

An associative array containing a jump table to handle each database
entry type. Structure is:

=over

=item *
C<%parse_database[entrytype] => &function;> - jump table

=back

=cut

our %parse_database = (
    listen => sub {
        $_[0] =~ /^ ([^ ]*) ([^ ]*) (on|off)$/ or syntax_error;
        do_listen  $1, $2, $3;
    },
	filter => sub {
		$_[0] =~ /^ ([^ ]*) ([^ ]*) (.*)$/ or syntax_error;
		do_filter $1, $2, $3;
	},
	user => sub {
		$_[0] =~ /^ ([^ ]*) ([^ ]*) ([^ ]*)$/ or syntax_error;
		do_user $1, $2, $3;
	},
	ignore => sub {
		$_[0] =~ /^ ([^ ]*) ([^ ]*) (on|off)$/ or syntax_error;
		do_ignore $1, $2, $3;
	}
);



=head3 read_database

reads and processes the various entries in the database

=cut

sub read_database() {
    %listen_on = ();
    %filters = ();
    %validusers = ();
    open DATABASE, $database or return;
    while (<DATABASE>) {
        chomp;
        /^([^ ]*)(| .*)$/ or syntax_error;
        my $func = $parse_database{$1} or syntax_error;
        $func->($2);
    }
    close DATABASE;
}


=head3 write_database

Writing the database to file

=cut

sub write_database {
    open DATABASE, ">$database_tmp";
    foreach my $chatnet (keys %listen_on) {
        foreach my $channel (keys %{$listen_on{$chatnet}}) {
            my $state = $listen_on{$chatnet}{$channel};
            print DATABASE "listen $chatnet $channel $state\n";
        }
    }
	foreach my $chatnet (keys %filters) {
		foreach my $channel (keys %{$filters{$chatnet}}) {
			if (defined $filters{$chatnet}{$channel}) {
				foreach my $filter (@{$filters{$chatnet}{$channel}}) {
					print DATABASE "filter $chatnet $channel $filter\n";
				}
			}
		}
	}
	foreach my $chatnet (keys %validusers) {
		foreach my $channel (keys %{$validusers{$chatnet}}) {
			if (defined $validusers{$chatnet}{$channel}) {
				foreach my $address (@{$validusers{$chatnet}{$channel}}) {
					print DATABASE "user $chatnet $channel $address\n";
				}
			}
		}
	}
    foreach my $chatnet (keys %ignores) {
        foreach my $channel (keys %{$ignores{$chatnet}}) {
            my $state = $ignores{$chatnet}{$channel};
            print DATABASE "ignore $chatnet $channel $state\n";
        }
    }
   close DATABASE;
    rename $database, $database_old;
    rename $database_tmp, $database;
	shownotice("wrote database");
}

=head3 append_to_database

Append an entry to the database

=over

=item *
param array @_ - elements to add to the database

=back

=cut

sub append_to_database(@) {
    open DATABASE, ">>$database";
    print DATABASE map {"$_\n"} @_;
    close DATABASE;
}


=head2 URL Processing

=head3 is_html

Retrieve the header of the given URL to see if it contains HTML code

=over

=item *
param string $url - the url to check

=item *
returns boolean - true if url contains HTML, false if not

=back

=cut

sub is_html {
	my $url = shift;
	return 0 if (!$url || $url =~ $empty_re);
	my $curl_cmd = "curl";
	my $curlopt_connect_timeout = Irssi::settings_get_int('st_connect_timeout')?Irssi::settings_get_int('st_connect_timeout'):15;
	my $curlopt_max_timeout = Irssi::settings_get_int('st_max_timeout')?Irssi::settings_get_int('st_max_timeout'):30;
	my @curlopts = (
	    "--fail",
		"-I",
		"--insecure",			# don't worry if a certificate doesn't pass
	    '-A "Mozilla"', 
		"--connect-timeout ".$curlopt_connect_timeout,
	    "--location",
		"--max-time ".$curlopt_max_timeout,
	    "--silent"
	);
	my $cmd = $curl_cmd . ' ' . join( ' ', @curlopts ) . ' ' . "'" . $url . "'";
	DebugPrint("cmd=$cmd");
	my @result = `$cmd`;
	if ($!) {
		## OOPS, curl command returned an error
		my $curl_error=$!;
		showerror("Curl command: $cmd - returned an error: $curl_error.".
		    " Current Chatnet: $current_chatnet".
		    " Current channel: $current_channel".
		    " Current URL: $url");
		return 0;
	}
	chomp(@result);
	DebugPrint("Size of result: " . ( $#result + 1 ));
	for (my $i = 0 ; $i <= $#result ; $i++ ) {
	    DebugPrint("$i: $result[$i]");
	}
	my @content_type = grep(/^Content-Type:/,@result);
	DebugPrint("Matches: ".($#content_type+1));
	
	for (my $i = 0; $i < $#content_type+1; $i++) {
		DebugPrint("$i: $content_type[$i]");
		if ($content_type[$i] =~ m:text/x?html:) {
			DebugPrint("It's html!");
			return 1;
		}
	}
	return 0;
}

=head3 grab_page
    
get the page for the specified URL -- possibly only a fragment

=over    

=item *
param string $url - the url to grab

=item *
returns string - contents of page

=back

B<description>: 

Uses curl (command line version) to pull over the contents of the
specified URL. The curl command is set to be silent, unless the
command fails. Other parameters to the curl command include the output
file name, the user agent string, a connect timeout and a max timeout,
and to follow relocation headers (302s) from the web server.

=cut

sub grab_page {
	my $url = shift;
	return undef if (!$url || $url =~ $empty_re);
	my $outputfile = '/tmp/curl.'.time; # cheap way to make a unique file?
	unlink($outputfile); # just to be sure
	my $curlopt_connect_timeout = Irssi::settings_get_int('st_connect_timeout')?Irssi::settings_get_int('st_connect_timeout'):15;
	my $curlopt_max_timeout = Irssi::settings_get_int('st_max_timeout')?Irssi::settings_get_int('st_max_timeout'):30;
	my $curl_cmd = "curl";
	my @curlopts = (
	    "--fail", 
		"--insecure",			# don't worry if a certificate doesn't pass
		"-o $outputfile", 
		#"--max-filesize 10240", # this tends to cause some requests to fail strangely
	    '-A "Mozilla"', 
		"--connect-timeout ".$curlopt_connect_timeout,
	    "--location",			# follow 302 returns
		"--max-time ".$curlopt_max_timeout,
	    "--silent", 
		"--show-error"
	);
	my $cmd = $curl_cmd . ' ' . join( ' ', @curlopts ) . ' ' . "'" . $url . "'".' 2>&1';
	DebugPrint("cmd=$cmd");
	my @result = `$cmd`;
	if ($!) {
		## OOPS, curl command returned an error
		my $curl_error=$!;
		showerror("Curl command: $cmd -  returned an error: $curl_error".
		    " Current chatnet: $current_chatnet".
		    " Current channel: $current_channel");
		return undef;
	}
	DebugPrint("Value of \$#result=$#result");
	if ($#result+1 > 0) {
		shownotice("curl said something...");
		for (my $i = 0; $i <= $#result; $i++) {
			shownotice("[$i] $result[$i]");
		}
		shownotice(" Current chatnet: $current_chatnet".
			   " Current channel: $current_channel");

		return;
	}
	
	# grab the contents from the returned file
	unless (open(FH,"< $outputfile"))  {
		showerror("Could not open $outputfile for reading: $!");
		return undef;
	}
	@result = <FH>;
	close(FH);
	unlink($outputfile) unless $debug;
	chomp(@result);

	DebugPrint(($#result+1)." lines returned");

	# the following is only to be able to present something more reasonable than the full result from the function
	for (my $i = 0; $i < 20; $i++) {
		if (length($result[$i])>50) {
			my $shorter = substr($result[$i],0,49)."...";
			DebugPrint("$i: $shorter");
		} else {
			DebugPrint("$i: $result[$i]");
		}
	}
	
	return join(' ',@result);
}


=head3 get_title

Pull the title from the contents and clean it up

=over

=item *
param string $content -- the contents of the web page

=item *
returns string -- the cleaned up and presentable title

=back

=cut

sub get_title {
	my $content = shift;
	return "No Title" if (!$content || $content =~ $empty_re);
	my @lines;
	my $title = "No Title";

	# For the following regexes, treat the various text containers as one lone string, ignoring newlines
	$content =~ /<\s*title\s*[^>]*>(.*?)<\/\s*title\s*>/msgi;
	DebugPrint("Match: $1");
	$title = $1 if $1; # set title only if there is has been a match
	$title =~ s/[[:cntrl:]]*//msg; # get rid of extraneous control characters
	$title =~ s/\n/ /msg; # convert newlines to spaces
	# handle certain entity codes
	$title =~ s/&nbsp;/ /msg;
	$title =~ s/&[rl]squo;/'/msg;
	$title =~ s/&amp;/&/msg;
	$title =~ s/&lt;/</msg;
	$title =~ s/&gt;/>/msg;
	$title =~ s/&(#39|apos);/'/msg;
	$title =~ s/&#x26;/&/msg;
	$title =~ s/&#8220;/"/msg;
	$title =~ s/&#8221;/"/msg;
	$title =~ s/&quot;/"/msg;

	# begin modifications by Jess -- Youtube specific mods no longer required 2011-12-30
		
	# handle all other entity codes
	$title =~ s/&[a-z0-9A-Z]+;//msg;
	$title =~ s/&#x?[0-9a-fA-F]+;//msg;
	
	# Strip repeated spaces -- UPDATED: 2011-12-30 jess remove begining and trailing line breaks and whitespace
	$title =~ s/\s+/ /msg;
	#Beginning Whitespace removal
	$title =~ s/^\s+//msg;
	#End Whitespace Removal
	$title =~ s/\s+$//msg;
	DebugPrint("title=$title");
	return $title;
	
}

=head3 find_url

Extract the url from the message text

=over

=item *
param string $text - the contents of the IRC message we're processing

=item *
return string - the URL extracted, or undef otherwise

=back

find_url will match on the text for various URL schemes (currently only supporting FTP and HTTP).
In addition, if the bareword "www" precedes a triple-word, it is treated as an HTTP URL and modified accordingly.

=cut

sub find_url {
   my $text = shift;
   if($text =~ /\b((ftp|https?):\/\/[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~\,]*)/i){
		DebugPrint($1);
	  return $1;
   }elsif($text =~ /\b(www\.[a-zA-Z0-9\/\\\:\?\%\.\&\;=#\-\_\!\+\~\,]*)/i){
		DebugPrint($1);
	  return "http://".$1;
   }
   return undef;
}

=head3 pass_filter

Check to see if the url passes various filters

=over

=item *
param object $server - current server object

=item *
param string $target - name of current channel/query

=item *
param string $url - current url

=item *
returns boolean - true if it passes filters, false if not

=back

=cut

sub pass_filter {
	my ($server, $target, $url) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	return 0 unless ($listen_on{$chatnet}{$channel} eq "on"); # returns false if we're not listening on this channel
	return 1 unless defined $filters{$chatnet}{$channel}; # returns true if there are no filters for this channel
	my @thesefilters = @{$filters{$chatnet}{$channel}};
	return 1 unless (@thesefilters); # returns true if there are no filters for this channel
	foreach my $filter (@thesefilters) {
		DebugPrint("url = $url ; filter = $filter");
		return 1 if $url =~ $filter; # returns true if there's a match
	}
	return 0; # no matches, return false
}


=head3 showtitle

Main logic of the script -- display the title of a given URL on either the target's channel, or to the user's screen

=over

=item *
param object $server - the server where the URL was shown

=item *
param string $msg - the data from the current irc message

=item *
param string $target - the current window

=back

B<showtitle> checks the message to see if it contains a valid URL string (currently only ftp: and http: are supported). B<showtitle> will also match if the string begins with "www". It then checks to see if the URL contains an HTML content type.

=cut

sub showtitle {
    my ($server, $msg, $target) = @_;
    my $url = find_url($msg);
    my $line_prefix = Irssi::settings_get_str('st_line_prefix')?Irssi::settings_get_str('st_line_prefix'):"URL title: ";
    if ($url && is_html($url)) {
	my $page = grab_page($url);
	if ($page && $page !~ $empty_re) {
	    my $title = get_title($page);
	    if ($title && $title !~ $empty_re) {
		if (pass_filter($server, $target, $url)) {
		    me_action($server, $target, $line_prefix . $title);
		} else {
		    printOnThisWindow($server,$target, $line_prefix . $title);
		}
	    }
	}
    }
}

########## Command Processing ##########

=head2 Command Processing

=head3 is_validuser

Checks to see if calling user is in the list of valid users

=over

=item *
param string $user - user to validate

=item *
param string $chatnet - current chatnet

=item *
param string $channel - current channel

=item *
returns boolean - whether user is valid or not

=back

=cut

sub is_validuser {
	my ($user, $chatnet, $channel) = @_;
	return 1 unless defined $validusers{$chatnet}{$channel};
	return 1 unless (@{$validusers{$chatnet}{$channel}});
	foreach my $channeluser (@{$validusers{$chatnet}{$channel}}) {
		return 1 if ($user eq $channeluser);
	}
	return 0;
}


=head3 process_listen

Process an !st listen on/off request

=over

=item *
param string $status - whether to turn listening on or off

=item *
param object $server

=item *
param string $nick - user sending request

=item *
param string $address - address of nick sending request

=item *
param string $target - channel or query originating request

=item *
returns void

=back

=cut

sub process_listen {
	my ($status, $server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	unless(is_validuser($address, $chatnet, $channel)) {
		say_message($server, $nick, "You have insufficient privileges to do that");
		return;
	}
	if ($status eq "on") {
		do_listen $chatnet, $channel, $status;
		append_to_database("listen $chatnet $channel $status"); # CHANGED order of keywords in data base to conform to other entries
	} else {
		delete $listen_on{$chatnet}{$channel};
		write_database;
	}
	say_message($server, $target, "listening for $channel is turned $status");
	
}

=head3 show_listen

List the current channels being listened to for urls

=over

=item *
param object $server

=item *
param string $nick

=item *
param string $address

=item *
param string $target

=back

=cut

sub show_listen {
	my ($server, $nick, $address, $target) = @_;
	say_message($server, $nick, "listening on:");
	# Restrict listing to just this chatnet - don't show I'm on other networks
	my $chatnet = lc $server->{chatnet};
	foreach my $channel (keys %{$listen_on{$chatnet}}) {
		my $state = $listen_on{$chatnet}{$channel};
		say_message($server, $nick, "$chatnet: $channel: listening is $state");
	}
}

=head3 listen_help

    Provide help to the calling user, sent as private message.

=over

=item *
param object $server

=item *
param string $nick

=item *
param string $address

=item *
param string $target

=back

=cut

sub listen_help {
	my ($server, $nick, $address, $target) = @_;
	my @help_msg = (
		"Control whether $IRSSI{name} is listening on a certain channel",
		"",
		"  !st listen on - turns listening on for the current channel/query",
		"  !st listen off - turns listening off for the current channel/query",
		"  !st listen help - displays this message",
		"  !st listen - displays current channel/query's listening status"
		);
	foreach my $m (@help_msg) {
		say_message($server, $nick, $m);
	}
}


=head3 show_listen_status

Show whether the current chatnet/channel is being listened to

=over

=item *
param object $server

=item *
param string $nick

=item *
param string $address

=item *
param string $target

=back

=cut

sub show_listen_status {
	my ($server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	my $status = $listen_on{$chatnet}{$channel} eq "on" ? "on" : "off";
	say_message($server, $target, "listening is currently $status for $channel");
}

=head3 add_filter

Add a filter to the current channel. Filters are treated as regexes. If a filter is specified as "qr/.../", then it will be evaled as is, if it isn't, then "qr/" and "/" will be wrapped around what ever is given.

=over

=item *
param string $filter -- the filter to add

=item *
param object $server

=item *
param string $nick

=item *
param string $address

=item *
param string $target

=back

=cut

sub add_filter {
	my ($filter, $server, $nick, $address, $target) = @_;
	
	# Check to see if the filter is in a qr/../ form
	unless ($filter =~ /^qr\/.*\//) {
		$filter = eval "qr/" . $filter . "/"; # convert filter to qr/.../ form
	} else {
		$filter = eval $filter;
	}
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	unless(is_validuser($address, $chatnet, $channel)) {
		say_message($server, $nick, "You have insufficient privileges to do that");
		return;
	}
	do_filter $chatnet, $channel, $filter;
	append_to_database "filter $chatnet $channel $filter";
	say_message($server,$target,"added $filter to $channel")
}

=head3 delete_filter

Deletes a given filter. Filters are regexes. If a filter is specifed with "qr/.../" then it is used as is. Otherwise "qr/" and "/" are wrapped around teh filter text and it is evaled.

=over

=item *
param string $filter -- the filter to delete

=item *
param object $server

=item *
param string $nick

=item *
param string $address

=item *
param string $target

=back

=cut

sub delete_filter {
	my ($filter, $server, $nick, $address, $target) = @_;
	# Check to see if the filter is in a qr/../ form
	unless ($filter =~ /^qr\/.*\//) {
		$filter = eval "qr/" . $filter . "/"; # convert filter to qr/.../ form
	} else {
		$filter = eval $filter;
	}
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	unless(is_validuser($address, $chatnet, $channel)) {
		say_message($server, $nick, "You have insufficient privileges to do that");
		return;
	}
	my @new_filter_list = ();
	@{$filters{$chatnet}{$channel}} = () unless defined $filters{$chatnet}{$channel};
	foreach my $channelfilter (@{$filters{$chatnet}{$channel}}) {
		unless ($filter eq $channelfilter) {
			push @new_filter_list, ($channelfilter);
		}
	}
	@{$filters{$chatnet}{$channel}} = @new_filter_list;
	write_database;
	say_message($server, $target, "removed $filter from $channel");
}



=head3 show_filters

Give a list of filters on the current channel

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub show_filters {
	my ($server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	return unless defined $filters{$chatnet}{$channel};
	say_message($server, $nick, "Filters on $channel:");
	foreach my $filter (@{$filters{$chatnet}{$channel}}) {
		say_message($server, $nick, $filter);
	}
}





=head3 filter_help

Send help messages to calling nick as private messages

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub filter_help {
	my ($server, $nick, $address, $target) = @_;
	my @help_msg = (
		"Filter command help",
		"",
		"   !st filter - show current filtering status",
		"   !st filter add regex - add a regular expression filter to the current channel's filter list",
		"   !st filter delete regex - remove a filter from the current channel's filter list",
		"   !st filter list - list the current channel's filters",
		"   !st filter help - this message",
		"",
		"You can specify the filters either with or without the qr/.../ syntax.",
		"Specifying the qr/.../ syntax is especially useful when you want to include modifiers,",
		"such as setting case-insensitivity, which would be accomplished by:",
		"",
		"!st filter add qr/regex/i",
		"",
		"If you don't specify the qr/.../ syntax, the filter will be converted to use it.",
		"This is especially important to note if you want to delete the filter subsequently."
		);
	foreach my $m (@help_msg) {
		say_message($server, $nick, $m);
	}
}

=head3 show_filter_status

Show what the current filter status is on channel (on or off)

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub show_filter_status {
	my ($server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	my $filter_status;
	if (defined $filters{$chatnet}{$channel}) {
	 	$filter_status = (@{$filters{$chatnet}{$channel}}) ? "on" : "off";
	} else {
		$filter_status = "off";
	}
	say_message($server, $target, "Filtering for $channel is currently $filter_status");
}


=head3 add_user

Add a user to the authorized users list for this channel

=over

=item *
param string $user -- user to add to authorized user's list (currently is host part of their hostmask)

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub add_user {
	my ($user, $server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	unless(is_validuser($address, $chatnet, $channel)) {
		say_message($server, $nick, "You have insufficient privileges to do that");
		return;
	}
	do_user $chatnet, $channel, $user;
	append_to_database "user $chatnet $channel $user";
	say_message($server, $target, "added $user to $channel valid users");
}

=head3 delete_user

Remove a user to the authorized users list for this channel

=over

=item *
param string $user -- user to remove to authorized user's list (currently is host part of their hostmask)

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub delete_user {
	my ($user, $server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	unless(is_validuser($address, $chatnet, $channel)) {
		say_message($server, $nick, "You have insufficient privileges to do that");
		return;
	}
	@{$validusers{$chatnet}{$channel}} = () unless defined $validusers{$chatnet}{$channel};
	my @channelusers = @{$validusers{$chatnet}{$channel}};
	my @newuserlist = ();
	foreach my $channeluser (@channelusers) {
		unless ($user eq $channeluser) {
			push @newuserlist, ($channeluser);
		}
	}
	@{$validusers{$chatnet}{$channel}} = @newuserlist;
	write_database;
	say_message($server, $target, "deleted $user from $channel valid users");
}

=head3 list_users

Show the current set of authorized users for the chatnet/channel

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub list_users {
	my ($server, $nick, $address, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	return unless defined $validusers{$chatnet}{$channel};
	say_message($server, $nick, "Users on $chatnet $channel");
	foreach my $user (@{$validusers{$chatnet}{$channel}}) {
		say_message($server, $nick, $user);
	}
}

=head3 user_request

Send a user request to the owner of the bot to add to authorized users

=over

=item *
param string $user -- user to remove to authorized user's list (currently is host part of their hostmask)

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub user_request {
    my ($user, $server, $nick, $address, $target) = @_;
    my $chatnet = lc_irc $server->{chatnet};
    my $channel = lc_irc $target;
    my $botnick = $server->{nick};
    say_message($server,$botnick,"Request from $nick ($address):");
    say_message($server,$botnick,"Please add $user to $chatnet $channel user list");
}

=head3 user_help

Send help info to requesting user as private messages

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub user_help {
	 my ($server, $nick, $address, $target) = @_;
	 my @help_msg = (
		 "Valid user help",
		 "",
		 "   !st user - show current (calling) user's status",
		 "   !st user add hostmask - add the hostmask to current channel's valid user list",
		 "   !st user delete hostmask - delete the hostmask from the current channel's valid user list",
		 "   !st request - request the bot owner to add the current (calling) user's address",
		 "	!st request hostmask - request the bot owner to add the given hostmask",
		 "   !st user list - list the users for the current channel",
		 "   !st user help - this message",
		 "",
		 "$IRSSI{name} implements a valid user concept that limits",
		 "certain commands to people on the valid user list.",
		 "Users are kept on a per-chatnet, per-channel basis",
		 "and are based on the user's hostmask.",
		 "Thus, if you change hostmasks, you will need to be added to",
		 "the valid user database again for each channel you want",
		 "control over.",
		 "",
		 "Note if no users are specified for a given channel on a network,",
		 "all commands are available freely. This has the unfortunate side-effect",
		 "that the first person who adds a user locks it down for everyone else.",
		 "(except the bot owner)."
		 );
	 foreach my $m (@help_msg) {
		 say_message($server, $nick, $m);
	 }
 }


=head3 show_user_status

Say whether the requesting user is an authorized user or not

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub show_user_status {
    my ($server, $nick, $address, $target) = @_;
    my $chatnet = lc_irc $server->{chatnet};
    my $channel = lc_irc $target;
    my $status = (is_validuser($address, $chatnet, $channel)) ? " is " : " is not ";
    say_message($server, $target, $nick . $status . "a valid user on $chatnet $channel");
}

=head3 showtitle_help

Send help info to requesting user as private messages

=over

=item *
param object $server - current server object

=item *
param string $nick - nick of person making request

=item *
param string $address - address of person making request

=item *
param string $target - channel/query to send to

=back

=cut

sub showtitle_help {
    my ($server, $nick, $address, $target) = @_;
    my @help_msg = (
	"$IRSSI{name} $VERSION help",
	"",
	"the following commands are available:",
	"  !st listen [on|off|list|help]",
	"  !st filter [add regex|delete regex|list|help] ",
	"  !st user [add address|delete address|list|help]",
	"  !st help",
	"",
	"you can also use !showtitle as the command prefix instead of !st"
	);
    foreach my $m (@help_msg) {
	say_message($server, $nick, $m);
    }
    say_message($server, $target, "help sent");
}


=head3 parse_command jump table

A jump table to determine which subroutine to use to process the command

=cut

our %parse_command = (
    listen => sub {
	my ($data, $server, $nick, $address, $target) = @_;
      SWITCH: {
	  $data =~ /^ (on|off)$/ && do {process_listen $1, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ list$/ && do {show_listen $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ help$/ && do {listen_help $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^$/ && do {show_listen_status $server, $nick, $address, $target; last SWITCH;};
	  say_message($server, $target, "Invalid syntax. Try !st listen help");
	}
    },
    filter => sub {
	my ($data, $server, $nick, $address, $target) = @_;
      SWITCH: {
	  $data =~ /^ delete (.*)$/ && do {delete_filter $1, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ list$/ && do {show_filters $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ help$/ && do {filter_help $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ add (.*)$/ && do {add_filter $1, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^$/ && do {show_filter_status $server, $nick, $address, $target; last SWITCH;};
	  say_message($server, $target, "Invalid syntax. Try !st filter help");
	}
    },
    user => sub {
	my ($data, $server, $nick, $address, $target) = @_;
      SWITCH: {
	  $data =~ /^ add ([^ ]*)$/ && do {add_user $1, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ delete ([^ ]*)$/ && do {delete_user $1, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ request$/ && do {user_request $address, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ request ([^ ]*)$/ && do {user_request $1, $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ list$/ && do {list_users $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^ help$/ && do {user_help $server, $nick, $address, $target; last SWITCH;};
	  $data =~ /^$/ && do {show_user_status $server, $nick, $address, $target; last SWITCH;};
	  say_message($server, $target, "Invalid syntax. Try !st user help");
	}
    },
    help => sub {
	my ($data, $server, $nick, $address, $target) = @_;
	showtitle_help($server, $nick, $address, $target);
    }
    );


=head3 process_command

process the command given with the C<st> trigger

=over

=item *
param object $server - current server object

=item *
param string $msg - command from channel

=item *
param string $nick - requesting user

=item *
param string $address - address of requesting user

=item *
param string $target - name of channel/query

=item *
returns void

=back

=cut

sub process_command {
	my ($server, $msg, $nick, $address, $target) = @_;
	SWITCH: {
	$msg =~ /^!(showtitle|st) ([^ ]*)(| .*)$/ && 
		do {
			my $cmd = $2;
			my $data = $3;
			my $func = $parse_command{$cmd} or 
				do {say_message($server, $target, "Syntax error. Try !st help"); return;};
			$func->($data, $server, $nick, $address, $target);
			last SWITCH;
		};
	$msg =~ /^!(showtitle|st)$/ &&
		do {
			say_message($server, $target, "for help type !st help");
			last SWITCH;
		};
	$msg =~ /^!help(| .*)$/ &&
		do {
			say_message($server, $target, "for help type !st help");
			last SWITCH;
		};
	}
}



=head3 ignored

returns true if the current chatnet/channel is being ignored

=over

=item *
param object $server - current server object

=item *
param string $target - name of current channel/query

=item *
returns boolean

=back

=cut

sub ignored {
	my ($server, $target) = @_;
	my $chatnet = lc_irc $server->{chatnet};
	my $channel = lc_irc $target;
	return ($ignores{$chatnet}{$channel} eq "on") ? 1 : 0;  # good old ternary operator!!

}

=head3 sig_showtitle

Process the signals from a channel for showtitle requests and URLs

=over

=item *
param object $server - current server object

=item *
param string $msg - message received

=item *
param string $nick - user who send the message

=item *
param string $address - address of user

=item *
param string $target - name of channel/query sending message

=item *
returns void

=back

=cut

sub sig_showtitle {
	my ($server, $msg, $nick, $address, $target) = @_;
	unless ($server && $server->{connected}) {
		showerror("not connected to server");
	}
	Irssi::signal_continue(@_);
	$target = $nick if $target eq "";
	$current_chatnet = $server->{chatnet};
	$current_channel = $target;
	if ($msg =~ /^!/ && !ignored($server, $target)) {
		process_command($server, $msg, $nick, $address, $target);
	} else {
		showtitle($server, $msg, $target);
	}
}
Irssi::signal_add_last("message public", "sig_showtitle");
Irssi::signal_add_last("message private", "sig_showtitle");

=head3 sig_own_showtitle

Process the signals from self for showtitle requests and URLs

=over

=item *
param object $server - current server object

=item *
param string $msg - message sent

=item *
param string $target - name of channel/query sending message to

=item *
returns void

=back

=cut

sub sig_own_showtitle {
	my ($server, $msg, $target) = @_;
	unless ($server && $server->{connected}) {
		showerror("not connected to server");
	}
	$current_chatnet = $server->{chatnet};
	$current_channel = $target;
	Irssi::signal_continue(@_);
	my $line_prefix = Irssi::settings_get_str('st_line_prefix')?Irssi::settings_get_str('st_line_prefix'):"URL title: ";
	if ($msg =~ qr{$line_prefix}) {
		# message from me with the title -- ignore this message
		return;
	}
	my $nick = $server->{nick};
	my $address = $server->{userhost};
	if ($msg =~ /^!/ && !ignored($server,$target)) {
		process_command($server, $msg, $nick, $address, $target);
	} else {
		showtitle($server, $msg, $target);
	}
}



Irssi::signal_add_last("message own_public", "sig_own_showtitle");
Irssi::signal_add_last("message own_private", "sig_own_showtitle");

# CHANGED make showtitle respond to url's in actions as well as messages
#"message irc own_action", SERVER_REC, char *msg, char *target
#"message irc action", SERVER_REC, char *msg, char *nick, char *address, char *target

Irssi::signal_add_last("message irc action", "sig_showtitle");
Irssi::signal_add_last("message irc own_action", "sig_own_showtitle");



=head2 UI commands

=cut

=head3 cmd_stuser

Dispatch the appropriate user command.

=over

=item *
param string $data - data from the command

=item *
param object $server - current server object

=item *
param object $witem - current window item

=item *
returns void

=back

C<cmd_stuser> uses the C<Irssi::command_runsub> to dispatch the appropriate subcommand based on the first word in the C<$data> string. Commands include:

=over

=item *
C<add> -- add a user

=item *
C<delete> -- remove a user

=item *
C<list> -- list users

=back

=cut

sub cmd_stuser {
	my ($data, $server, $witem) = @_;
	Irssi::command_runsub("stuser", $data, $server, $witem);
}

Irssi::command_bind('stuser', 'cmd_stuser');


=head3 cmd_stuser_add

Add a user to the authorized user list for a given channel and chatnet

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the user to add as:

C<< /stuser add [[[chatnet] channel] hostmask] >>


=cut

sub cmd_stuser_add {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel, $address);
	if ($data =~ $empty_re) {
		# nothing given, just add the current user to this channel
		$address = $witem->{ownnick}->{host};
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) *$/) {
		# just the hostmask given
		$address = $1;
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# channel and hostmask given
		$channel = lc $1;
		$address = $2;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel and hostmask given
		$chatnet = lc $1;
		$channel = lc $2;
		$address = $3;
	}
	DebugPrint("address=$address ; chatnet=$chatnet ; channel=$channel (in cmd_stuser_add)");
	
	do_user $chatnet, $channel, $address;
	append_to_database "user $chatnet $channel $address";
	shownotice("$address added to $chatnet $channel");
}

Irssi::command_bind('stuser add', 'cmd_stuser_add');

=head3 cmd_stuser_delete

Delete a user based on chatnet, channel and/or hostmask

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the user to delete as:

C<< /stuser delete [[[chatnet] channel] hostmask] >>


=cut

sub cmd_stuser_delete {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel, $address);
	if ($data =~ /^ *([^ ]+) *$/) {
		# just the hostmask given
		$address = $1;
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# channel and hostmask given
		$channel = lc $1;
		$address = $2;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel and hostmask given
		$chatnet = lc $1;
		$channel = lc $2;
		$address = $3;
	}
	return unless defined $validusers{$chatnet}{$channel};
	$validusers{$chatnet}{$channel} =
		[grep {lc $_ ne lc $address} @{$validusers{$chatnet}{$channel}}];
	write_database;
	shownotic("$address removed from $chatnet $channel");
}

Irssi::command_bind('stuser delete', 'cmd_stuser_delete');

=head3 cmd_stuser_list

List the current set of users

=over

=item *
param string $data - command line data

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

=cut

sub cmd_stuser_list {
	my ($data, $server, $witem) = @_;
	shownotice("User list");
	foreach my $chatnet (keys %validusers) {
		shownotice("$chatnet :");
		foreach my $channel (keys %{$validusers{$chatnet}}) {
			shownotice("  $channel :");
			if (defined $validusers{$chatnet}{$channel}) {
				foreach my $user (@{$validusers{$chatnet}{$channel}}) {
					shownotice("    $user");
				}
			}
		}
	}
}

Irssi::command_bind('stuser list', 'cmd_stuser_list');

=head3 cmd_stfilter

Dispatch the appropriate filter command.

=over

=item *
param string $data - data from the command

=item *
param object $server - current server object

=item *
param object $witem - current window item

=item *
returns void

=back

C<cmd_stfilter> uses the C<Irssi::command_runsub> to dispatch the appropriate subcommand based on the first word in the C<$data> string. Commands include:

=over

=item *
C<add> -- add a filter

=item *
C<delete> -- remove a filter

=item *
C<list> -- list filters

=back

=cut

sub cmd_stfilter {
	my ($data, $server, $witem) = @_;
	Irssi::command_runsub("stfilter", $data, $server, $witem);
}

Irssi::command_bind('stfilter', 'cmd_stfilter');

=head3 cmd_stfilter_add

Add a filter to the authorized filter list for a given channel and chatnet

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the filter to add as:

C<< /stfilter add [[[chatnet] channel] hostmask] [qr/]regex[/] >>

=cut

sub cmd_stfilter_add {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel, $filter);
	if ($data =~ /^ *([^ ]+) *$/) {
		# just the filter given
		$filter = $1;
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# channel and filter given
		$channel = lc $1;
		$filter = $2;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel and filter given
		$chatnet = lc $1;
		$channel = lc $2;
		$filter = $3;
	}
	unless ($filter =~ /^qr\//) {
		$filter = eval "qr/" . $filter . "/";
	} else {
		$filter = eval $filter;
	}
	do_filter $chatnet, $channel, $filter;
	append_to_database "filter $chatnet $channel $filter";
	shownotice("$filter added to $chatnet $channel");
}

Irssi::command_bind('stfilter add', 'cmd_stfilter_add');

=head3 cmd_stfilter_delete

Delete a filter to the authorized filter list for a given channel and chatnet

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the filter to delete as:

C<< /stfilter delete [[[chatnet] channel] hostmask] [qr/]regex[/] >>

=cut

sub cmd_stfilter_delete {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel, $filter);
	if ($data =~ /^ *([^ ]+) *$/) {
		# just the filter given
		$filter = $1;
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# channel and filter given
		$channel = lc $1;
		$filter = $2;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel and filter given
		$chatnet = lc $1;
		$channel = lc $2;
		$filter = $3;
	}
	return unless defined $filters{$chatnet}{$channel};
	unless ($filter =~ /^qr\//) {
		$filter = eval "qr/" . $filter . "/";
	} else {
		$filter = eval $filter;
	}
	$filters{$chatnet}{$channel} =
		[grep {lc $_ ne lc $filter} @{$filters{$chatnet}{$channel}}];
	write_database;
	shownotice("$filter removed from $chatnet $channel");
}

Irssi::command_bind('stfilter delete', 'cmd_stfilter_delete');

=head3 cmd_stfilter_list

List the current set of filters

=over

=item *
param string $data - command line data

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

=cut

sub cmd_stfilter_list {
	my ($data, $server, $witem) = @_;
	shownotice("Filter list");
	foreach my $chatnet (keys %filters) {
		shownotice("$chatnet :");
		foreach my $channel (keys %{$filters{$chatnet}}) {
			shownotice("  $channel :");
			if (defined $filters{$chatnet}{$channel}) {
				foreach my $filter (@{$filters{$chatnet}{$channel}}) {
					shownotice("    $filter");
				}
			}
		}
	}
}

Irssi::command_bind('stfilter list', 'cmd_stfilter_list');

=head3 cmd_stlisten

Dispatch the appropriate listen command.

=over

=item *
param string $data - data from the command

=item *
param object $server - current server object

=item *
param object $witem - current window item

=item *
returns void

=back

C<cmd_stlisten> uses the C<Irssi::command_runsub> to dispatch the appropriate subcommand based on the first word in the C<$data> string. Commands include:

=over

=item *
C<on> -- add a channel to listen on

=item *
C<off> -- remove a channel from listening

=item *
C<list> -- list channels listened to

=back

=cut

sub cmd_stlisten {
	my ($data, $server, $witem) = @_;
	Irssi::command_runsub("stlisten", $data, $server, $witem);
}

Irssi::command_bind('stlisten', 'cmd_stlisten');

=head3 cmd_stlisten_on

Turn on listening for the specified chatnet/channel

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the listen channel as:

C<< /stlisten on [[chatnet] channel]  >>

=cut

sub cmd_stlisten_on {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel);
	if ($data =~ /^ *$/) {
		# no arg, use current channel and chatnet
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) *$/) {
		# channel given
		$channel = lc $1;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel given
		$chatnet = lc $1;
		$channel = lc $2;
	}
	do_listen $chatnet, $channel, "on";
	append_to_database "listen $chatnet $channel on";
	shownotice("Listening on $chatnet $channel");
}

Irssi::command_bind('stlisten on', 'cmd_stlisten_on');

=head3 cmd_stlisten_off

Turn off listening on the specified chatnet/channel

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the filter to delete as:

C<< /stlisten off [[chatnet] channel] >>

=cut

sub cmd_stlisten_off {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel);
	if ($data =~ /^ *$/) {
		# no arg, use current channel and chatnet
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) *$/) {
		# channel given
		$channel = lc $1;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel given
		$chatnet = lc $1;
		$channel = lc $2;
	}
	do_listen $chatnet, $channel, "off";
	write_database;
	shownotice("Listening off $chatnet $channel");
}

Irssi::command_bind('stlisten off', 'cmd_stlisten_off');

=head3 cmd_stlisten_list

List the channels being listened to

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

=cut

sub cmd_stlisten_list {
	my ($data, $server, $witem) = @_;
	shownotice("Listen list");
	foreach my $chatnet (keys %listen_on) {
		shownotice("$chatnet :");
		foreach my $channel (keys %{$listen_on{$chatnet}}) {
			my $status = $listen_on{$chatnet}{$channel} eq "on" ? "on" : "off";
			shownotice("  $channel : $status");
		}
	}
	
}

Irssi::command_bind('stlisten list', 'cmd_stlisten_list');

=head3 cmd_stignore

Dispatch the appropriate ignore command.

=over

=item *
param string $data - data from the command

=item *
param object $server - current server object

=item *
param object $witem - current window item

=item *
returns void

=back

C<cmd_stignore> uses the C<Irssi::command_runsub> to dispatch the appropriate subcommand based on the first word in the C<$data> string. Commands include:

=over

=item *
C<on> -- add a filter

=item *
C<off> -- remove a filter

=item *
C<list> -- list filters

=back

=cut

sub cmd_stignore {
	my ($data, $server, $witem) = @_;
	Irssi::command_runsub("stignore", $data, $server, $witem);
}

Irssi::command_bind('stignore', 'cmd_stignore');

=head3 cmd_stignore_on

Turn on ignore for a given chatnet/channel

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the filter to delete as:

C<< /stignore on [[chatnet] channel] >>

=cut

sub cmd_stignore_on {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel);
	if ($data =~ /^ *$/) {
		# no arg, use current channel and chatnet
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) *$/) {
		# channel given
		$channel = lc $1;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel given
		$chatnet = lc $1;
		$channel = lc $2;
	}
	do_ignore $chatnet, $channel, "on";
	append_to_database "ignore on $chatnet $channel";
	shownotice("Ignoring $chatnet $channel");
}

Irssi::command_bind('stignore on', 'cmd_stignore_on');

=head3 cmd_stignore_off

Stop ignoring a given chatnet/channel

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

The user can specify the filter to delete as:

C<< /stignore off [[chatnet] channel] >>

=cut

sub cmd_stignore_off {
	my ($data, $server, $witem) = @_;
	my ($chatnet, $channel);
	if ($data =~ /^ *$/) {
		# no arg, use current channel and chatnet
		$chatnet = lc $server->{chatnet};
		$channel = lc $witem->{name};
	} elsif ($data =~ /^ *([^ ]+) *$/) {
		# channel given
		$channel = lc $1;
		$chatnet = lc $server->{chatnet};
	} elsif ($data =~ /^ *([^ ]+) +([^ ]+) *$/) {
		# chatnet, channel given
		$chatnet = lc $1;
		$channel = lc $2;
	}
	do_ignore $chatnet, $channel, "off";
	write_database;
	shownotice("No longer ignoring $chatnet $channel");
}

Irssi::command_bind('stignore off', 'cmd_stignore_off');

=head3 cmd_stignore_list

Show the channels being ignored

=over

=item *
param string $data - data string from command line

=item *
param object $server - current server object

=item *
param object $witem - current window object

=back

=cut

sub cmd_stignore_list {
	my ($data, $server, $witem) = @_;
	shownotice("Ignores list");
	foreach my $chatnet (keys %ignores) {
		shownotice("$chatnet :");
		foreach my $channel (keys %{$ignores{$chatnet}}) {
			my $status = $ignores{$chatnet}{$channel} eq "on" ? "on" : "off";
			shownotice("  $channel : $status");
		}
	}
	
}

Irssi::command_bind('stignore list', 'cmd_stignore_list');

=head3 cmd_save

Save the database

=cut

sub cmd_save {
	my ($data, $server, $witem) = @_;
	write_database;
}

Irssi::command_bind('stsave', 'cmd_save');


=head3 cmd_ststatus

Give a current status of everything.

=cut

sub cmd_ststatus {
	cmd_stlisten_list(@_);
	cmd_stuser_list(@_);
	cmd_stfilter_list(@_);
	cmd_stignore_list(@_);
}

Irssi::command_bind('ststatus', 'cmd_ststatus');

=head3 cmd_debug

Turn debugging on or off

B<Usage:> /stdebug [on|off]

C<on> - turn on debugging

C<off> - turn off debugging

I<omitted> - show current debugging status

=cut

sub cmd_debug {
	my ($data, $server, $witem) = @_;
	if ($data =~ /\bon\b/i) {
		$debug = 1;
	} elsif ($data =~ /\boff\b/i) {
		$debug = 0;
	} elsif ($data =~ /^\s*$/) {
		#$debug = $debug ? 0 : 1; # do nothing, just report current state of debug
	}
	shownotice("Debug is " . ($debug ? "on" : "off") );
}

Irssi::command_bind('stdebug', 'cmd_debug');


read_database;

Irssi::timeout_add(60*60*1000, sub {write_database}, undef);

cmd_ststatus();


shownotice("$IRSSI{name} $VERSION loaded");
