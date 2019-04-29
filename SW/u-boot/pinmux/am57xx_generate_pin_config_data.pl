#!/usr/bin/perl -w
#
# Copyright (c) 2015, Texas Instruments
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# *  Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# *  Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# *  Neither the name of Texas Instruments Incorporated nor the names of
#    its contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
# EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#Format with perltidy -et=4 -ce -bar -sbl

use strict;
use warnings;
use Getopt::Std;

#---------------------------------------- Data
my %options = ();
my $iodelay_file;
my $padconf_file;
my $output_format;
my %iodelay_array;
my %iopad_array;

# For New operations: update the two arrays
my %operations_help = (
	iopad   => "Generate IO Pad header data",
	iodelay => "Generate IO Delay header data",
);
my %operations_array = (
	iopad   => \&operation_iopad,
	iodelay => \&operation_iodelay,
);

#---------------------------------------- Main flow
getopts( "hp:d:o:", \%options );

if ( $options{h} ) {
	do_help("Usage:");
}

$iodelay_file  = $options{d} if defined $options{d};
$padconf_file  = $options{p} if defined $options{p};
$output_format = $options{o} if defined $options{o};

# check for sanity
do_help("Error: Missing file parameters!")
  if !defined $iodelay_file && !defined $padconf_file;
do_help("Error: Missing output format!") if !defined $output_format;
do_help("Error: iodelay file '$iodelay_file' is not readable")
  if defined $iodelay_file && !-r "$iodelay_file";
do_help("Error: padconf file '$padconf_file' is not readable")
  if defined $padconf_file && !-r "$padconf_file";
do_help("Error: Unknown Output format '$output_format'")
  if !exists( $operations_array{$output_format} );

# read input files
do_read_iopad($padconf_file)   if defined $padconf_file;
do_read_iodelay($iodelay_file) if defined $iodelay_file;

# Now, execute the corresponding operation
$operations_array{$output_format}->();

exit 0;

#---------------------------------------- Subroutines

# Help subroutine.. uses the argument of some error or print message..
sub do_help
{
	my $operation;

	print "@_\n";
	print "$0 [-h] [-p padconf_file | -d iodelay_file] -o output_format\n";
	print "Where";
	print "\t-h provides this help text\n";
	print
"\t-p padconf_file is the padconf output file provided by PCT(Pad Configuration Tool)\n";
	print
"\t-d iodelay_file is the iodelay output file provided by PCT(Pad Configuration Tool)\n";
	print "\t-o output_format , where output_format is one of:\n";

	foreach $operation ( keys %operations_array ) {
		print "\t\t $operation - $operations_help{$operation}\n";
	}
	exit 0;
}

