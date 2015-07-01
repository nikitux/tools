#!/usr/bin/perl
# ---------------------------------------------------------------------------
# warranty_details - Get status of warranty
#
# Copyright 2015,  <nikitux@gmail.com>  & <federico.moya@surhive.com>
#
# Thanks to fede moya who was the guy that did the hard work.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.
#
# Revision history:
# Tested with Dell Servers
# ---------------------------------------------------------------------------

VERSION="1.0"



$ENV{'PATH'} = '/bin:/usr/bin';

use strict;
use warnings;

use DateTime::Format::Epoch;
use JSON;
use Getopt::Long;

use constant DEBUG => 0;

use constant BASE_URL => "http://www.lookupwarranty.com/updatewarranty/server/lookup?";

my $args;

GetOptions ("argument=s@" => \$args);

foreach my $arg (@{$args}) {
    
    my @splitted_arg = split(",", $arg);

    my $serviceTag = $splitted_arg[0];
    my $model = $splitted_arg[1];

    my $params = join ( "&",
        "time=" . time(),
        "serviceTag=$serviceTag",
        "modelNumber",
        "mfg=dell",
        "email=",
        "platform=Website",
        "databaseSize=1",
        "key"
    );

    my $url = BASE_URL . $params;

    my $response = http_request($url);

    if ($response->{error}) {
        print("ERROR for serviceTag $serviceTag: $response->{error}\n");
        print "----------------------------\n";
        next;
    }

    my $shipped = $response->{shipped};
    my $expires = $response->{expires};
  
    my $epoch = DateTime->new( year => 1970, month => 1, day => 1 );
    my $formatter = DateTime::Format::Epoch->new(
                      epoch          => $epoch,
                      unit           => 'milliseconds',
                      type           => 'int',    # or 'float', 'bigint'
                      skip_leap_seconds => 1,
                      start_at       => 0,
                      local_epoch    => undef,
                  );

    my $dt_shipped = $formatter->parse_datetime($shipped);
    my $dt_expires = $formatter->parse_datetime($expires);

    print "Model: $model\n";
    print "serviceTag: $serviceTag\n";
    print "shipped: " . join("-", $dt_shipped->dmy('/')) . "\n";
    print "expires: " . join("-", $dt_expires->dmy('/')) . "\n";
    print "----------------------------\n"

}


####################################################

sub http_request {
    my ($url) = @_;

    my $curl_opt = join ( " ",
        '-H "Pragma: no-cache"',
        '-H "Accept-Encoding: gzip, deflate, sdch"',
        '-H "Accept-Language: en-US,en;q=0.8"',
        '-H "Accept: application/json, text/javascript, */*; q=0.01"',
        '-H "Referer: http://www.lookupwarranty.com/"',
        '-H "X-Requested-With: XMLHttpRequest"',
        '-H "Connection: keep-alive"',
        '-H "Cache-Control: no-cache"',
        "--compressed",
        "--silent --show-error --max-time 10 --dump-header -"
    );

    my $cmd_out = `curl $curl_opt \"$url\" 2>&1`;

    my ($http_status, $status_str) = $cmd_out =~ m|^HTTP/1\.\d (\d{3}) (.*?)\r\n|s;

    unless ($http_status) {
         # Connection error (couldn't connect to host, etc)
         return { error => $cmd_out };
    }

    unless ($http_status eq '200') {
         # Backend error (404 not found, etc)
         return { error => "$http_status $status_str" };
    }

    my ($headers, $body) = split("\r\n\r\n", $cmd_out, 2);

    DEBUG && print "\nResponse: $body\n";

    my $response = eval { decode_json( $body ) };

    unless (defined $response) {
         return { error => "Server response is not valid JSON" };
    }

    return $response;    
}
