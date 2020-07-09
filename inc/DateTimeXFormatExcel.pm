package DateTimeXFormatExcel;
use version 0.77; our $VERSION = version->declare("v0.14.0");
use	5.010;
use	strict;
use	warnings;
use feature qw(say);
use Data::Dumper qw(Dumper);
use List::Util 1.33;
use	Moose 2.1213;
use	MooseX::StrictConstructor;
use	MooseX::HasDefaults::RO;
use	DateTime;
use	Carp qw( cluck );
use Types::Standard -types;
if( $ENV{ Smart_Comments } ){
	use Smart::Comments -ENV;
	### Smart-Comments turned on for DateTimeX-Format-Excel ...
}
use DateTimeX::Format::Excel::Types 0.012 qw(
	DateTimeHash
	DateTimeInstance
	HashToDateTime
	is_ExcelEpoch
	ExcelEpoch
	SystemName
);

#########1 Dispatch Tables    3#########4#########5#########6#########7#########8#########9

my	$input_scrub ={
		win_excel	=>{
			action => sub{
				### <where> - Reached win_excel scrub with: @_
				if(int( $_[0] ) == 60){
					cluck "-1900-February-29- is not a real date (contrary to excel implementation)";
				}elsif($_[0] == 0){
					cluck "-1900-January-0- is not a real date (contrary to excel implementation)";
				}
				### <where> - Finished testing Lotus 123 date error warnings ...
				my	$return =(
						(int( $_[0] ) > 60) ? ($_[0] - 1) :
						(int( $_[0] ) == 0) ? ($_[0] + 1) : $_[0] );
				### <where> - updated date: $return
				return $return;
			},
			output => sub{
				### <where> - Reached win_excel output with: @_
				my	$return =( (defined( $_[0] ) and int( $_[0] ) > 59) ? ($_[0] + 1) : $_[0] );
				if( defined( $return ) and $return < 1 ){
					$return = undef;
				}
				### <where> - updated date: $return
				return $return;
			},
			date_time_hash =>{
				year	=> 1899,# actually 1900
				month	=> 12,# actually 01
				day		=> 31,# actually 00
			},
		},
		apple_excel	=>{
			date_time_hash =>{
				year	=> 1904,
				month	=> 1,
				day		=> 1,
			},
		}
	};

#########1 Public Attributes  3#########4#########5#########6#########7#########8#########9

has system_type =>(
        isa         => SystemName,
		reader		=> 'get_system_type',
        writer      => 'set_system_type',
		default		=> 'win_excel',
		trigger		=> \&_set_system,
    );

#########1 Public Methods     3#########4#########5#########6#########7#########8#########9

sub parse_datetime{
    my ( $self, $date_num, $timezone_flag, $timezone ) = @_;
	### <where> - Reached parse_datetime for: $date_num
    say "date_num: '$date_num'";
    if( !is_ExcelEpoch( $date_num ) ){
		### <where> - not and excel epoch: $date_num
		return $date_num;
	}
	### <where> - Passed the type constraint ...
	if( my $action = $input_scrub->{$self->get_system_type}->{action} ){
		### <where> - There is an action: $action
		### <where> - Using system name: $self->get_system_type
		$date_num = $action->( $date_num );
	}
	### <where> - Updated date num: $date_num
	$date_num	=~ /^ (\d+ (?: (\.\d+ ) )? ) $/x;
    my	$excel_days = $1;
    my	$excel_secs = $2;
	### <where> - Excel added days: $excel_days
	### <where> - Excel seconds: $excel_secs
    my	$dt = $self->_get_epoch_start->clone();
	### <where> - DateTime: $dt
    if(defined $excel_secs){
        say "excel_secs: '$excel_secs'";
       $excel_secs				= $excel_secs * (60*60*24);# Seconds in most days
       my $excel_nanoseconds	= ($excel_secs - int($excel_secs)) * 1_000_000_000;
		### <where> - Excel days: $excel_days
		### <where> - Excel seconds: $excel_secs
		### <where> - Excel nano seconds: $excel_nanoseconds
        say "excel_nanoseconds: '$excel_nanoseconds'";
       $dt->add( days			=> $excel_days,
                 seconds		=> $excel_secs,
                 nanoseconds	=> $excel_nanoseconds);
    } else {
		### <where> - No seconds in the epoch ...
		$dt->add( days => $excel_days );
    }
	if( $timezone_flag and $timezone_flag eq 'time_zone' ){
		### <where> - Setting timezone to: $timezone
		$dt->set_time_zone( $timezone );
	};
	### <where> - DateTime: $dt

    return $dt;
}

