package Device::Opto22::Firewire;

use IO::Socket;
use IO::Select;
use POSIX;

our @ISA = qw(IO::Socket);

our @EXPORT_OK = ( );

our @EXPORT = qw( 0chat bld_rd_quad_packet bld_wr_quad_packet bld_rd_blk_packet bld_wr_blk_packet dump_quadlet ); 

our $VERSION = '0.90';

$| = 1;

# Global Data Area

# TCode for transmission
our $TC_WR_QUAD_RQST  = 0;
our $TC_WR_BLK_RQST   = 1;
our $TC_RD_QUAD_RQST   = 4;
our $TC_RD_BLK_RQST    = 5;

# TCode for responses
our $TC_WR_RSP     = 2;
our $TC_RD_BLK_RSP  = 6;
our $TC_RD_QUAD_RSP = 7;

our $timeout = 5;
our $error_msg; 

sub new {

    my $class = shift @_;
    %args     = @_;

    $PeerAddr = $args{PeerAddr} ;
    $PeerPort = $args{PeerPort} ;

    if (not ($PeerAddr && $PeerPort) )  {
          $error_msg = "Inputs missing in Package $class Addr = $PeerAddr, Port = $PeerPort" ;
          return 0 ;
    }


    # This establishes a SENDER socket connection OK
    $root = new IO::Socket::INET (PeerAddr => $PeerAddr ,
                                       PeerPort => $PeerPort ,
                                       Proto    => 'tcp',
                                       Timeout  => $timeout );

    if ( not($root))  {
          $error_msg = "Error Socket Connecting" ;
          return 0 ;
    }

    $SIG{ALRM} = \&_time_out ;

    bless  $root;

    return $root;
}

#----------------------------------------------------------------------
# Description:  Does a socket transation
#
# Inputs:  $socket - Socket descriptor
#          $packet - Request packet to send
#
# Output:
#----------------------------------------------------------------------

sub chat {

  my ($class, $packet) = @_;
  
  my ($rsp,$cnt);

  eval {

     alarm ($timeout) ;

     print $class $packet;
     $cnt = $class->recv($rsp, 300, 0 ) ;
     alarm(0);
  };

  unless ( length($rsp) )  
  {
          $error_msg = "$@ - Nothing returned in Chat\n$!\n" ;
          return 0 ;
  }

  # Split response
  my $header  = substr $rsp, 0 , 16 ;
  my $payload = substr $rsp, 16     ;

  @header_lst = unpack ("C8", $header ) ;

  $tcode = $header_lst[3] >> 4 ;
  $rcode = $header_lst[6] >> 4 ;

  if ($rcode) {
    $error_msg = "oh oh we got a NAK in Chat \n$!\n" ;
    return 0 ;
  }

  if ( $tcode == 2 )  { $payload = 1 ; }

  return ($payload) ;
}

#----------------------------------------------------------------------
# Description:  Formats a packet as per pg 106 of the SNAP Users Guide
#
# Inputs:  $offset (hexidecimal MemMap address)
#
# Output:  pointer to the packet consisting of 16 bytes
#----------------------------------------------------------------------

sub bld_rd_quad_packet {

  ($class, $offset) = @_;

  $src_id = 0 ;

  $trans += 1; # global variable

  $dest_id = 0;                      # Destination ID

  $tl      = ($trans & 0x3f)  << 2;  # Transaction Label (shifted to set retry bits to 00)
  $tcode   = $TC_RD_QUAD_RQST << 4;  # Bit shift over the unused priority bits

  $fixed = 0xffff ;     # fixed area of address

  $packet = pack "ncc n2 N N", $dest_id, $tl, $tcode, $src_id, $fixed, $offset ;

  return $packet;

}

#----------------------------------------------------------------------
# Description:  Formats a packet as per pg 106 of the SNAP Users Guide
#
# Inputs:  $offset - (hexidecimal MemMap address which is prefixed with $fixed)
#          $data   - 4 bytes of data to write
#
# Output:  pointer to the packet consisting of 16 bytes
#----------------------------------------------------------------------

sub bld_wr_quad_packet {

  my %args = @_ ;

  ($class, $offset, $data) = @_;

  $trans += 1; # global variable

  $src_id = 0  ;

  $dest_id = 0;                      # Destination ID
  $tl      = ($trans & 0x3f)  << 2;  # Transaction Label (shifted to set retry bits to 00)
  $tcode   = $TC_WR_QUAD_RQST << 4;  # Bit shift over the unused priority bits

  $fixed = 0xffff ;     # fixed area of address



  $packet = pack "ncc n2 N N", $dest_id, $tl, $tcode, $src_id, $fixed, $offset, $data;

  return $packet;

}

#----------------------------------------------------------------------
# Description:  Formats a packet as per pg 106 of the SNAP Users Guide
#
# Inputs:  $offset - (hexidecimal MemMap address which is prefixed with $fixed)
#          $data   - 4 bytes of data to write
#
# Output:  pointer to the packet consisting of 16 bytes
#----------------------------------------------------------------------

sub bld_rd_blk_packet {

  my %args = @_ ;

  ($class, $offset, $length) = @_;

  $trans += 1; # global variable

  $src_id = 0  ;

  $dest_id = 0;                      # Destination ID
  $tl      = ($trans & 0x3f)  << 2;  # Transaction Label (shifted to set retry bits to 00)
  $tcode   = $TC_RD_BLK_RQST  << 4;  # Bit shift over the unused priority bits

  $fixed = 0xffff ;     # fixed area of address

  $length = $length << 16 ;

  $packet = pack "ncc n2 N2", $dest_id, $tl, $tcode, $src_id, $fixed, $offset, $length ;

  return $packet;

}

#----------------------------------------------------------------------
# Description:  Formats a packet as per pg 106 of the SNAP Users Guide
#
# Inputs:  $offset - (hexidecimal MemMap address which is prefixed with $fixed)
#          $data   - 4 bytes of data to write
#
# Output:  pointer to the packet consisting of 16 bytes
#----------------------------------------------------------------------

sub bld_wr_blk_packet {

  my %args = @_ ;

  ($class, $offset, $length) = @_;

  $trans += 1; # global variable

  $src_id = 0  ;

  $dest_id = 0;                      # Destination ID
  $tl      = ($trans & 0x3f)  << 2;  # Transaction Label (shifted to set retry bits to 00)
  $tcode   = $TC_WR_BLK_RQST  << 4;  # Bit shift over the unused priority bits

  $fixed = 0xffff ;                  # fixed area of address

  $length = $length << 16 ;

  $packet = pack "ncc n2 N2", $dest_id, $tl, $tcode, $src_id, $fixed, $offset, $length ;

  return $packet;

}

#------------------
# Private Functions
#------------------

sub _time_out {

 die "Error Time Out" ;

}


sub dump_quadlet
{
 my $self = shift @_ ;
 my $data = shift @_ ;

 my $len = length($data); 
 print "Length $len\n"; 
 
 @lst = split // , unpack  "B128" , $data ;

 my $cnt;
 foreach my $b (@lst) 
 {
 
    print "$b ";
	$cnt++;
	unless ( $cnt % 8 )  { print " "  }
    unless ( $cnt % 32 ) { print "\n" }	
 }	
 
 print "\n"; 
}

1;









