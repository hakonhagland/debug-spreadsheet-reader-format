#! /usr/bin/env perl

use feature qw(say);
use strict;
use warnings;
use lib './inc';
use POSIX qw( floor fmod );
use DateTimeXFormatExcel;
{
    say "DateTime::VERSION : ", $DateTime::VERSION;
    no warnings 'redefine';
    *DateTime::_format_nanosecs = \&format_nanosecs2;
    *DateTime::format_cldr = \&format_cldr;
    my @args_list = ('system_type', 'apple_excel');
    my $converter = DateTimeXFormatExcel->new( @args_list );
    my $num = "0.112311";
    my $dt = $converter->parse_datetime( $num );
    my $nanosecs = $dt->{rd_nanosecs};
    say "nanosecs: '$nanosecs'";
    $DB::single = 1;
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

sub format_nanosecs2 {
    my $self = shift;
    my $precision = @_ ? shift : 9;
    say "Precision: '$precision'";

    my $divide_by = 10**( 9 - $precision );
    say "divide_by: '$divide_by'";

    return sprintf(
        '%0' . $precision . 'u',
        floor( $self->{rd_nanosecs} / $divide_by )
    );
}

sub format_cldr {
        my $self = shift;

        say "Format_cldr..";
        # make a copy or caller's scalars get munged
        my @p = @_;

        my @r;
        foreach my $p (@p) {
            $p =~ s/\G
                    (?:
                      '((?:[^']|'')*)' # quote escaped bit of text
                                       # it needs to end with one
                                       # quote not followed by
                                       # another
                      |
                      (([a-zA-Z])\3*)     # could be a pattern
                      |
                      (.)                 # anything else
                    )
                   /
                    defined $1
                    ? $1
                    : defined $2
                    ? $self->_cldr_pattern($2)
                    : defined $4
                    ? $4
                    : undef # should never get here
                   /sgex;

            $p =~ s/\'\'/\'/g;

            return $p unless wantarray;

            push @r, $p;
        }

        return @r;
    }
