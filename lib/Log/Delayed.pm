# Log::Delayed - Delayed error handling
# $Revision: #6 $$Date: 2003/09/04 $$Author: wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# This program is Copyright 2000 by Wilson Snyder.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the GNU General Public License or the
# Perl Artistic License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# If you do not have a copy of the GNU General Public License write to
# the Free Software Foundation, Inc., 675 Mass Ave, Cambridge, 
# MA 02139, USA.
######################################################################

package Log::Delayed;
require Exporter;
use IO::File;
use Carp;

use strict;
use vars qw($VERSION $Global_Delayed @ISA @EXPORT $Debug);

@ISA = qw(Exporter);
@EXPORT = qw(die_delayed);

$VERSION = '1.413';

######################################################################
#### Traps

END {
    # Called whenever perl exits.
    return if !$Global_Delayed;
    sig_end ($Global_Delayed);
}

######################################################################
#### Creation

sub new {
    my $class = shift;
    my $self = {errors => 0,
		filename => ".status",
		status => "Completed\n",	# Set to undef if will call completed() later.
		overwrite => 1,
		global => 1,
		@_};
    bless $self, $class;
    $self->{status} = "%Error: Missing Completed\n" if !defined $self->{status};
    $self->{_noerror_status} = $self->{status};
    if ($self->{global}) {
	$Global_Delayed = $self;
	$SIG{__DIE__} = \&sig_die;
    }
    # Remove the file before we start; in case of a fatal error we don't
    # want a bad "Completed" message in it.
    unlink $self->{filename} if ($self->{overwrite} && $self->{filename} && -r $self->{filename});
    return $self;
}

######################################################################
#### Signals

sub sig_end {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    $? = 10 if (!$? && $self->{errors});	# Exit with bad status if a error was detected
    $self->write_status() if $self->{filename};
}

sub sig_die {
    die @_ if $^S;
    return if !$Global_Delayed;
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    $self->die_delayed (@_);
    exit (20);
}

######################################################################
#### Accessors

sub completed {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    my $msg = "Completed\n";
    if ($#_ >= 0) {
	$msg = join('',@_);
    }
    if (!$self->errors) {
	$self->{status} = $msg;
	$self->{_noerror_status} = $self->{status};
	print "\tLog::Delayed::completed <= $msg\n" if $Debug;
    }
}

sub errors {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    if ($#_ >= 0) {
	$self->{errors} = shift;
	if (!$self->{errors}) {  # User cleared errors, so clear status too...
	    $self->{status} = $self->{_noerror_status};
	}
    }
    return $self->{errors};
}

sub status {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    # New apps should use errors(0) to clear errors, completed() to indicate completion
    # or die_delayed() to report errors instead of this function
    if ($#_ >= 0) {
	my $msg = join('',@_);
	$self->{status} = $msg;
	$self->{errors}++ if $msg ne "Completed\n";	# Back compatible, suggest completed instead for new apps.
	print "\tLog::Delayed::status <= $msg\n" if $Debug;
    }
    return $self->{status};
}

sub exit_if_error {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    #END handler will write the status file
    exit(10) if $self->{errors};
}

sub die_delayed {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    $self->{errors} ++;
    my $msg = join('',@_);
    warn $msg;
    if ($self->{errors} == 1) {
	$self->{status} = $msg;
    }
}

######################################################################
#### File

sub write_status {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    my %params = (%{$self},
		  @_);
    my $filename = $params{filename};
    defined $filename or croak "%Error: No filename=> specified, stopped";

    print "\tLog::Delayed::write_status\n" if $Debug;
    if ($params{overwrite} || (!-r $filename && $self->errors)) {
	my $fh = new IO::File (">$filename") or die "%Error: $! $filename\n";
	print $fh $params{status};
	$fh->close();
    }
}

sub read_status {
    my $self = (ref $_[0]) ? shift : $Global_Delayed;  # Allow method or global calling
    my %params = (%{$self},
		  @_);
    my $filename = $params{filename};
    defined $filename or croak "%Error: No filename=> specified, stopped";

    my $fh = new IO::File ($filename);
    return undef if ! $fh;
    my $wholefile = join('',$fh->getlines());
    $fh->close();

    return $wholefile;
}

######################################################################
#### Package return
1;
__END__

=pod

=head1 NAME

Log::Delayed - Delay error handling and write status file

=head1 SYNOPSIS

use Log::Delayed;
my $Delayed = new Log::Delayed (filename=>"test_dir/.status");

die_delayed ("First error into .status\n");

if ($Delayed->errors()) {
    print "We got a error\n";
}
$Delayed->errors(0);  # Clear errors

$Delayed->write_status();

my $current_status = $Delayed->read_status();

$Delayed->exit_if_error();

=head1 DESCRIPTION

Log::Delayed is used to delay error messages for later logging and exiting.
This is useful when parsing files and such, and multiple errors want to be
presented to the user before exiting the program.

In addition, Log::Delayed optionally makes a status file (.status), which
contains the first error detected.  This allows calling programs to be
passed more useful tracking information then just the shell exit status.

=head1 FUNCTIONS

=over 4

=item $dly->new

New creates a new Log::Delayed object.  Parameters are passed by named
form.  

The filename=> parameter specifies the file to be written with the exit
message, undef for none; defaults to .status.

The global=> boolean parameter forces the $dly->sig_end to be called
automatically at program exit, it defaults true.

The overwrite=> boolean parameter defaults to true to overwrite any
existing status file and write it even if there are no errors.  If
overwrite=> is clear, the status file will only be written with errors,
which is useful to detect the first error across many applications running
together.

The status=> string has the default status.  It defaults to "Completed" for
backward compatibility; new applications may wish to undef it and use the
completed() call instead.

=item $dly->completed

Call at the end of the normal execution flow to set the status to
"Completed\n".  Use with the status=>undef parameter in the new call.  This
allows the status file to indicate if the program didn't complete normally,
but also didn't report an error.  (Like from calling exit() insead of
die().)

=item $dly->die_delayed

Die_delayed prints any parameters on stderr, then records the error
occurrence for later error exiting.  If new was called with global=>1
parameter, the exported version of die_delayed may be called without any
object.

=item $dly->errors

Returns the number of errors seen.  With a parameter it sets the number of
errors seen.

=item $dly->exit_if_error

exit_if_error exits the program if any errors were detected.

=item $dly->read_status

read_status reads the filename=> specified with new or this function call.
It returns the contents of the file, or undef if no file exists.

=item $dly->sig_end

sig_end changes the exit status to be bad if any delayed errors were
detected, and calls write_status.  sig_end is called automatically by the
END{} handler if global=>1 was specified with the new constructor.

=item $dly->sig_die

sig_die records the first error it sees so that write_status will contain
perl related error messages.  sig_end is called automatically by the
%SIG{__DIE__} handler if global=>1 was specified with the new constructor.

=item $dly->write_status

write_status writes the filename=> specified with new or this function call
with the first error message detected, or "Completed\n" if there were no
errors.

=back

=head1 SEE ALSO

L<Log::Detect>, SIG{__DIE__} in L<perlvar>

=head1 DISTRIBUTION

The latest version is available from CPAN and from C<http://veripool.com/>.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut
