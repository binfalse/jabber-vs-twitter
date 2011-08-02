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

my $T_CONS_KEY = "t_cons_key";
my $T_CONS_SEC = "t_cons_sec";
my $CONF_FILE = "j-vs-t.conf";
my $T_TOKEN = "t_token";
my $T_SECRET = "t_secret";
my $J_USER = "j_user";
my $J_PASS = "j_pass";
my $J_SERV = "j_serv";
my $J_AUTH_USER = "j_auth_user";
my $J_PORT = "j_port";
my $LAST_DATE = time()-6*60;
my $LAST_FRIENDS = 0;
my $LAST_MENTION = 0;
my $LAST_RETWEET = 0;
my $DEBUG = 0;
#my $DEBUG = 1;
my @DATECONV = (
	DateTime::Format::Strptime->new (pattern => "%a %b %d %T %z %Y"),
	DateTime::Format::Strptime->new (pattern => "%a %T"), # this one will be displayed in your message
	strftime("%z", localtime()),
	DateTime::Format::Strptime->new (pattern => "%s"),
);

my ($t_token, $t_secret, $t_cons_key, $t_cons_sec, $j_user, $j_pass, $j_serv, $j_auth_user, $j_port) = readConf ();

my $TWITTER = Net::Twitter->new(traits => ['API::REST', 'OAuth', 'WrapError'], consumer_key => $t_cons_key, consumer_secret => $t_cons_sec);

if ($t_token && $t_secret)
{
	$TWITTER->access_token($t_token);
	$TWITTER->access_token_secret($t_secret);
}

die "failed to auth to twitter... please provide token in config\n" unless ( $TWITTER->authorized );

my $bot = Net::Jabber::Bot->new ({server => $j_serv, port => $j_port, username => $j_user, password => $j_pass, alias => $j_user, message_function => \&messageCheck, background_function => \&updateCheck, loop_sleep_time => 40, process_timeout => 5, forums_and_responses => {}, ignore_server_messages => 1, ignore_self_messages => 1, out_messages_per_second => 20, max_message_size => 1000, max_messages_per_hour => 1000});

$bot->SendPersonalMessage($j_auth_user, "hey i'm back again!");
$bot->Start();

exit;


sub reauthTwitter
{
	$TWITTER = Net::Twitter->new(traits => ['API::REST', 'OAuth', 'WrapError'], consumer_key => $t_cons_key, consumer_secret => $t_cons_sec);
	$TWITTER->access_token($t_token);
	$TWITTER->access_token_secret($t_secret);
	sendJabber ("had to reauth twitter...") if ($DEBUG);
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
	}
	close(CF);
	return ($t_token, $t_secret, $t_cons_key, $t_cons_sec, $j_user, $j_pass, $j_serv, $j_auth_user, $j_port);
}

sub unshortURL
{
	my $url = shift;
	my $it = shift;
	$it = 0 if (!$it);
	return $url if ($it > 5);
	return "[URL failed]" if (!$url);
	my $respcode = 0;
	my $respurl = "";
	print "unshortening URL: $url" if ($DEBUG);
	open CMD, "curl -s -I '".$url."' |";
	while (<CMD>)
	{
		if (m/^HTTP\S*\s+(\d+)/)
		{
			$respcode = $1;
			next;
		}
		if (m/^Location:\s+(\S+)\s*$/)
		{
			$respurl = $1;
			if ($respurl =~ m/^\//i)
			{
				my $tmp = $url;
				$tmp =~ s/^(\S+:\/\/[^\/]+)\/.*$/$1/;
				$respurl = $tmp.$respurl;
			}
			next;
		}
	}
	close CMD;
	print " -> unshortened URL: $respurl ($respcode)" if ($DEBUG);

	if (($respcode == 301 || $respcode == 302) && $respurl)
	{
		return unshortURL ($respurl, $it + 1);
	}
	else
	{
		return $url;
	}
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
	my $date = shift;
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
			$by = "by *".$by."*, ";
		}
	}
	else
	{
		$by = "";
	}
	#replace shortened URLs
	$msg =~ s/\s+(http:\/\/[a-zA-Z0-9]+\.[a-zA-Z]+\/[a-zA-Z0-9]+)([.,!?;:]?)(\s+|$)/" ".unshortURL ($1)." ".specChar ($2)/eg;
	return "*" . $sender . $reply . "*" . ": ".$msg." [".$by.dateconv($date)."]";
}

