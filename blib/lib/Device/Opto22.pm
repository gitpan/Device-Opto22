package Device::Opto22;

use 5.008008;
use strict;
use warnings;

require Exporter;

use Device::Opto22::Firewire;

our @ISA = qw( Exporter Device::Opto22::Firewire );


# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

our @EXPORT_OK = qw( send_PUC get_scratchpadint get_scratchpadfloat get_eu_lst get_digital_lst wr_digital_pnt serial_chat );

our @EXPORT = qw( );

our $VERSION = '0.90';

our $error_msg; 

################################################33
# Opto22 Specific commands
################################################33

our $timeout = 10;

sub new {

    my $class = shift @_;
    my %args = @_;

    my $PeerAddr = $args{PeerAddr} ;
    my $PeerPort = $args{PeerPort} ;

    if (not ($PeerAddr && $PeerPort) )  {
          die "Inputs missing in Package $class in Method new";
    }

    # This establishes a SENDER socket connection OK
    my $root = new Device::Opto22::Firewire (PeerAddr => $PeerAddr ,
                          PeerPort => $PeerPort );

    if ( not($root))  {
	    die "Error connecting in Package $class" ;
    }
	
    bless  $root;

    return $root;
}

sub send_PUC {

  my ($class) = @_;

  my $packet = $class->bld_wr_quad_packet(0xf0380000,0x00000001);
  my $rsp    = $class->chat($packet);

  return ($rsp) ;
}

# Does not work... not sure what to send ... 
sub send_MMap_ver {

  my ($class) = @_;

  my $packet = $class->bld_wr_quad_packet(0xf0300000,0x00000000);
  my $rsp    = $class->chat($packet);

  return ($rsp) ;
}

#-------------------------------------------
# Load $len number of elements from the
# ScratchPad Integer Table of the brain's
# memory map
#-------------------------------------------
sub get_scratchpadint {

  my ($class) = shift @_;
  my ($len) = shift @_;   # how many ints to get
  
  my $packet  = $class->bld_rd_blk_packet(0xF0D81000,4*$len);

  my $data    = $class->chat($packet);

  my @lst = big2little_int($data);

  return (@lst) ;

}

#-------------------------------------------
# Load $len number of elements from the
# ScratchPad Float Table of the brain's
# memory map
#-------------------------------------------
sub get_scratchpadfloat {

  my ($class) = shift @_;
  my ($len) = shift @_;   # how many ints to get

  my $packet  = $class->bld_rd_blk_packet(0xF0D82000,4*$len);

  my $data    = $class->chat($packet);

  my @lst = big2little_fp($data);

  return (@lst) ;
}

sub get_eu_lst {

  my ($class) = @_;

  my $packet  = $class->bld_rd_blk_packet(0xf0600000,256);

  my $data    = $class->chat($packet);

  my @lst = big2little_fp($data);

  return (@lst) ;
}

sub get_digital_lst {

  my ($class) = @_;

  my $packet  = $class->bld_rd_blk_packet(0xf0400000,8);

  my $data    = $class->chat($packet);

  # Place 0 or 1 in each element of an array
  my @lst = split // , unpack  "B64" , $data ;

  @lst = reverse @lst ;  # Ain't Perl cool

  return @lst ;
}

sub wr_digital_pnt {

  my ($class) = shift @_;

  my ($channel, $data) = @_;

  # Note: channel is zero based
  my $offset = $channel * 64 ;

  $offset = 0xf0900000 + $offset ;

  # The set/clr byte are next to each other
  if (  not($data)  ) { $offset = $offset + 4 ; }

  my $packet  = $class->bld_wr_quad_packet($offset, "1");

  my $rtn = $class->chat($packet);

  return ($rtn) ;
}


#----------------------------------------------------------
# serial_chat() - sends and rcvs on open Opto serial port
#
# NOTE:  The class object must have opened a socket on
# a port that maps to a particular Opto serial module.
#----------------------------------------------------------
sub serial_chat {

  my ($class) = shift @_;

  my ($data) = @_;

  my $rsp ;

  my $cnt; 
  eval {

     alarm ($timeout) ;

     print $class $data;

     # Wait for data
     select(undef,undef,undef,0.5);

     $cnt = $class->recv($rsp, 30, 0 ) ;

     alarm(0);

  };

  if (not ($cnt))  {
       $error_msg = "Nothing returned in Serial Chat\n$!\n" ;
       return 0 ;
  }else{

       return ($rsp) ;
  }
}

#----------------------------------------------------------
# serial_send() - sends to an open Opto serial port
#
# NOTE:  The class object must have opened a socket on
# a port that maps to a particular Opto serial module.
#----------------------------------------------------------
sub serial_send {

  my ($class) = shift @_;

  my ($data) = @_;

  eval {

     alarm ($timeout) ;

     print $class $data;

     alarm(0);

  };

  return(0);
}


#----------------------------------------------------------
# serial_rcv- rcvs on an open Opto serial port
#
# NOTE:  The class object must have opened a socket on
# a port that maps to a particular Opto serial module.
#----------------------------------------------------------
sub serial_rcv {

  my ($class) = shift @_;

  my $rsp ;

  eval {

     alarm ($timeout) ;

     $rsp = <$class>;   # blocks until newline terminated

     alarm(0);

 };

 if($rsp =~ /^\*/){  # all good data starts with a *  (Paroscientific Depth Probe Specific for P3 cmd)

    $rsp =~ s/\*0001(.+)/$1/;    # strip off the *0001 leading address info

    return($rsp);

 }else{

    $error_msg = "Bad data received in serial_rcv ($rsp)\n$!\n" ;
    return(0);
 }
}


########################
# Private methods
########################

sub big2little_fp {

 my $data = shift @_ ;

 my @lst = () ;

 my $size = length $data ;

 for ( my $j = 0 ; $j < $size ; $j = $j + 4 ) {

   my $quadword = substr $data , $j , 4 ;

   my $reverse_quadword = reverse $quadword ;       # Big to Little Endian

   push @lst, unpack( "f", $reverse_quadword );

 }

return @lst ;

}


sub big2little_int {

 my $data = shift @_ ;

 my @lst = () ;

 my $size = length $data ;

 for (my $j = 0 ; $j < $size ; $j = $j + 4 ) {

   my $quadword = substr $data , $j , 4 ;

   my $reverse_quadword = reverse $quadword ;       # Big to Little Endian

   push @lst, unpack( "l", $reverse_quadword );

 }

return @lst ;

}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Device::Opto22 - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Device::Opto22;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Device::Opto22, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

root, E<lt>root@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by root

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut