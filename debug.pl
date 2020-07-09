#! /usr/bin/env perl

use feature qw(say);
use strict;
use warnings;
use lib './inc';

use DateTimeXFormatExcel;
my @args_list = ('system_type', 'apple_excel');
my $converter = DateTimeXFormatExcel->new( @args_list );
my $num = "0.112311";
my $dt = $converter->parse_datetime( $num );
my $calc_sub_secs = $dt->format_cldr( "S" );
if( "0.$calc_sub_secs" >= 0.5 ){
    $dt->subtract( seconds => 1 );
}
my $result = $dt->format_cldr( q<mm:ss'.'>  );
$result .= $calc_sub_secs;
say $result;
