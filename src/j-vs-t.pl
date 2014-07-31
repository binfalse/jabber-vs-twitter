#!/usr/bin/perl -w

###################################
#
#    j-vs-t - Jabber -vs- Twitter
#
#     written by Martin Scharm
#       see http://binfalse.de
#
###################################

use warnings;
use strict;

use Net::Jabber::Bot;
use Net::Twitter;
use Date::Parse;
use HTML::Entities;
use Switch;
use DateTime::Format::Strptime;
use POSIX;
use Data::Dumper;
use URI::Find;

my $CONF_FILE = "j-vs-t.conf";
my $T_CONS_KEY = "t_cons_key";
my $T_CONS_SEC = "t_cons_sec";
my $T_TOKEN = "t_token";
my $T_SECRET = "t_secret";
my $J_USER = "j_user";
my $J_PASS = "j_pass";
my $J_SERV = "j_serv";
my $J_AUTH_USER = "j_auth_user";
my $J_PORT = "j_port";
my $A_NUMRETRIEVE = "a_num_tweets";
my $A_DEBUG = "a_debug";
my $A_UPDATE_TIME = "a_update_time";

my $LAST_DATE = time()-60*60;
my $LAST_FRIENDS = 0;
my $LAST_MENTION = 0;
my $LAST_RETWEET = 0;


my @DATECONV = (
    DateTime::Format::Strptime->new (pattern => "%a %b %d %T %z %Y"),
    DateTime::Format::Strptime->new (pattern => "%a %T"), # this one will be displayed in your message
    strftime("%z", localtime()),
    DateTime::Format::Strptime->new (pattern => "%s"),
);

my ($t_token, $t_secret, $t_cons_key, $t_cons_sec, $j_user, $j_pass, $j_serv, $j_auth_user, $j_port, $update_time, $NUMRETRIEVE, $DEBUG) = readConf ();

$NUMRETRIEVE = 10 if (!$NUMRETRIEVE);
$DEBUG = 0 if (!$DEBUG);
$update_time = 60 if (!$update_time);

my $TWITTER = Net::Twitter->new(traits => [ qw/API::RESTv1_1 RetryOnError OAuth WrapError/ ], consumer_key => $t_cons_key, consumer_secret => $t_cons_sec, ssl => 1);

if ($t_token && $t_secret)
{
    $TWITTER->access_token($t_token);
    $TWITTER->access_token_secret($t_secret);
}

unless ( $TWITTER->authorized )
{
    # The client is not yet authorized: Do it now
    print "Authorize this app at ", $TWITTER->get_authorization_url, " and enter the PIN#\n";

    my $pin = <STDIN>; # wait for input
    chomp $pin;

    my($access_token, $access_token_secret, $user_id, $screen_name) = $TWITTER->request_access_token(verifier => $pin);
    print "==== YOUR CREDENTIALS ====\n";
    print "t_token = $access_token\nt_secret = $access_token_secret\n";
    print "\n\nplease store them in $CONF_FILE";
    print "\nshould i do that for you? (Y/n): ";
    $pin = <STDIN>;
    if ($pin =~ m/^\s*y/i)
    {
        open CF, '>>'.$CONF_FILE or die "cannot write $CONF_FILE";
        print CF "t_token = $access_token\nt_secret = $access_token_secret\n";
        close CF;
    }
    else
    {
        exit;
    }
}

die "failed to auth to twitter... please provide token in config\n" unless ( $TWITTER->authorized );

my $bot = Net::Jabber::Bot->new ({server => $j_serv, port => $j_port, username => $j_user, password => $j_pass, alias => $j_user, message_function => \&messageCheck, background_function => \&updateCheck, loop_sleep_time => $update_time, process_timeout => 5, forums_and_responses => {}, ignore_server_messages => 1, ignore_self_messages => 1, out_messages_per_second => 20, max_message_size => 1000, max_messages_per_hour => 1000});

$bot->SendPersonalMessage($j_auth_user, "hey i'm back again!");
$bot->Start();

exit;


sub reauthTwitter
{
	$TWITTER = Net::Twitter->new(traits => [ qw/API::RESTv1_1 RetryOnError OAuth WrapError/ ], consumer_key => $t_cons_key, consumer_secret => $t_cons_sec, ssl => 1);
	$TWITTER->access_token($t_token);
	$TWITTER->access_token_secret($t_secret);
	sendJabber ("had to reauth twitter...") if ($DEBUG);
	
	my $err = $TWITTER->get_error;
	if ($err or !$TWITTER->authorized)
	{
		print "ERROR reauthing:";
		print Dumper $err;
		sendJabber ("reauthing failed... ".$TWITTER->http_message) if ($DEBUG);
	}
	
	
	return $TWITTER;
}


