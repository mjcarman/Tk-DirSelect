#===============================================================================
# Tk/DirSelect.pm
# Copyright (C) 2000-2001 Kristi Thompson   <kristi@kristi.ca>
# Copyright (C) 2002-2004 Michael J. Carman <mjcarman@mchsi.com>
# Last Modified: 5/19/2004 10:42AM
#===============================================================================
# This is free software under the terms of the Perl Artistic License.
#===============================================================================
BEGIN { require 5.004 }

package Tk::DirSelect;
use Cwd;
use Tk::widgets qw'Frame BrowseEntry Button Label DirTree';
use strict;
use base 'Tk::Toplevel';
Construct Tk::Widget 'DirSelect';

use vars qw'$VERSION';
$VERSION = '1.03';

my %color;
my $isWin32;

#-------------------------------------------------------------------------------
# Subroutine : ClassInit()
# Purpose    : Class initialzation.
# Notes      : 
#-------------------------------------------------------------------------------
sub ClassInit {
	my ($class, $mw) = @_;
	$class->SUPER::ClassInit($mw);

	$isWin32 = $^O eq 'MSWin32';

	# Get system colors from Text widget to use in DirTree
	my $t = $mw->Text();
	foreach my $x (qw'-background -selectbackground -selectforeground') {
		$color{$x} = $t->cget($x);
	}
	$t->destroy();
}


#-------------------------------------------------------------------------------
# Subroutine : Populate()
# Purpose    : Create the DirSelect
# Notes      : 
#-------------------------------------------------------------------------------
sub Populate {
	my ($w, $args) = @_;
    $w->withdraw;
	$w->SUPER::Populate($args);
	$w->title('Select Directory');
	$w->bind('<Escape>', sub { $w->{dir} = undef });

	my $directory = delete $args->{-dir};

	# DirTree options; defaults + user specified
	my %args = (
		-width            => 50,
		-height           => 15,
		-background       => $color{-background},
		-selectbackground => $color{-selectbackground},
		-selectforeground => $color{-selectforeground},
		%$args,
	);

	my $top    = $w->Frame()->pack(-anchor => 'n', -fill => 'x');
	my $bottom = $w->Frame->pack(
		-side   => 'bottom',
		-anchor => 's',
		-fill   => 'x',
		-ipady  => 6,
	);
	my $mid = $w->Frame->pack(-fill => 'both', -expand => 1);

	$bottom->Button(
		-width   => 7,
		-text    => 'OK',
		-command => sub { $w->{dir} = $mid->packSlaves->selectionGet() },
	)->pack(
		-side   => 'left',
		-expand => 1,
	);
	$bottom->Button(
		-width   => 7,
		-text    => 'Cancel',
		-command => sub { $w->{dir} = undef },
	)->pack(
		-side   => 'left',
		-expand => 1,
	);

	if ($isWin32) {
		require Win32API::File;
		my @drives = map {_get_volume_info($_)} Win32API::File::getLogicalDrives();

		my ($startdir, $startdrive) = ($directory)
			? (_drive($directory), $directory)
			: (_drive(cwd), _drive(cwd));
		my $selcolor = $top->cget(-background);

		my $drvsel;
		$top->Label(-text => 'Drive:')->pack(-side => 'left');
		my $drive_be = $top->BrowseEntry(
			-variable  => \$drvsel,
			-choices   => \@drives,
			-browsecmd => [\&_browse, 0, $mid, \%args],
		)->pack(
			-side   => 'left',
			-fill   => 'x',
			-expand => 1,
		);
		$drive_be->configure(-state => 'readonly');

		foreach my $d (@drives) {
			if (lc $startdrive eq lc _drive($d)) {
				$drvsel = $d;
				_browse(1, $mid, \%args, undef, $startdir);
				last;
			}
		}
	}
	else {
		$top->destroy;
		my $d = $directory || '/';
		_dirtree($mid, $d, $args);
	}
	return $w;
}


