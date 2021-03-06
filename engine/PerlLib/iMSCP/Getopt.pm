=head1 NAME

 iMSCP::Getopt - Provides command line options for both imscp-autoinstall and imscp-setup scripts

=cut

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2015 by Laurent Declercq <l.declercq@nuxwin.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

package iMSCP::Getopt;

use strict;
use warnings;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use iMSCP::Debug qw/ debugRegisterCallBack /;
use Text::Wrap;
use fields qw / reconfigure noprompt preseed listener cleanPackagesCache skipPackagesUpdate debug /;

$Text::Wrap::columns = 80;
$Text::Wrap::break = qr/[\s\n\|]/;

our $options = fields::new('iMSCP::Getopt');
our $optionHelp = '';

my $showUsage;

=head1 DESCRIPTION

 This class provide command line options for both imscp-autoinstall and imscp-setup scripts.

=head1 CLASS METHODS

=over 4

=item parse($usage)

 This class method parses command line options in @ARGV with GetOptions from Getopt::Long.

 The first parameter should be basic usage text for the program in question. Usage text for the globally supported
options will be prepended to this if usage help must be printed.

 If any additonal parameters are passed to this function, they are also passed to GetOptions. This can be used to handle
additional options.

 Return undef

=cut

sub parse
{
	my ($class, $usage) = (shift, shift);

	$showUsage = sub {
		my $exitCode = shift || 0;
		print STDERR wrap('', '', <<EOF);
$usage
 -r,    --reconfigure [item]    Type --reconfigure help.
 -n,    --noprompt              Switch to non-interactive mode.
 -p,    --preseed <file>        Path to preseed file.
 -l,    --listener <file>       Path to listener file.
 -c     --clean-packages-cache  Cleanup i-MSCP packages cache.
 -a     --skip-packages-update  Skip i-MSCP packages update
 -d,    --debug                 Force debug mode.
 -?,-h  --help                  Show this help.

 $optionHelp
EOF
		debugRegisterCallBack(sub { exit $exitCode; });
		exit $exitCode;
	};

	# Do not load Getopt::Long if not needed
	return unless grep { $_ =~ /^-/ } @ARGV;

	local $SIG{__WARN__} = sub {
		my $error = shift;
		$error =~ s/(.*?) at.*/$1/;
		print STDERR wrap('', '', $error) if $error ne "Died\n";
	};

	require Getopt::Long;

	Getopt::Long::Configure('bundling');

	eval {
		Getopt::Long::GetOptions(
			'reconfigure|r:s', sub { $class->reconfigure($_[1]) },
			'noprompt|n', sub { $options->{'noprompt'} = 1 },
			'preseed|p=s', sub { $class->preseed($_[1]) },
			'listener|l=s', sub { $class->listenerFile($_[1]) },
			'clean-packages-cache|c', sub { $options->{'cleanPackagesCache'} = 1 },
			'skip-packages-update|a', sub { $options->{'skipPackagesUpdate'} = 1 },
			'debug|d', sub { $options->{'debug'} = 1 },
			'help|?|h', sub { $showUsage->() },
			@_,
		) || $showUsage->(1);
	};

	undef;
}

=item parseNoDefault($usage)

 This class method parses command line options in @ARGV with GetOptions from Getopt::Long. Default options are excluded.

 The first parameter should be basic usage text for the program in question. Any following parameters are passed to
to GetOptions.

 Return undef

=cut

sub parseNoDefault
{
	my ($class, $usage) = (shift, shift);

	$showUsage = sub {
		my $exitCode = shift || 0;
		print STDERR wrap('', '', <<EOF);
$usage
 -?,-h  --help          Show this help.

EOF
		debugRegisterCallBack(sub { exit $exitCode; });
		exit $exitCode;
	};

	# Do not load Getopt::Long if not needed
	return unless grep { $_ =~ /^-/ } @ARGV;

	local $SIG{__WARN__} = sub {
		my $error = shift;
		$error =~ s/(.*?) at.*/$1/;
		print STDERR wrap('', '', $error) if $error ne "Died\n";
	};

	require Getopt::Long;

	Getopt::Long::Configure('bundling');

	eval {
		Getopt::Long::GetOptions(
			'help|?|h', sub { $showUsage->() },
			@_,
		) || $showUsage->(1);
	};

	undef;
}

=item showUsage($exitCode)

 Show usage

 Param int $exitCode OPTIONAL Exit code
 Return undef

=cut

sub showUsage
{
	my ($class, $exitCode) = @_;

	$exitCode //= 1;

	if(ref $showUsage eq 'CODE') {
		$showUsage->($exitCode);
	} else {
		die('ShowUsage() is not defined');
	}

	undef;
}

our $reconfigurationItems = [
	'all', 'servers', 'httpd', 'mta', 'mailfilters', 'po', 'ftpd', 'named', 'sql', 'hostnames', 'system_hostname',
	'panel_hostname', 'panel_ports', 'ips', 'admin', 'php', 'panel_ssl', 'services_ssl', 'ssl', 'backup', 'webstats',
	'sqlmanager', 'webmails', 'filemanager', 'antirootkits'
];

=item reconfigure($value = 'none')

 reconfigure option

 Param string $value OPTIONAL Option value
 Return string Name of item to reconfigure or none

=cut

sub reconfigure
{
	my ($class, $value) = @_;

	if(defined $value) {
		if($value eq 'help') {
			$optionHelp .= "Without any argument, the --reconfigure option allows to reconfigure all items.";
			$optionHelp .= " You can reconfigure a specific item by passing it name as argument.\n\n";
			$optionHelp .= " Available items are:\n\n";
			$optionHelp .=  ' ' . (join '|', @{$reconfigurationItems});
			die();
		} elsif($value eq '') {
			$value = 'all';
		}

		$value eq 'none' || $value ~~ $reconfigurationItems or die(
			"Error: '$value' is not a valid argument for the --reconfigure option."
		);

		$options->{'reconfigure'} = $value;
	}

	$options->{'reconfigure'} ||= 'none';
}

=item noprompt($value = 0)

 noprompt option

 Param string $value OPTIONAL Option value
 Return int 0 or 1

=cut

sub noprompt
{
	my ($class, $value) = @_;

	$options->{'noprompt'} = $value if defined $value;
	$options->{'noprompt'} // 0;
}

=item preseed($value = '')

 preseed option

 Param string $value OPTIONAL Option value
 Return string Path to preseed file or empty string

=cut

sub preseed
{
	my ($class, $value) = @_;

	if(defined $value) {
		if( -f $value) {
			$options->{'preseed'} = $value;
		} else {
			die("Preseed file not found: $value");
		}
	}

	$options->{'preseed'} // '';
}

=item listener($value = '')

 listener option

 Param string $value OPTIONAL Option value
 Return string Path to listener file or empty string

=cut

sub listener
{
	my ($class, $value) = @_;

	if(defined $value) {
		if( -f $value) {
			$options->{'listener'} = $value;
		} else {
			die("Listener file not found: $value")
		}
	}

	$options->{'listener'} // '';
}

=back

=head1 FIELDS

 Mutator/Accessor for all other fields (which have not their own mutator/accessor methods)

 Return mixed Field value if defined or empty string;

=cut

sub AUTOLOAD
{
	(my $field = our $AUTOLOAD) =~ s/.*://;
	my $class = shift;

	$options->{$field} = shift if @_;

	$options->{$field} // '';
}

=back

=head1 AUTHOR

 Laurent Declercq <l.declercq@nuxwin.com>

=cut

1;
__END__