sub format_datetime{
    my ( $self, $date_time ) = @_;
	### <where> - Reached format_datetime with: $date_time
	DateTimeInstance->( $date_time );
    my $base = $self->_get_epoch_start->clone();
	my	$test = DateTime->compare_ignore_floating( $date_time, $base );
	### <where> - DateTime base is: $base
	### <where> - Using system name: $self->get_system_type
	### <where> - Test result: $test
	my	$excel = undef;
	my	$return_string = 0;
	if( $test < 0 ){
		$return_string = 1;
	}else{
		$excel = $date_time->jd - $base->jd;
	}
	### <where> - Initial excel epoch: $excel
	if( defined $excel and my $action = $input_scrub->{$self->get_system_type}->{output} ){
		### <where> - There is an action: $action
		### <where> - For: $self->get_system_type
		$excel = $action->( $excel );
		$return_string = 1 if !defined $excel;
	}
	### <where> - Should return a date string: $return_string
	### <where> - Final excel epoch: $excel
	### <where> - Original DateTime: $date_time

    return ( $return_string ) ? $date_time : $excel;
}

#########1 Private Attributes 3#########4#########5#########6#########7#########8#########9

has _epoch_start =>(
		isa		=> DateTimeInstance->plus_coercions( HashToDateTime ),
		writer	=> '_set_epoch_start',
		reader	=> '_get_epoch_start',
		coerce	=> 1,
		default	=> sub{ DateTime->new(
			$input_scrub->{win_excel}->{date_time_hash}
		) },
	);

#########1 Private Methods    3#########4#########5#########6#########7#########8#########9

sub	_set_system{
	my ( $self, $system_type ) = @_;
	$self->_set_epoch_start( $input_scrub->{$system_type}->{date_time_hash} );
	return $system_type;
}

#########1 Phinish            3#########4#########5#########6#########7#########8#########9

no Moose;
__PACKAGE__->meta->make_immutable(
	inline_constructor => 0,
);

1;

#########1 Documentation      3#########4#########5#########6#########7#########8#########9
__END__

=head1 NAME

DateTimeX::Format::Excel - Microsofty conversion of Excel epochs

=begin html

<a href="https://www.perl.org">
	<img src="https://img.shields.io/badge/perl-5.10+-brightgreen.svg" alt="perl version">
</a>

<a href="https://travis-ci.org/jandrew/DateTimeX-Format-Excel">
	<img alt="Build Status" src="https://travis-ci.org/jandrew/DateTimeX-Format-Excel.png?branch=master" alt='Travis Build'/>
</a>

<a href='https://coveralls.io/r/jandrew/DateTimeX-Format-Excel?branch=master'>
	<img src='https://coveralls.io/repos/jandrew/DateTimeX-Format-Excel/badge.svg?branch=master' alt='Coverage Status' />
</a>

<a href='https://github.com/jandrew/DateTimeX-Format-Excel'>
	<img src="https://img.shields.io/github/tag/jandrew/DateTimeX-Format-Excel.svg?label=github level" alt="github level"/>
</a>

<a href="https://metacpan.org/pod/DateTimeX::Format::Excel">
	<img src="https://badge.fury.io/pl/DateTimeX-Format-Excel.svg?label=cpan version" alt="CPAN version" height="20">
</a>

