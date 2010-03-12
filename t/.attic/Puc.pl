#!/usr/bin/perl

use lib "./";
use Device::Opto22;
use Data::Dumper;

$brain_ip = '157.187.162.26';

my $sock  = new Device::Opto22( PeerAddr => "$brain_ip",PeerPort => '2001' );

my $rtn = $sock->send_PUC();

print $rtn,"\n"; 

$rtn = $sock->error_msg();

print $rtn,"\n";

#$rtn = $sock->send_MMap_ver();
#print $rtn,"\n"; 
#ok ( $rtn );


