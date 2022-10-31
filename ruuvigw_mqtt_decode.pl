#!/usr/bin/perl -w -CSDA

use utf8;
use strict;
use warnings;
$SIG{HUP}  = \&signal_handler_hup;
$SIG{INT}  = \&signal_handler_term;
$SIG{TERM} = \&signal_handler_term;
use Getopt::Long qw(GetOptions);

# Install extra modules
use Net::MQTT::Simple;
use JSON::PP qw(decode_json encode_json);
use Async::Event::Interval;

GetOptions(
    "debug"		=> \my $debug,
    "config:s"	=> \(my $config = "config.txt"),
    "tags:s"		=> \(my $tags = "known_tags.txt"),
) or die "Options missing $!";

# Load known comfig from file
open(INFILE, "<:encoding(UTF-8)", $config ) or die "Could not open ${config} $!";
my %config;
while (<INFILE>) {
	chomp $_;
	my($key, $data) = split(/\t/, $_);
	$config{$key} = $data;
}

# Load known tags from file
open(INFILE, "<:encoding(UTF-8)", $tags) or die "Could not open ${tags} $!";
my %tags;
while (<INFILE>) {
	chomp $_;
	my($mac, $name) = split(/\t/, $_);
	$tags{$mac} = $name;
}

# Initialize MQTT publish handler
my $event = Async::Event::Interval->new(
    20,						# number of seconds between execs
    \&publish_mqtt_buffer,	# code reference, or anonymous sub
    'test'					# parameters to the callback
);
$event->start;

# Initialize MQTT subscriptions and run for ever.
$ENV{MQTT_SIMPLE_ALLOW_INSECURE_LOGIN} = 1;
my $mqtt = Net::MQTT::Simple->new($config{"mqtthost"});
$mqtt->login($config{"username"}, $config{"password"});
$mqtt->subscribe($config{"sub_topic"}, \&handle_mqtt_message);
$mqtt->run;

# Handler to received MQTT messages
sub handle_mqtt_message {
	my ($topic, $message) = @_;
	utf8::encode($topic);
	my ($prefix, $ruuvigw_mac, $ruuvi_mac) = split ('/', $topic);
	my ($tag_name, $tag_data);

	my ($message_hash) = decode_json $message;
	my ($ble_mac) = lc($ruuvi_mac);
	my ($ble_rssi) = abs($message_hash->{rssi});
	my ($ble_adv_data) = $message_hash->{data};
	#print "Found $topic with RSSI = $ble_rssi.\n" if $debug;

	if (exists($tags{$ble_mac})) {
		$tag_name = $tags{$ble_mac};
		if($ble_adv_data =~ /^020106/) { # ADV Data start with 020106 for Manufacturer Advertised Data
			my $ble_len = hex(substr($ble_adv_data,6, 2));
			my $ble_type = "0x" . substr($ble_adv_data,8, 2);

			if ($ble_type =~ /0xFF/) {
				my $ble_manufacturer = "0x" . substr($ble_adv_data, 12, 2) . substr($ble_adv_data,10, 2);
				my $ble_data = substr($ble_adv_data, 14);
									
				# RuuviTags
				if ($ble_manufacturer =~ /^0x0499/) {
					my $tag_type = 1;
					my @raw_data = unpack("C c C16 H*", pack ("H*", $ble_data));
					# c = signed char (8 bits)
					# C = unsigned signed char (8 bits)
					# s = signed short (16 bits)
					# S = unsigned signed short (16 bits)
					# H = hex
					#    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 18-23
					# 0x05109C2F38C325FFF400080424ADB68992FB ECEE9687CEFC
					my $temperature = (($raw_data[1] * 256 + $raw_data[2])) * 0.05;
					my $humidity    = (($raw_data[3] * 256 + $raw_data[4])) * 0.0025;
					my $pressure   = ((($raw_data[5] * 256 + $raw_data[6])) + 50000) / 100;
					my $voltage     = (($raw_data[13] * 256 + $raw_data[14])) / 32 + 1600;
					$tag_data = sprintf("{\"type\":%d,\"t\":%d,\"rh\":%d,\"bu\":%d,\"ap\":%d,\"s\":%d}", $tag_type, $temperature, $humidity, $voltage, $pressure, $ble_rssi);
				} else {
					print "Unknown: mac = $ble_mac, rssi = $ble_rssi, len = $ble_len, type = $ble_type, manu = $ble_manufacturer, data = $ble_data\n" if $debug;
				}
			} elsif ($ble_type =~ /0x03/) {
				my $ble_service = "0x" . substr($ble_adv_data, 12, 2) . substr($ble_adv_data,10, 2);
				my $ble_data = "0x" . substr($ble_adv_data, 14);
				if ($ble_data =~ /0x09FF/) { # Most likely a IFind beacon tag
					print "iFind:   mac = $ble_mac, rssi = $ble_rssi, len = $ble_len, type = $ble_type, serv = $ble_service, data = $ble_data\n" if $debug;
				} else {
					print "Unknown: mac = $ble_mac, rssi = $ble_rssi, len = $ble_len, type = $ble_type, manu = $ble_service, data = $ble_data\n" if $debug;
				}
			} else {
				print "Unknown: mac = $ble_mac, rssi = $ble_rssi, len = $ble_len, type = $ble_type, data = $ble_adv_data\n" if $debug;
			}
		}
		my $pub_topic = $config{"pub_topic"} . "/" . $tag_name;
		printf ("%s %s\n", $pub_topic, $tag_data) if $debug;
		#$mqtt->publish($pub_topic => $tag_data);
		#warn Dumper($_);
	} else {
		print "Skipped\t$ble_mac\n" if $debug;
	}			
}

# Called periodically to publish current data
sub publish_mqtt_buffer {
	#$mqtt->publish($pub_topic => $tag_data);
	print "\n* * * *\n\nHeartbeat Interval $!\nWe should send collected data and flush the buffer.\n\n* * * *\n\n" if $debug;
	$event->restart if $event->error;
}

sub signal_handler_hup {
	$mqtt->disconnect();
	print "HUP on signal $!\n" if $debug;
}

sub signal_handler_term {
	$mqtt->disconnect();
	print "Exit on signal $!\n" if $debug;
	exit();
}