# read into an associative array of array indexed by register address
# allows us to do operations and offsets and sorts. unfortunately with ballname,
# we dont have exactly an unique key considering that multiple idoelay registers
# have the same ballname
sub do_read_file
{
	my $file  = $_[0];
	my $iopad = $_[1];
	my $fh;
	my $row;
	my @iopad_row;
	my $register;
	my $skip = 0;

	open( $fh, '<', $file )
	  or do_help("Error: unable to open IOPAD $file for read");

	while ( $row = <$fh> ) {

		chomp($row);
		$row =~ s/\r//g;  # Handle DOS carriage return

		# get rid of commented lines including single line and multiline
		next if $skip == 1;
		if ( $row =~ /\/\*/ ) { $skip = 1 if !$row =~ /\*\//; next; }
		if ( $row =~ /\*\// ) { $skip = 0; next; }

		# get rid of Empty lines
		next if $row =~ /^$/;

		# Now, Human readable to CSV
		$row =~ s/\s\s*/,/g;
		@iopad_row = split( ',', $row );
		$register  = $iopad_row[0];
		@iopad_row = splice @iopad_row, 1, $#iopad_row;
		if ($iopad) {
			$iopad_array{$register} = [@iopad_row];
		} else {
			$iodelay_array{$register} = [@iopad_row];
		}
	}

	close($fh);
}

# tiny lil wrapper
sub do_read_iopad
{
	do_read_file( $_[0], 1 );
}

# tiny lil wrapper
sub do_read_iodelay
{
	do_read_file( $_[0], 0 );
}

#---- the various operations----
sub operation_iopad()
{
	my $register;

	do_help("Error: I need iodelay file for this option")
	  if !defined $iodelay_file;
	do_help("Error: I need padconf file for this option")
	  if !defined $padconf_file;

	foreach $register ( sort keys %iopad_array ) {
		my @val;
		my $reg_val;
		my $reg_name;
		my $ball_name;
		my $mux0;
		my $mux;
		my $reg_dec;
		my $slew_control;
		my $input_en;
		my $pull_active;
		my $pull_up;
		my $compare_val;
		my $compare_hex;
		my $val_mux0_name;
		my $val_mux_mode;
		my $val_pull;
		my $val_delay_mode;
		my $val_virtual_mode;
		my $val_manual_mode;

		@val = @{ $iopad_array{$register} };

# register_address(hex)        register_value(hex)     ball_name(string)       register_name(string)   mux_mode0_name(string)  muxed_mode_name(string)
		( $reg_val, $ball_name, $reg_name, $mux0, $mux ) = @val;

		$reg_dec = hex($reg_val);

		#pulls and mux mode
		$slew_control = $reg_dec & ( 1 << 19 );
		$input_en     = $reg_dec & ( 1 << 18 );
		$pull_up      = $reg_dec & ( 1 << 17 );
		$pull_active  = $reg_dec & ( 1 << 16 );
		$compare_val = $slew_control | $input_en | $pull_up | $pull_active;
		$compare_hex = sprintf( "0x%08x", $compare_val );
		if ( $compare_hex =~ /0x00000000/ ) {
			$val_pull = "PIN_OUTPUT_PULLDOWN";
		} elsif ( $compare_hex =~ /0x00010000/ ) {
			$val_pull = "PIN_OUTPUT";
		} elsif ( $compare_hex =~ /0x00020000/ ) {
			$val_pull = "PIN_OUTPUT_PULLUP";
		} elsif ( $compare_hex =~ /0x00030000/ ) {
			$val_pull = "PIN_OUTPUT";
		} elsif ( $compare_hex =~ /0x00040000/ ) {
			$val_pull = "PIN_INPUT_PULLDOWN";
		} elsif ( $compare_hex =~ /0x00050000/ ) {
			$val_pull = "PIN_INPUT";
		} elsif ( $compare_hex =~ /0x00060000/ ) {
			$val_pull = "PIN_INPUT_PULLUP";
		} elsif ( $compare_hex =~ /0x00070000/ ) {
			$val_pull = "PIN_INPUT";
		} elsif ( $compare_hex =~ /0x00080000/ ) {
			$val_pull = "PIN_OUTPUT_PULLDOWN | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x00090000/ ) {
			$val_pull = "PIN_OUTPUT | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x000a0000/ ) {
			$val_pull = "PIN_OUTPUT_PULLUP | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x000b0000/ ) {
			$val_pull = "PIN_OUTPUT | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x000c0000/ ) {
			$val_pull = "PIN_INPUT_PULLDOWN | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x000d0000/ ) {
			$val_pull = "PIN_INPUT | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x000e0000/ ) {
			$val_pull = "PIN_INPUT_PULLUP | SLEWCONTROL";
		} elsif ( $compare_hex =~ /0x000f0000/ ) {
			$val_pull = "PIN_INPUT | SLEWCONTROL";
		}

		# Uggh.. unknown definition?
		else { $val_pull = $compare_hex; }

		# virtual mode definition
		$val_virtual_mode = ( $reg_dec >> 4 ) & 15;
		$val_delay_mode = "MODESELECT" if $reg_dec & ( 1 << 8 );

		# Am i Manual mode with VIRTUAL_MODE0 ?
		if ( defined $val_delay_mode && $val_virtual_mode == 0 ) {
			my $iodr;

			#This could be manual mode!
			foreach $iodr ( keys %iodelay_array ) {
				my @iodv;
				my $iod_a_delay;
				my $iod_g_delay;
				my $iod_reg_name;
				my $iod_ball;
				my $na = "N/A";

				@iodv = @{ $iodelay_array{$iodr} };
				( $iod_a_delay, $iod_g_delay, $iod_reg_name, $iod_ball ) =
				  @iodv;
				if ( !$ball_name =~ /$iod_ball/ ) { next; }
				if ( $iod_a_delay =~ /$na/ && $iod_g_delay =~ /$na/ ) { next; }

				# if either one is defined, we are manual mode
				$val_manual_mode = "MANUAL_MODE";
			}

		}

		# mux mode
		$val_mux_mode = $reg_dec & 15;

		# register defines is mux_mode0 name
		# CTRL_CORE_PAD_GPMC_AD0 -> is GPMC_AD0
		$val_mux0_name = substr $reg_name, 14;
		print "\{$val_mux0_name, (M$val_mux_mode | $val_pull";
		if ( defined $val_delay_mode ) {
			if ( defined $val_manual_mode ) {
				print " | $val_manual_mode";
			} else {
				printf " | VIRTUAL_MODE$val_virtual_mode";
			}
		}
		printf(")},\t/* $mux0.$mux */\n");
	}
}

sub operation_iodelay()
{
	my $register;
	my @val;

	do_help("Error: I need iodelay file for this option")
	  if !defined $iodelay_file;

	foreach $register ( sort keys %iodelay_array ) {
		my @iodv;
		my $iodelay_base = 0x4844A000;
		my $reg_dec;
		my $offset;
		my $iod_a_delay;
		my $iod_g_delay;
		my $iod_reg_name;
		my $iod_ball;
		my $na = "N/A";
		my $val_a;
		my $val_g;
		my $val_offset;

		@iodv = @{ $iodelay_array{$register} };
		( $iod_a_delay, $iod_g_delay, $iod_reg_name, $iod_ball ) = @iodv;
		next if $iod_a_delay =~ /$na/ && $iod_g_delay =~ /$na/;
		if ( $iod_a_delay =~ /$na/ ) {
			$val_a = 0;
		} else {
			$val_a = $iod_a_delay;
		}
		if ( $iod_g_delay =~ /$na/ ) {
			$val_g = 0;
		} else {
			$val_g = $iod_g_delay;
		}
		$reg_dec    = hex($register);
		$offset     = $reg_dec - $iodelay_base;
		$val_offset = sprintf( "0x%04X", $offset );
		print "{$val_offset, $val_a, $val_g},\t/* $iod_reg_name */\n";
	}
}