sub updateCheck
{
	# check for new messages
	my $bot= shift;
	my $counter = shift;
	print "background " if ($DEBUG);

	# timeline ...
	my $tweets = $TWITTER->friends_timeline({count => 7});
	while (!defined($tweets))
	{
		reauthTwitter ();
		print "undef " if ($DEBUG);
		$tweets = $TWITTER->friends_timeline({count => 7});
		sleep 5;
	}
	print "got tweets " if ($DEBUG);
	my $new_date = $LAST_DATE;
	foreach my $hash_ref (@$tweets)
	{
		if ($LAST_DATE < u_time($hash_ref->{'created_at'}))
		{
			sendJabber (processMessage ($hash_ref->{'user'}->{'screen_name'}, $hash_ref->{'text'}, $hash_ref->{'created_at'}));
			$new_date = u_time($hash_ref->{'created_at'}) if ($new_date < u_time($hash_ref->{'created_at'}));
			print "." if ($DEBUG);
		}
	}

	# mentions ...
	$tweets = $TWITTER->mentions({count => 7});
	while (!$tweets)
	{
		reauthTwitter ();
		print "undef " if ($DEBUG);
		$tweets = $TWITTER->mentions({count => 7});
		sleep 5;
	}
	print "got replies " if ($DEBUG);
	foreach my $hash_ref (@$tweets)
	{
		if ($LAST_DATE < u_time($hash_ref->{'created_at'}))
		{
			sendJabber (processMessage ($hash_ref->{'user'}->{'screen_name'}, $hash_ref->{'text'}, $hash_ref->{'created_at'}, "->reply<-"));
			$new_date = u_time($hash_ref->{'created_at'}) if ($new_date < u_time($hash_ref->{'created_at'}));
			print "." if ($DEBUG);
		}
	}

	# retweets ...
	$tweets = $TWITTER->retweeted_to_me({count => 7, since_id => $LAST_RETWEET});
	while (!$tweets)
	{
		reauthTwitter ();
		print "undef " if ($DEBUG);
		$tweets = $TWITTER->retweeted_to_me({count => 7, since_id => $LAST_RETWEET});
		sleep 5;
	}
	print "got retweets " if ($DEBUG);
	foreach my $hash_ref (@$tweets)
	{
		if ($LAST_DATE < u_time($hash_ref->{'created_at'}))
		{
			sendJabber (processMessage ($hash_ref->{'retweeted_status'}->{'user'}->{'screen_name'}, $hash_ref->{'retweeted_status'}->{'text'}, $hash_ref->{'retweeted_status'}->{'created_at'}, $hash_ref->{'user'}->{'screen_name'}));
			$new_date = u_time($hash_ref->{'created_at'}) if ($new_date < u_time($hash_ref->{'created_at'}));
			print "." if ($DEBUG);
			$LAST_RETWEET = $hash_ref->{'id'} if ($hash_ref->{'id'} > $LAST_RETWEET);
		}
	}
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
				sendJabber ("avaiable commands (commands begin with !):");
				sendJabber ("!help - print this help message");
				sendJabber ("!follow [USER] - follow the user USER");
				sendJabber ("!unfollow [USER] - stop following the user USER");
				sendJabber ("!profile [USER] - print the profile of USER");
				sendJabber ("!following - list the users you are following");
				sendJabber ("!followers - list the users that follow you");
				sendJabber ("all messages that doesn't start with ! are understood as status update");
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
					sendJabber ("failed");
				}
			}
			case "!following"
			{
				my $ret = $TWITTER->friends();
				my @hash = @$ret;
				my $out = "you are following: ";
				foreach my $k (@hash )
				{
					$out .= "$k->{screen_name} ";
				}
				sendJabber ($out);
			}
			case "!followers"
			{
				my $ret = $TWITTER->followers();
				my @hash = @$ret;
				my $out = "your followers: ";
				foreach my $k (@hash )
				{
					$out .= "$k->{screen_name} ";
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
		sendJabber ("you tried to send 0 characters, thats no status brother...");
		return;
	}
	
	print "try to tweet\n" if ($DEBUG);
	
	if ($TWITTER->update({ status => $status }))
	{
		sendJabber ("updated your status");
	}
	else
	{
		sendJabber ("failed to update your status");
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
