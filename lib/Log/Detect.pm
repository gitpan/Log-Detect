# Log::Detect - Detect errors in logfiles
# $Revision: #10 $$Date: 2004/01/27 $$Author: wsnyder $
# Author: Wilson Snyder <wsnyder@wsnyder.org>
######################################################################
#
# Copyright 2001-2004 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# General Public License or the Perl Artistic License.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
######################################################################

package Log::Detect;
use Text::Wrap;
use IO::File;
use IO::Zlib;
use Class::Struct;
use Carp;

use Log::Delayed;
use strict;
use vars qw($VERSION %Default_Params);

$VERSION = '1.414';

(my $prog = $0) =~ s/^.*\///;

%Default_Params =
    ( dino => undef,
      program => $prog,
      time_regexp => qr/\[([0-9 ]+)\]/,	# Regexp to extract time in $1
      warn_fatal => 1,
      warn_finish => 0,
      regexps =>
      [
       # Action => qr/REGEXP/,
       warning => qr/Stopping due to warnings/i,  # Actually a warning, not error, so first
       error   => qr/(?i)%E|\bError ?[:!-\#]|Fatal ?[:!-]|\] Error [0-9]/,
       error   => qr!aborted due to compilation errors!,	# Perl
       warning => qr/%W/i,
       warning => qr/\bWarning ?[:!-\#]/i,
       finish  => qr/\*-\* All Finished \*-\*/,
       ],
      );

######################################################################
#### Creation

sub new {
    my $class = shift;
    my $self = {_lines => [],
		%Default_Params};
    bless $self, $class;
    $self->set (@_);
    return $self;
}

sub set {
    my $self = shift;
    while (@_) {
	my $param = shift; my $value = shift;
	(exists $self->{$param}) or confess ("%Error: $param isn't valid Log::Detect member variable, stopped");
	$self->{$param} = $value;
    }
}

sub add_regexp {
    my $self = shift;
    my $numargs = $#_+1;
    return if ($numargs <= 0);
    confess("%Error:  Cannot call add_regexp() with an odd number of arguments ($numargs)!") if ($numargs % 2);
    unshift @{$self->{regexps}}, @_;
}

######################################################################
#### Reading Functions

sub read {
    my $self = shift;
    my %params = (%{$self},
		  @_);

    my $filename = $params{filename};
    defined $filename or croak "%Error: No filename=> specified, stopped";
    $self->{filename} = $filename;

    my @regexps = @{$params{regexps}};

    my $fh;
    if ($filename =~ m/\.gz$/) {
	$fh = IO::Zlib->new();
    } else {
	$fh = IO::File->new();
    }
    $fh->open($filename, "r") or die "%Error: $! $filename\n";
  line:
    while (my $line = $fh->getline()) {
	next if ($line =~ /^\s*$/m);	# Short circuit
	for (my $i=0; $i<=$#regexps; $i+=2) {
	    my $re = $regexps[$i+1];
	    if ($line =~ /$re/) {
		my $action = $regexps[$i]; 
		next line if $action eq "ignore";
		#print "MATCH: $action  $line\n" if $Debug;
		my $actref = [$., $filename, $action, $line];
		bless $actref, 'Log::Detect::Action';
		push @{$self->{_lines}}, $actref;
		next line;
	    }
	}
    }
    $fh->close;
    #use Data::Dumper; print Dumper($self);
}

######################################################################
#### Accessors

sub actions {
    my $self = shift;
    return @{$self->{_lines}};
}

sub filename {
    $_[0]->{filename} = $_[1]  if ($#_ > 0);
    return $_[0]->{filename};
}

sub actions_sorted_line {
    my $self = shift;
    #We currently add to the array in sorted order, so...
    return @{$self->{_lines}};
    #return (sort {$a->lineno() <=> $b->lineno()}
    #        @{$self->{_lines}});
}

######################################################################
#### Result Functions

sub write_stderr {
    my $self = shift;
    my ($stat,$sum) = $self->summary();
    if (defined $sum) {
	print STDERR $sum;
    }
}

sub write_append {
    my $self = shift;
    my %params = (%{$self},
		  @_);

    my $filename = $params{filename};
    defined $filename or croak "%Error: No filename=> specified, stopped";

    my @regexps = @{$params{regexps}};

    my ($stat,$sum) = $self->summary();
    if (defined $sum) {
	my $fh = new IO::File;
	$fh->open (">>$filename") or die "%Error: $! $filename\n";
	print $fh $sum;
	$fh->close();
    }
}

sub summary {
    my $self = shift;
    # Return (message, lines with errors).
    # Returns UNDEF if no errors
    my @out = ();
    my $first_error;
    my $first_warn;
    my $first_finish;
    foreach my $actref ($self->actions_sorted_line()) {
	$first_error = $actref if (!$first_error && $actref->action() eq 'error');
	$first_warn  = $actref if (!$first_warn && $actref->action() eq 'warning');
	$first_finish = $actref if (!$first_finish && $actref->action() eq 'finish');
	if ($actref->action eq 'error' || $actref->action eq 'warning') {
	    push @out, $actref->text;
	}
    }

    my $result_message = undef;
    if ($first_error) {
	unshift @out, $self->{program}.": Stopped, Errors detected in $self->{filename}:\n";
	$result_message = $first_error->text();
    } elsif ($first_warn) {
	if ($self->{warn_fatal}) {
	    unshift @out, $self->{program}.": Stopped, Warnings detected in $self->{filename}:\n";
	    $result_message = $first_warn->text();
	} else {
	    unshift @out, $self->{program}.": Warnings detected in $self->{filename}:\n";
	}
    } elsif (!$first_finish && $self->{warn_finish}) {
	unshift @out, $self->{program}.": Stopped, Missing all-finished in $self->{filename}\n";
	$result_message = "Missing all-finished";
    }
    return (undef,undef) if ($#out < 0);

    unshift @out, "\n".("-"x70)."\n";
    return ($result_message, (join '',@out));
}

sub write_dino {
    my $self = shift;
    my %passed_params = (@_);
    my %params = (error_color => 2,
		  warning_color => 7,
		  %{$self},
		  @_);
    local $Text::Wrap::columns = 50;

    my $filename = $passed_params{filename} || $params{dino};
    defined $filename or croak "%Error: No filename=> specified, stopped";
    my $fh = IO::File->new (">$filename") or croak "%Error: $! $filename\n";

    print $fh "# Dinotrace\n";
    print $fh "# Created automagically on ", (scalar(localtime)), " by ";
    print $fh '$Revision: #10 $$Date: 2004/01/27 $$Author: wsnyder $ ', "\n";

    print $fh "\n";
    print $fh "# Error/Warning cursors\n";
    # Add in reverse order so earlier messages overwrite later
    foreach my $actref (reverse ($self->actions_sorted_line())) {
	my $text = $actref->text;
	chomp $text;
	my $comment = $text;
	$comment =~ /$params{time_regexp}/;
	my $time = $1 || 0;
	my $color = ((  ($actref->action() eq 'error') && $params{error_color})
		     ||(($actref->action() eq 'warning') && $params{warning_color})
		     );
	print $fh "#$text\n";
	$comment =~ s/\s+/ /g;
	$comment = Text::Wrap::wrap ('','',$comment);
	$comment =~ s/\n/\\n/g;	# Use \n for newlines
	$comment =~ s/\"/\\\"/g;	# Quote the quotes
	if ($time && $color) {
	    print $fh "cursor_add $time $color \"$comment\"\n";
	}
	print $fh "\n";
    }
    print $fh "\n";
    $fh->close();
}

######################################################################
######################################################################
######################################################################
#### Action class

struct('Log::Detect::Action'
       # read() requires this order; for speed it doesn't call new
       =>[lineno     	=> '$', #'	# Line number from
	  filename 	=> '$', #'	# Filename this came from
	  action 	=> '$', #'	# Action decoded
	  text		=> '$', #'	# Text on that line
	  ]);

######################################################################
#### Package return
1;
__END__

=pod

=head1 NAME

Log::Detect - Read logfiles to detect error and warning messages

=head1 SYNOPSIS

use Log::Detect;
my $d = new Log::Detect ();
$d->read(filename=>"test_dir/test.log");
$d->write_stdout();
$d->write_append();

=head1 DESCRIPTION

Log::Detect is used to read logfiles, and apply regexps to determine if the
logfile contains any errors or warning messages.  This is generally useful
for those programs that refuse to return bad exit status when they should.

Log::Detect can also append a summary of all errors and warnings to the
logfile, to a different file, or to the screen.

=head1 VARIABLES

These variables may be specified with the new function, or with the set
function.  Most member functions also accept any of these variables when
they are called.

=over 4

=item dino

The default filename for write_dino.

=item program

The name of the program to prepend to error messages.  Defaults to $0.

=item time_regexp

A regexp where $1 returns the timestamp.  Used by write_dino only.

=item warn_fatal

If true, warnings are considered fatal errors.  Defaults true.

=item warn_finish

If true, lack of a regexp matching 'finish' is considered fatal.

=item regexps

A list of actions and regular expressions.  The regexps are matched
against the text in order, with the first match action determining
the result.

For example, the default:
      [warning => qr/Stopping due to warnings/i,
       error   => qr/(?i)%E|\bError ?[:!-]|Fatal ?[:!-]|\] Error [0-9]/,
       warning => qr/%W/i,
       warning => qr/\bWarning ?[:!-]/i,
       finish  => qr/\*-\* All Finished \*-\*/,
       ],

Specifies that a line matching "stopping due to warnings" is a warning, as
is any line with %W (VMS's error messages).  A %E on a matching line is
signaled as an error.  As the rules are done in order, if the file has the
line '%E stopping due to warnings', which matches both the "%E" and the
"stopping due to warnings" regexps, the first match wins, and thus the
action indicates a warning, not an error.

=back

=head1 FUNCTIONS

=over 4

=item $det->actions

Returns the list of parsed actions.  Each list element is a reference to a
Log::Detect::Action, which has four accessor functions.  lineno is the line
number the message was detected on.  filename is the file the error came
from.  action is the action specified with the regexp.  text is the line
itself.

=item $det->actions_sorted_line

Returns the parsed actions, sorted by line number.

=item $det->add_regexp

Prepends new rules to the regexp list.

=item $det->new

Constructs the class.  Any variables described above may be passed to the
constructor.

=item $det->read

read parses the logfile specified with filename=>.  Each line is compared
against the regular expressions in turn, forming a list of actions.

=item $det->set

set takes a named parameter list and sets those variables.

=item $det->summary

summary returns a two element list.  The first element is a text message
describing if errors or warnings were found.  The second contains the text
lines from the file which had errors or warnings.

=item $det->write_append

write_append appends to a file, by default the same exact logfile, any
errors or warnings that were found.

=item $det->write_dino

write_dino prints to a file Dinotrace annotations for any errors or
warnings that were found in the logfile.

=item $det->write_stderr

write_stderr prints to the screen any errors or warnings that
were found in the logfile.

=back

=head1 SEE ALSO

L<Log::Delayed>

=head1 DISTRIBUTION

The latest version is available from CPAN and from C<http://veripool.com/>.

=head1 AUTHORS

Wilson Snyder <wsnyder@wsnyder.org>

=cut
