# $Revision: #10 $$Date: 2003/08/12 $$Author: wsnyder $
# DESCRIPTION: Perl ExtUtils: Type 'perl Makefile.PL' to create a Makefile for this package

require 5.005;
use ExtUtils::MakeMaker;
use Carp;

sub MY::postamble {
"
DIST_DEFAULT += manifest

README: readme.texi
	-rm \$@
	makeinfo \$< --output \$@ --no-headers --no-validate

maintainer-dist: dist tag
	cp \$(DISTVNAME).tar.gz \$(HOME)/src/kits
	mv \$(DISTVNAME).tar.gz \$(HOME)/backpack

maintainer-clean: distclean
	-rm README vtrace

maintainer-copy: README

tag:
	p4 label -d     \$(DISTNAME)_\$(VERSION_SYM) || true
	p4 label        \$(DISTNAME)_\$(VERSION_SYM)
	p4 labelsync -l \$(DISTNAME)_\$(VERSION_SYM) ...
#	cvs tag -F \$(DISTNAME)_\$(VERSION_SYM) .

clean::
	-rm -rf test_dir
";
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
			},
	      'dist'    => {COMPRESS => 'gzip -9f',
			    SUFFIX   => '.gz', 
			    DIST_DEFAULT => 'README all tardist',
			},
	      );

