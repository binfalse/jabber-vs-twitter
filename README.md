# Jabber -vs- Twitter

Perl script sending you news from Twitter to your Jabber account and sending
status updates from Jabber to Twitter. It's free, open source and not too hard to use!
The actual homepage can be found here at [my website](http://binfalse.de/software/jabber-vs-twitter/)


##  COPYRIGHT AND LICENCE

    Copyright (C) 2011-2014 Martin Scharm

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <http://www.gnu.org/licenses/>.

##  DEPENDENCIES

So far, exclusively developed and tested on a Linux. I do not expect it to work on win servers,
but feel free to give it a try and please report issues.

The following Perl modules should be installed:

* Net::Jabber::Bot;
* Net::Twitter;
* Date::Parse;
* HTML::Entities;
* DateTime::Format::Strptime;
* Data::Dumper;
* Switch;
* URI::Find;

Debian based? Copy the following line:

    aptitude install libnet-jabber-bot-perl libnet-twitter-perl libtimedate-perl libdatetime-format-dateparse-perl libdatetime-format-strptime-perl libhtml-html5-entities-perl libhtml-entities-numbered-perl libdata-dump-perl libswitch-perl liburi-find-perl

Example for installing `Net::Jabber::Bot` using cpan shell:

    perl -MCPAN -e shell
    cpan[1]> install  Net::Jabber::Bot


##  CONFIGURATION

All configuration stuff is located in `j-vs-t.conf`.

1. Create Jabber accounts for you (if you do not have one already) and the bot. Some popular servers can be found at [jabberes.org/servers](http://www.jabberes.org/servers/) or [xmpp.net/directory.php](https://xmpp.net/directory.php).
2. Set up a Twtitter account at [twitter.com](http://twitter.com)
3. Fill in your Jabber credentials and serversettings in `j-vs-t.conf`
4. Create a new Twitter App at [dev.twitter.com/apps](https://dev.twitter.com/apps)
5. Provide your *application settings* and *access tokens* in `j-vs-t.conf`:


        t_token = Access token
        t_secret = Access token secret
        t_cons_key = API key
        t_cons_sec = API secret


##  USAGE

Just run the script with

perl -w j-vs-t.pl

While the tool is running it sends the status updates in your Twitter home time line as 
messages to the authorized Jabber account. Replies are also sent seperatedly.

Each message that arrives from the authorized user to the Jabber account of the
bot will be sent to Twitter as status update. But keep in mind
to stay shorter than 140 chars.

In addition you can send some special commands to the bot. Command always start with an
exclamation mark (`!`). And each message starting with `!` is interpreted as a command.
The following commands are available:

	!help
	list available commands
	
	!follow [USER]
	follow the user USER
	
	!unfollow [USER]
	stop following the user USER
	
	!profile [USER]
	print the profile of USER
	
	!following
	list users you are following
	
	!followers
	list users who follow you
	
	!retweet [ID]
	retweet message with id ID (last number in jabber message)
	
	!favorite [ID]
	favorite message with id ID (last number in jabber message)


##  BUGS

Bugs and feature requested are listed here: http://bt.binfalse.de

##  MORE INFO

More information can be found at

[binfalse.de/software/jabber-vs-twitter](http://binfalse.de/software/jabber-vs-twitter/)
