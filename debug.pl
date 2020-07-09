#! /usr/bin/env perl

use feature qw(say);
use strict;
use warnings;
use lib './inc';
use POSIX qw( floor fmod );
use DateTimeXFormatExcel;
{
    say "DateTime::VERSION : ", $DateTime::VERSION;
    *DateTime::_format_nanosecs = \&format_nanosecs;
    my @args_list = ('system_type', 'apple_excel');
    my $converter = DateTimeXFormatExcel->new( @args_list );
    my $num = "0.112311";
    my $dt = $converter->parse_datetime( $num );
    my $nanosecs = $dt->{rd_nanosecs};
    say "nanosecs: '$nanosecs'";
    my $calc_sub_secs = $dt->format_cldr( "S" );
    if( "0.$calc_sub_secs" >= 0.5 ){
        $dt->subtract( seconds => 1 );
    }
    my $result = $dt->format_cldr( q<mm:ss'.'>  );
    $result .= $calc_sub_secs;
    say $result;
}

sub format_nanosecs {
    my $self      = shift;
    my $precision = @_ ? shift : 9;

    say "Precision: '$precision'";
    my $exponent     = 9 - $precision;
    say "Exponent: '$exponent'";
    my $nano = $self->{rd_nanosecs};
    say "Nano: '$nano'";
    my $formatted_ns = floor(
        (
              $exponent < 0
            ? $self->{rd_nanosecs} * 10**-$exponent
            : $self->{rd_nanosecs} / 10**$exponent
        )
    );
    say "Formatted_ns: '$formatted_ns'";
    say 'Format: ', '%0' . $precision . 'u';

    return sprintf(
        '%0' . $precision . 'u',
        $formatted_ns
    );
}
