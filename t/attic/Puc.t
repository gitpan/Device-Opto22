#!/usr/bin/perl

use Test::More tests => 1;

use Device::Opto22;
use Data::Dumper;

$brain_ip = '157.187.162.26';

my $sock  = new Device::Opto22( PeerAddr => "$brain_ip",PeerPort => '2001' );

my $rtn = $sock->send_PUC();
ok ( $rtn );

#$rtn = $sock->send_MMap_ver();
#print $rtn,"\n"; 
#ok ( $rtn );


