# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package
#
# Copyright 2001-2009 by Wilson Snyder.  This program is free software;
# you can redistribute it and/or modify it under the terms of either the GNU
# Lesser General Public License or the Perl Artistic License.

require 5.005;
use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
    q{
DIST_DEFAULT += manifest

README: readme.texi
	-$(RM_RF) $@
	makeinfo $< --output $@ --no-headers --no-validate

## Maintainer use:
preexist:
	svnorcvs nexists $(DISTNAME)_$(VERSION_SYM)
	test -s README

tag:
	svnorcvs tag  $(DISTNAME)_$(VERSION_SYM)

maintainer-diff:
	svnorcvs diff $(DISTNAME)_$(VERSION_SYM)

maintainer-dist: README preexist dist tag
	svnorcvs release $(DISTVNAME).tar.gz

maintainer-clean: distclean
	-$(RM_RF) README

maintainer-copy: README

clean::
	-$(RM_RF) test_dir MANIFEST.bak Makefile.old
};
}

WriteMakefile(
	      VERSION_FROM => 'lib/Log/Detect.pm',
	      DISTNAME  => 'Log-Detect',
	      NAME      => 'Log::Detect',
	      AUTHOR	=> 'Wilson Snyder <wsnyder@wsnyder.org>',
	      ABSTRACT  => 'Parse logfiles to detect errors',
	      EXE_FILES => [qw(vtrace)],
	      PREREQ_PM => {'IO::Zlib' => 1.01,
			    'Compress::Zlib' => 1.16,	# Needed by IO::Zlib, but I hate deps under deps!
			    'Pod::Usage' => 0,
			    'Text::Wrap' => 0,
			},
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz',
			    DIST_DEFAULT => 'README all tardist',
			},
	      );