<a href='http://cpants.cpanauthors.org/dist/DateTimeX-Format-Excel'>
	<img src='http://cpants.cpanauthors.org/dist/DateTimeX-Format-Excel.png' alt='kwalitee' height="20"/>
</a>

=end html

=head1 SYNOPSIS

	#!/usr/bin/env perl
	use DateTimeX::Format::Excel;

	# From an Excel date number

	my	$parser = DateTimeX::Format::Excel->new();
	print	$parser->parse_datetime( 25569 )->ymd ."\n";
	my	$datetime = $parser->parse_datetime( 37680 );
	print	$datetime->ymd() ."\n";
		$datetime = $parser->parse_datetime( 40123.625 );
	print	$datetime->iso8601() ."\n";

	# And back to an Excel number from a DateTime object

	use DateTime;
	my	$dt = DateTime->new( year => 1979, month => 7, day => 16 );
	my	$daynum = $parser->format_datetime( $dt );
	print 	$daynum ."\n";

	my 	$dt_with_time = DateTime->new( year => 2010, month => 7, day => 23
									, hour => 18, minute => 20 );
	my 	$parser_date = $parser->format_datetime( $dt_with_time );
	print 	$parser_date ."\n";

	###########################
	# SYNOPSIS Screen Output
	# 01: 1970-01-01
	# 02: 2003-02-28
	# 03: 2009-11-06T15:00:00
	# 04: 29052
	# 05: 40382.763888889
	###########################

=head1 DESCRIPTION

Excel uses a different system for its dates than most Unix programs.
This package allows you to convert between the Excel raw format and
and L<DateTime> objects, which can then be further converted via any
of the other L<DateTime::Format::*
|https://metacpan.org/search?q=DateTime%3A%3AFormat> modules, or just
with L<DateTime>'s methods.  The L<DateTime::Format::Excel> module states
"we assume what Psion assumed for their Abacus / Sheet program".  As a
consequence the output does not follow exactly the output of Excel.
Especially in the Windows range of 0-60.  This module attempts to more
faithfully follow actual Microsoft Excel with a few notable exceptions.

Excel has a few date quirks. First, it allows two different epochs.  One
for the Windows world and one for the Apple world.  The windows epoch
starts in 0-January-1900 and allows for 29-February-1900 (both non real
dates).  Most of the explanations for the difference between windows
implementations and Apple implementations focus on the fact that there
was no leap year in 1900 L<(the Gregorian vs Julian calendars)
|http://en.wikipedia.org/wiki/Gregorian_calendar> and the Apple
version wanted to skip that issue.  Both non real dates appear to have
been a known issue in the original design of VisiCalc that was carried
through Lotus 1-2-3 and into Excel for L<compatibility
|http://support.microsoft.com/kb/214326>.  (Spreadsheets were arguably the
first personal computer killer app and Excel was a L<johnny come lately
|http://en.wikipedia.org/wiki/Lotus_1-2-3#VisiCalc> trying to gain an entry
into the market at the time.)  The closest microsoft discussion I could find
on this issue is L<here|http://www.joelonsoftware.com/items/2006/06/16.html>.
In any case the apple version starts 1-January-1904. (counting from 0 while
also avoiding the leap year issue).  In both cases the Windows and Apple
version use integers from the epoch start to represent days and the decimal
portion to represent a portion of a day.  Both Windows and Apple Excel will
attempt to convert recognized date strings to an Excel epoch for storage with
the exception that any date prior to the epoch start will be stored as a
string.  (31-December-1899 and earlier for Windows and 31-December-1903 and
earlier for Apple).  Next, Excel does not allow for a time zone component of
each number. Finally, in the Windows version when dealing with epochs that
do not have a date component just a time component all values will fall
between 0 and 1 which is a non real date (0-January-1900).

=head2 Caveat utilitor