sub readConf
{
	# read the config
	my $file = $CONF_FILE;
	my $t_token = undef;
	my $t_secret = undef;
	my $t_cons_key = undef;
	my $t_cons_sec = undef;
	my $j_user = undef;
	my $j_pass = undef;
	my $j_serv = undef;
	my $j_auth_user = undef;
	my $j_port = undef;
	my $update_time = undef;
	my $NUMRETRIEVE = undef;
	my $DEBUG = undef;

	open(CF,'<'.$file) or return ("", "");

	while (my $line = <CF>)
	{
		next if($line =~ /^\s*#/);
		next if($line !~ /^\s*\S+\s*=.*$/);

		my ($key,$value) = split(/=/,$line,2);

		$key   =~ s/^\s+//g;
		$key   =~ s/\s+$//g;
		$value =~ s/^\s+//g;
		$value =~ s/\s+$//g;

		$t_token = $value if ($key eq $T_TOKEN);
		$t_secret = $value if ($key eq $T_SECRET);
		$t_cons_key = $value if ($key eq $T_CONS_KEY);
		$t_cons_sec = $value if ($key eq $T_CONS_SEC);
		
		$j_user = $value if ($key eq $J_USER);
		$j_pass = $value if ($key eq $J_PASS);
		$j_serv = $value if ($key eq $J_SERV);
		$j_auth_user = $value if ($key eq $J_AUTH_USER);
		$j_port = $value if ($key eq $J_PORT);
		
		$NUMRETRIEVE = $value if ($key eq $A_NUMRETRIEVE);
		$DEBUG = $value if ($key eq $A_DEBUG);
		$update_time = $value if ($key eq $A_UPDATE_TIME);
	}
	close(CF);
	return ($t_token, $t_secret, $t_cons_key, $t_cons_sec, $j_user, $j_pass, $j_serv, $j_auth_user, $j_port, $update_time, $NUMRETRIEVE, $DEBUG);
}

sub unshortURL
{
	my $url = shift;
	return "[URL failed]" if (!$url);
	print "unshortening URL: $url" if ($DEBUG);
	open CMD, "curl -sIL '".$url."' 2>&1 | ";
	while (<CMD>)
	{
		my $line = $_;
		print "---> ".$line if ($DEBUG);
		if ($line =~ m/^location: (.*)$/i)
		{
			my $tmp = $1;
 			$tmp =~ s/[^[:print:]]+//g;
			
			if ($tmp =~ m/^http/i)
			{
				$url = $tmp;
			}
			else
			{
				$url = $url.$tmp;
			}
			print  "---URL> ".$url."\n" if ($DEBUG);
		}
 	}
	close CMD;
	print " -> unshortened URL: $url\n" if ($DEBUG);
	return $url;
}

sub specChar
{
	my $char = shift;
	return $char." " if ($char);
	return "";
}

sub processMessage
{
	my $sender = shift;
	my $msg = decode_entities (shift);
	chomp ($msg);
	$msg =~ s/[^[:print:]]+//g;
	my $date = shift;
	my $id = shift;
	my $place = shift;
	my $by = shift;
	my $reply = "";
	if ($by)
	{
		if ($by eq "->reply<-")
		{
			$by = "";
			$reply = " replied";
		}
		else
		{
			$by = " retweeted *".$by."* ";
		}
	}
	else
	{
		$by = "";
	}
	#replace shortened URLs
	my $finalmsg = $msg;
	my $finder = URI::Find->new(sub {
		my($uri) = shift;
    my $url = unshortURL ($uri);
		print "expanded uri $uri to $url in ".$finalmsg . "\n\n" if ($DEBUG);
		$finalmsg =~ s/$uri/$url/g if ($url);
  });
  $finder->find(\$msg);
	
	if ($place)
	{
		$place = " - $place";
	}
	else
	{
		$place = "";
	}
	
	print "\n\n--FINAL MESSAGE:--".$finalmsg . "----\n\n" if ($DEBUG);
	return "*" . $sender . $reply . "*"  . $by. ": ".$finalmsg." [".dateconv($date)."$place - $id]";
}

sub updateCheck
{
	# check for new messages
	my $bot= shift;
	my $counter = shift;
	print "background ".`date "+\%c"`."\n" if ($DEBUG);

	# timeline ...
	my $tweets = $TWITTER->home_timeline({count => $NUMRETRIEVE});
	while (!defined($tweets))
	{
		sendJabber ("error getting home timeline: ".$TWITTER->http_message);
		print "error getting home timeline: ";
		print Dumper $TWITTER->get_error;
		$TWITTER = reauthTwitter ();
#		print "undef " if ($DEBUG);
		$tweets = $TWITTER->home_timeline({count => $NUMRETRIEVE});
		sleep 15;
	}
	print "got tweets\n" if ($DEBUG);
	my $new_date = $LAST_DATE;
	foreach my $hash_ref (@$tweets)
	{
		if ($LAST_DATE < u_time($hash_ref->{'created_at'}))
		{
			#print Dumper $hash_ref;
			
			if ($hash_ref->{'retweeted_status'})
			{
				sendJabber (processMessage ($hash_ref->{'user'}->{'screen_name'}, $hash_ref->{'retweeted_status'}->{'text'}, $hash_ref->{'created_at'}, $hash_ref->{'id'}, $hash_ref->{'place'}->{'full_name'}, $hash_ref->{'retweeted_status'}->{'user'}->{'screen_name'}));
			}
			else
			{
				sendJabber (processMessage ($hash_ref->{'user'}->{'screen_name'}, $hash_ref->{'text'}, $hash_ref->{'created_at'}, $hash_ref->{'id'}, $hash_ref->{'place'}->{'full_name'}));
			}
			$new_date = u_time($hash_ref->{'created_at'}) if ($new_date < u_time($hash_ref->{'created_at'}));
			print "." if ($DEBUG);
		}
	}
	print "tweets done\n" if ($DEBUG);

	# mentions ...
	$tweets = $TWITTER->mentions({count => $NUMRETRIEVE});
	while (!$tweets)
	{
		sendJabber ("error getting mentions: ".$TWITTER->http_message);
		print "error getting home timeline: ";
		print Dumper $TWITTER->get_error;
		$TWITTER = reauthTwitter ();
#		print "undef " if ($DEBUG);
		$tweets = $TWITTER->mentions({count => $NUMRETRIEVE});
		sleep 15;
	}
	print "got replies \n" if ($DEBUG);
	foreach my $hash_ref (@$tweets)
	{
		if ($LAST_DATE < u_time($hash_ref->{'created_at'}))
		{
			sendJabber (processMessage ($hash_ref->{'user'}->{'screen_name'}, $hash_ref->{'text'}, $hash_ref->{'created_at'}, $hash_ref->{'id'}, $hash_ref->{'place'}->{'full_name'}, "->reply<-"));
			$new_date = u_time($hash_ref->{'created_at'}) if ($new_date < u_time($hash_ref->{'created_at'}));
			print "." if ($DEBUG);
		}
	}
	print "mentions done\n" if ($DEBUG);
	
	
	print " done\n" if ($DEBUG);
	$LAST_DATE = $new_date;
}

sub messageCheck
{
	print "new msg arrived\n" if ($DEBUG);
	my %bot_message_hash = @_;
	
	$bot_message_hash{'sender'} = $bot_message_hash{'from_full'};
	$bot_message_hash{'sender'} =~ s{^(.+)\/.*$}{$1};
	
	# only the allowed user is able to speak to me
	return if ($bot_message_hash{'sender'} ne $j_auth_user);
	
	if ($bot_message_hash{body} =~ m/^!/)
	{
		# the user sends a command
		my($command, @options) = split(' ', $bot_message_hash{body});
		switch ($command)
		{
			case "!help"
			{
				sendJabber ("avaiable commands (commands start with !):");
				sendJabber ("!help - print this help message");
				sendJabber ("!break - set a break mark");
				sendJabber ("!follow [USER] - follow the user USER");
				sendJabber ("!unfollow [USER] - stop following the user USER");
				sendJabber ("!profile [USER] - print the profile of USER");
				sendJabber ("!following - list users you are following");
				sendJabber ("!followers - list users who follow you");
				sendJabber ("!retweet [ID] - retweet message with id ID (last number in jabber message)");
				sendJabber ("!favorite [ID] - favorites message with id ID (last number in jabber message)");
				sendJabber ("!delete [ID] - delete message with id ID (last number in jabber message, must be your message)");
				sendJabber ("all messages that do not start with an ! are interpreted as status update");
			}
			case "!retweet"
			{
				my $toretweet = $options[0];
				my $ret = $TWITTER->retweet($toretweet);
				if ($ret->{'id'})
				{
					sendJabber ("successfully retweeted!");
				}
				else
				{
					sendJabber ("retweeting failed... ".$TWITTER->http_message);
				}
			}
			case "!favorite"
			{
				my $tofav = $options[0];
				my $ret = $TWITTER->create_favorite($tofav);
				if ($ret->{'id'})
				{
					sendJabber ("successfully favorited!");
				}
				else
				{
					sendJabber ("favoriting failed... ".$TWITTER->http_message);
				}
			}
			case "!delete"
			{
				my $torm = $options[0];
				my $ret = $TWITTER->destroy_status($torm);
				if ($ret->{'id'})
				{
					sendJabber ("successfully deleted!");
				}
				else
				{
					sendJabber ("deletion failed... ".$TWITTER->http_message);
				}
			}
			case "!break"
			{
				sendJabber ("--= *BREAK* =--");
			}
			case "!follow"
			{
				my $tofollow = $options[0];
				my $ret = $TWITTER->create_friend({ screen_name => $tofollow});
				if ($ret->{'screen_name'} eq $tofollow)
				{
					sendJabber ("you are now following " . $ret->{'screen_name'});
				}
				else
				{
					sendJabber ("failed to follow $tofollow: $ret");
				}
			}
			case "!unfollow"
			{
				my $tounfollow = $options[0];
				my $ret = $TWITTER->destroy_friend({ screen_name => $tounfollow});
				if ($ret->{'screen_name'} eq $tounfollow)
				{
					sendJabber ("you stopped following " . $ret->{'screen_name'});
				}
				else
				{
					sendJabber ("failed to unfollow $tounfollow: $ret");
				}
			}
			case "!profile"
			{
				my $user = $options[0];
				my $ret = $TWITTER->show_user({ screen_name => $user});
				if (ref $ret)
				{
					sendJabber ("name: $ret->{'name'}");
					sendJabber ("screen_name: $ret->{'screen_name'}");
					sendJabber ("id: $ret->{'id'}");
					sendJabber ("url: $ret->{'url'}") if ($ret->{'url'});
					sendJabber ("language: $ret->{'lang'}") if ($ret->{'lang'});
					sendJabber ("created: " . dateconv ($ret->{'created_at'}) . "");
					sendJabber ("tweets: $ret->{'statuses_count'}");
					sendJabber ("following: $ret->{'friends_count'}");
					sendJabber ("followers: $ret->{'followers_count'}");
					sendJabber ("description: $ret->{'description'}") if ($ret->{'description'});
					sendJabber ("favourites: $ret->{'favourites_count'}");
					sendJabber ("last status: $ret->{'status'}->{'text'} [" . dateconv ($ret->{'status'}->{'created_at'}) . "]") if ($ret->{'status'}->{'text'});
				}
				else
				{
					sendJabber ("failed... " . $TWITTER->http_message);
				}
			}
			case "!following"
			{
				my $out = "*you are following:* ";
				
				my $page = 1;
				for ( my $cursor = -1, my $ret; $cursor; $cursor = $ret->{next_cursor} )
				{
					$ret = $TWITTER->friends({ cursor => $cursor });
					my $users = $ret->{users};
					foreach my $k (@$users)
					{
						$out .= "$k->{screen_name} ";
					}
					if ($page++ == 9)
					{
						$out .= " *[etc]*";
						last;
					}
				}
				sendJabber ($out);
			}
			case "!followers"
			{
				my $out = "*your followers:* ";
				
				my $page = 1;
				for ( my $cursor = -1, my $ret; $cursor; $cursor = $ret->{next_cursor} )
				{
					$ret = $TWITTER->followers({ cursor => $cursor });
					my $users = $ret->{users};
					foreach my $k (@$users)
					{
						$out .= "$k->{screen_name} ";
					}
					if ($page++ == 9)
					{
						$out .= " *[etc]*";
						last;
					}
				}
				sendJabber ($out);
				
				
				
			}
			else
			{
				sendJabber ("what do you mean? try !help");
			}
		}
	}
	else
	{
		print "try to call twitter\n" if ($DEBUG);
		tweet ($bot_message_hash{body});
	}
}

sub tweet
{
	# tweet the msg
	print "try to tweet\n" if ($DEBUG);
	my $status = shift;
	if (length $status > 140)
	{
		sendJabber ("you tried to send " . length ($status) . " characters, but only 140 are allowed...");
		sendJabber ("your message was: " . $status);
		return;
	}
	if (length $status < 1)
	{
		sendJabber ("you tried to send 0 characters, thats not a valid status...");
		return;
	}
	
	print "try to tweet\n" if ($DEBUG);
	
	if ($TWITTER->update({ status => $status }))
	{
		sendJabber ("updated your status");
	}
	else
	{
		sendJabber ("failed to update your status... " . $TWITTER->http_message);
		sendJabber ("your message was: " . $status);
		return;
	}
}

sub sendJabber
{
	# send a message to the authorized user
	$bot->SendPersonalMessage($j_auth_user, shift);
}

sub dateconv
{
	return $DATECONV[1]->format_datetime($DATECONV[0]->parse_datetime(shift)->set_time_zone($DATECONV[2]));
}
sub u_time
{
	return $DATECONV[3]->format_datetime($DATECONV[0]->parse_datetime(shift)->set_time_zone($DATECONV[2]));
}