#-------------------------------------------------------------------------------
# Subroutine : _browse()
# Purpose    : Browse to a mounted filesystem under Win32.
# Notes      : 
#-------------------------------------------------------------------------------
sub _browse {
	my $n = shift;
	my ($f, $args, undef, $d) = @_;
	$d = _drive($d);

	foreach ($f->packSlaves) { $_->packForget; }

	my $cwd = cwd();
	if (chdir($d)) {
		_dirtree($f, $d, $args);
	}
	chdir($cwd) or warn "Could not chdir() back to '$cwd' [$!]\n";
}


#-------------------------------------------------------------------------------
# Subroutine : _dirtree()
# Purpose    : Draw a DirTree widget in the DirSelect.
# Notes      : 
#-------------------------------------------------------------------------------
sub _dirtree {
	my $f    = shift;
	my $dir  = shift;
	my $args = shift;

	my $dt = $f->Scrolled('DirTree',
		-scrollbars       => 'osoe',
		-directory        => $dir,
		-selectmode       => 'browse',
		-ignoreinvoke     => 0,
		%$args,
	)->pack(-fill => 'both', -expand => 1);

	$dt->configure(-command   => sub { $dt->opencmd($_[0]) });
	$dt->configure(-browsecmd => sub { $dt->anchorClear });
}


#-------------------------------------------------------------------------------
# Subroutine : Show()
# Purpose    : Display the DirSelect widget.
# Notes      : 
#-------------------------------------------------------------------------------
sub Show {
	my $w     = shift;
	my $focus = $w->focusSave;
	my $grab  = $w->grabSave;

	$w->Popup(); # reappear
	$w->focus;   # seize focus
	$w->grab;    # seize grab
	$w->_wait;   # wait for user to do something
	$focus->();  # restore prior focus
	$grab->();   # restore prior grab

	{
		local $^W;
		if ($isWin32 && $w->{dir} =~ /:$/) {
			return("$w->{dir}/");
		}
		else {
			return($w->{dir});
		}
	}
}


#-------------------------------------------------------------------------------
# Subroutine : _wait()
# Purpose    : Wait for user selection or cancel.
# Notes      : 
#-------------------------------------------------------------------------------
sub _wait {
	my $w = shift;
	$w->waitVariable(\$w->{dir});
	$w->grabRelease;
	$w->withdraw;
	$w->Callback(-command => $w->{dir});
}


#-------------------------------------------------------------------------------
# Subroutine : _get_volume_info()
# Purpose    : Get volume information under Win32
# Notes      : 
#-------------------------------------------------------------------------------
sub _get_volume_info {
	my $d = _drive(shift);
	my $volumelabel;
	my @drivetype = (
		'Unknown',
		'No root directory',
		'Removable disk drive',
		'Fixed disk drive',
		'Network drive',
		'CD-ROM drive',
		'RAM Disk',
	);

	my $type = Win32API::File::GetDriveType($d);

	Win32API::File::GetVolumeInformation(
		$d, $volumelabel,
		[], [], [], [], [], []);

	return("$d  [$volumelabel] $drivetype[$type]");
}


#-------------------------------------------------------------------------------
# Subroutine : _drive()
# Purpose    : Get the drive letter under Win32.
# Notes      : 
#-------------------------------------------------------------------------------
sub _drive {
	shift =~ /^(\w:)/;
	return($1);
}


1;

__END__

=pod

=head1 Tk::DirSelect

Cross-platform directory selection widget.

=head1 SYNOPSIS

  use Tk::DirSelect;
  my $ds  = $mw->DirSelect([options]);
  my $dir = $ds->Show();

=head1 DESCRIPTION

This module provides a cross-platform directory selection widget. For systems 
running Microsoft Windows, this includes selection of local and mapped network 
drives.

Any options provided will be passed through to the DirTree widget.

=head1 AUTHOR

Original author Kristi Thompson <kristi@kristi.ca>
Current maintainer Michael J. Carman <mjcarman@mchsi.com>

=cut