This explanation is not intended to justify Microsofts decisions with Excel
dates just replicate them as faithfully as possible.  This module makes the
assumption that you already know if your date is a string or a number in Excel
and that you will handle string to DateTime conversions elsewhere. see
L<DateTime::Format::Flexible>.  Any passed strings will die.  (As a failure
of a L<Type::Tiny> test)  This module also makes several unilateral decisions
to deal with corner cases.  When a 0 date is requested to be converted to
DateTime it will use L<Carp> to cluck that it received a bad date and then
provide a DateTime object dated 1-January-1900 (Excel would provide
0-January-1900).  If a value between 0 and 1 is requested to be converted to
a DateTime object the module will B<NOT> cluck and provide an object dated
1-January-1900 with the appropriate time component. All Apple times are provide
as 1-January-1904.  Any requested numerical conversion for Windows >= 60 and
< 61 will cluck and provide a DateTime object dated 1-March-1900 (Excel would
provide 29-Febrary-1900).  All requests for conversion of negative numbers to
DateTime objects will die .  If a DateTime object is provided for conversion
to the Excel value and it falls earlier than 1-January-1900 for Windows and
1-January-1904 for Apple then the DateTime object itself will be returned.
If you accept the output of that L<method|/format_datetime( $date_time )>
as a scalar, DateTime will stringify itself and give you a text equivalent
date.  For time zones you can L<pass|/parse_datetime( @arg_list )> a time zone
with the excel number for conversion to the DateTime object.  In reverse,
the conversion to Excel Epoch uses the L<-E<gt>jd
|https://metacpan.org/pod/DateTime#dt-jd-dt-mjd> method for calculation so
the time zone is stripped out.  No clone or duration calculations are provided
with this module.  Finally this is a L<Moose> based module and does
not provide a functional interface. I<(Moose would allow it I just chose not
to for design purposes)>.

The Types module for this package uses L<Type::Tiny> which can, in the background,
use L<Type::Tiny::XS>.  While in general this is a good thing you will need to make
sure that Type::Tiny::XS is version 0.010 or newer since the older ones didn't support
the 'Optional' method.

=head2 Attributes

Data passed to new when creating an instance (parser).  For modification of
these attributes see the listed L</Methods> of the instance.

=head3 system_type

=over

B<Definition:> This attribute identifies whether the translation will be done
for Windows Excel => 'win_excel' or Apple Excel => 'apple_excel'.

B<Default> win_excel (0-January-1900T00:00:00 = 0, range includes 29-February-1900)

B<Range> win_excel|apple_excel (1-January-1904T00:00:00 = 0)

=back

=head2 Methods

These include methods to adjust attributes as well as providing methods to
provide the conversion functionality of the module.

=head3 get_system_type

=over

B<Definition:> This is the way to see whether the conversion is Windows or Apple based

B<Accepts:>Nothing

B<Returns:> win_excel|apple_excel

=back

=head3 set_system_type( $system )

=over

B<Definition:> This is the way to set the base epoch for the translator

B<Accepts:> win_excel|apple_excel (see the L</DESCRIPTION> for details)

B<Returns:> Nothing

=back

=head3 parse_datetime( @arg_list )

=over

B<Definition:> This is how positive excel numbers are translated to L<DateTime> objects

B<Accepts:> @arg_list - the order is important!

=over

B<0. > $the_excel_number_for_translation - must be positive - no strings allowed

B<1. > 'time_zone' (the only useful option - other values here will ignore position 2)

B<2. > A recognizable time zone string or L<DateTime::TimeZone> object

B<example: > ( 12345, time_zone => 'America/Los_Angeles' )

=back

B<Returns:> A DateTime object set to match the passed values.  A floating time zone is default.

=back

=head3 format_datetime( $date_time )

=over

B<Definition:> This is how DateTime objects can be translated to Excel epoch numbers

B<Accepts:> A L<DateTime> object

B<Returns:> An excel epoch number or DateTime object if it is before the relevant epoch start.

=back

=head2 A note on text dates

Dates saved in Excel prior to 1-January-1900 for Windows or 1-January-1904 for Apple are stored as text.
I suggest using L<Type::Tiny::Manual::Coercions/Chained Coercions>.  Or use an Excel reader
that implements this for you like L<Spreadsheet::XLSX::Reader::LibXML> (self promotion).
Here is one possible way to integrate text and dates in the same field into a consistent DateTime
output. (I know it's a bit clunky but it's a place to start)

	my $system_lookup = {
			'1900' => 'win_excel',
			'1904' => 'apple_excel',
		};
	my	@args_list	= ( system_type => $system_lookup->{$workbook->get_epoch_year} );
	my	$converter	= DateTimeX::Format::Excel->new( @args_list );
	my	$string_via	= sub{
							my	$str = $_[0];
							return DateTime::Format::Flexible->parse_datetime( $str );
						};
	my	$num_via	= sub{
							my	$num = $_[0];
							return $converter->parse_datetime( $num );
						};
	my	$date_time_from_value = Type::Coercion->new(
			type_coercion_map => [ Num, $num_via, Str, $string_via, ],
		);
	my	$date_time_type = Type::Tiny->new(
			name		=> 'Custom_date_type',
			constraint	=> sub{ ref($_) eq 'DateTime' },
			coercion	=> $date_time_from_value,
		);
	my	$string_type = Type::Tiny->new(
			name		=> 'YYYYMMDD',
			constraint	=> sub{
				!$_ or (
				$_ =~ /^\d{4}\-(\d{2})-(\d{2})$/ and
				$1 > 0 and $1 < 13 and $2 > 0 and $2 < 32 )
			},
			coercion	=> Type::Coercion->new(
				type_coercion_map =>[
					$date_time_type->coercibles, sub{
						my $tmp = $date_time_type->coerce( $_ );
						$tmp->format_cldr( 'yyyy-MM-dd' )
					},
				],
			),
	);


=head1 THANKS

Dave Rolsky (L<DROLSKY>) for kickstarting the DateTime project.
Iain Truskett, Dave Rolsky, and Achim Bursian for maintaining L<DateTime::Format::Excel>.
	I used it heavily till I wrote this.
Peter (Stig) Edwards and Bobby Metz for contributing to L<DateTime::Format::Excel>.

=head1 Build/Install from Source

B<1.> Download a compressed file with the code

B<2.> Extract the code from the compressed file.  If you are using tar this should work:

        tar -zxvf DateTimeX-Format-Excel-v1.xx.tar.gz

B<3.> Change (cd) into the extracted directory

B<4.> Run the following commands

=over

(For Windows find what version of make was used to compile your perl)

	perl  -V:make

(then for Windows substitute the correct make function (s/make/dmake/g)?)

=back

	>perl Makefile.PL

	>make

	>make test

	>make install # As sudo/root

	>make clean

=head1 SUPPORT

=over

L<github DateTimeX::Format::Excel/issues|https://github.com/jandrew/DateTimeX-Format-Excel/issues>

=back

=head1 TODO

=over

B<1.> Add an error attribute to load soft failures or warnings to

B<2.> Convert Smart::Comments to L<Log::Shiras|https://github.com/jandrew/Log-Shiras> debug lines

B<3.> Allow localization as an input to the data so the object output will localize (DateTime::Local)

=back

=head1 AUTHOR

=over

=item Jed Lund

=item jandrew@cpan.org

=back

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

This software is copyrighted (c) 2014 - 2016 by Jed Lund

=head1 DEPENDENCIES

=over

B<5.010> - (L<perl>)

L<version> - 0.77

L<Moose>

L<MooseX::StrictConstructor>

L<MooseX::HasDefaults::RO>

L<DateTime>

L<Carp>

L<Types::Standard>

L<DateTimeX::Format::Excel::Types>

=back

=head1 SEE ALSO

=over

L<DateTime::Format::Excel>

L<Smart::Comments> - Turned on with $ENV{ Smart_Comments }

=back

=cut

#########1#########2 main pod documentation end  5#########6#########7#########8#########9
