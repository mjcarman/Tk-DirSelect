#===============================================================================
# Tk/DirSelect.pm
# Copyright (C) 2000-2001 Kristi Thompson   <kristi@kristi.ca>
# Copyright (C) 2002-2004 Michael J. Carman <mjcarman@mchsi.com>
# Last Modified: 5/21/2004 11:08AM
#===============================================================================
# This is free software under the terms of the Perl Artistic License.
#===============================================================================
BEGIN { require 5.004 }

package Tk::DirSelect;
use Cwd;
use Tk 800;
require Tk::Frame;
require Tk::BrowseEntry;
require Tk::Button;
require Tk::Label;
require Tk::DirTree;

use strict;
use base 'Tk::Toplevel';
Construct Tk::Widget 'DirSelect';

use vars qw'$VERSION';
$VERSION = '1.07';

my %colors;
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

	# Get system colors from a Text widget for use in DirTree
	my $t = $mw->Text();
	foreach my $x (qw'-background -selectbackground -selectforeground') {
		$colors{$x} = $t->cget($x);
	}
	$t->destroy();
}


#-------------------------------------------------------------------------------
# Subroutine : Populate()
# Purpose    : Create the DirSelect widget
# Notes      : 
#-------------------------------------------------------------------------------
sub Populate {
	my ($w, $args) = @_;
	my $directory  = delete $args->{-dir}   || cwd();
	my $title      = delete $args->{-title} || 'Select Directory';

    $w->withdraw;
	$w->SUPER::Populate($args);
	$w->ConfigSpecs(-title => ['METHOD', 'title', 'Title', $title]);
	$w->bind('<Escape>', sub { $w->{dir} = undef });

	my %f = (
		drive  => $w->Frame->pack(-anchor => 'n', -fill => 'x'),
		button => $w->Frame->pack(-side => 'bottom', -anchor => 's', -fill => 'x', -ipady  => 6),
		tree   => $w->Frame->pack(-fill => 'both', -expand => 1),
	);

	$w->{tree} = $f{tree}->Scrolled('DirTree',
		-scrollbars       => 'osoe',
		-selectmode       => 'single',
		-ignoreinvoke     => 0,
		-width            => 50,
		-height           => 15,
		%colors,
		%$args,
	)->pack(-fill => 'both', -expand => 1);

	$w->{tree}->configure(-command   => sub { $w->{tree}->opencmd($_[0]) });
	$w->{tree}->configure(-browsecmd => sub { $w->{tree}->anchorClear });

	$f{button}->Button(
		-width   => 7,
		-text    => 'OK',
		-command => sub { $w->{dir} = $w->{tree}->selectionGet() },
	)->pack(-side => 'left', -expand => 1);

	$f{button}->Button(
		-width   => 7,
		-text    => 'Cancel',
		-command => sub { $w->{dir} = undef },
	)->pack(-side => 'left', -expand => 1);

	if ($isWin32) {
		$f{drive}->Label(-text => 'Drive:')->pack(-side => 'left');
		$w->{drive} = $f{drive}->BrowseEntry(
			-variable  => \$w->{selected_drive},
			-browsecmd => [\&_browse, $w->{tree}],
			-state     => 'readonly',
		)->pack(-side => 'left', -fill => 'x', -expand => 1);
	}
	else {
		$f{drive}->destroy;
	}
	return $w;
}


#-------------------------------------------------------------------------------
# Subroutine : Show()
# Purpose    : Display the DirSelect widget.
# Notes      : 
#-------------------------------------------------------------------------------
sub Show {
	my $w     = shift;
	my $cwd   = cwd();
	my $dir   = shift || $cwd;
	my $focus = $w->focusSave;
	my $grab  = $w->grabSave;

	chdir($dir);

	if ($isWin32) {
		# populate the drive list
		my @drives = _get_volume_info();
		$w->{drive}->delete(0, 'end');
		my $startdrive = _drive($dir);

		foreach my $d (@drives) {
			$w->{drive}->insert('end', $d);
			if ($startdrive eq _drive($d)) {
				$w->{selected_drive} = $d;
			}
		}
	}

	# show initial directory
	_showdir($w->{tree}, $dir);

	$w->Popup();                  # show widget
	$w->focus;                    # seize focus
	$w->grab;                     # seize grab
	$w->waitVariable(\$w->{dir}); # wait for user selection (or cancel)
	$w->grabRelease;              # release grab
	$w->withdraw;                 # run and hide
	$focus->();                   # restore prior focus
	$grab->();                    # restore prior grab
	chdir($cwd)                   # restore working directory
		or warn "Could not chdir() back to '$cwd' [$!]\n";

	# HList SelectionGet() behavior changed around Tk 804.025
	if (ref $w->{dir} eq 'ARRAY') {
		$w->{dir} = $w->{dir}[0];
	}

	{
		local $^W;
		$w->{dir} .= '/' if ($isWin32 && $w->{dir} =~ /:$/);
	}

	return $w->{dir};
}


#-------------------------------------------------------------------------------
# Subroutine : _browse()
# Purpose    : Browse to a mounted filesystem (Win32)
# Notes      : 
#-------------------------------------------------------------------------------
sub _browse {
	my ($w, undef, $d) = @_;
	$d = _drive($d) . '/';
	chdir($d);
	_showdir($w, $d);
}


#-------------------------------------------------------------------------------
# Subroutine : _showdir()
# Purpose    : Show the requested directory
# Notes      : 
#-------------------------------------------------------------------------------
sub _showdir {
	my $w   = shift;
	my $dir = shift;
	$w->delete('all');
	$w->chdir($dir);
}


#-------------------------------------------------------------------------------
# Subroutine : _get_volume_info()
# Purpose    : Get volume information (Win32)
# Notes      : 
#-------------------------------------------------------------------------------
sub _get_volume_info {
	require Win32API::File;

	my @drivetype = (
		'Unknown',
		'No root directory',
		'Removable disk drive',
		'Fixed disk drive',
		'Network drive',
		'CD-ROM drive',
		'RAM Disk',
	);

	my @drives;
	foreach my $ld (Win32API::File::getLogicalDrives()) {
		my $drive = _drive($ld);
		my $type  = $drivetype[Win32API::File::GetDriveType($drive)];
		my $label;

		Win32API::File::GetVolumeInformation(
			$drive, $label, [], [], [], [], [], []);

		push @drives, "$drive  [$label] $type";
	}

	return @drives;
}


#-------------------------------------------------------------------------------
# Subroutine : _drive()
# Purpose    : Get the drive letter (Win32)
# Notes      : 
#-------------------------------------------------------------------------------
sub _drive {
	shift =~ /^(\w:)/;
	return uc $1;
}


1;

__END__
=pod

=head1 NAME

Tk::DirSelect - Cross-platform directory selection widget.

=head1 SYNOPSIS

  use Tk::DirSelect;
  my $ds  = $mw->DirSelect();
  my $dir = $ds->Show();

=head1 DESCRIPTION

This module provides a cross-platform directory selection widget. For 
systems running Microsoft Windows, this includes selection of local and 
mapped network drives.

=head1 METHODS

=head2 C<DirSelect([-title =E<gt> 'title'], [options])>

Constructs a new DirSelect widget as a child of the invoking object 
(usually a MainWindow). 

The title for the widget can be set by specifying C<-title =E<gt> 
'Title'>. Any other options provided will be passed through to the 
DirTree widget that displays directories, so be sure they're appropriate 
(e.g. C<-width>)

=head2 C<Show([directory])>

Displays the DirSelect widget and returns the user selected directory or 
C<undef> if the operation is canceled.

Takes one optional argument -- the initial directory to display. If not 
specified, the current directory will be used instead.

=head1 DEPENDENCIES

=over 4

=item * Perl 5.004

=item * Tk 800

=item * Win32API::File (under Microsoft Windows only)

=back

=head1 AUTHOR

Original author Kristi Thompson <kristi@kristi.ca>

Current maintainer Michael J. Carman <mjcarman@mchsi.com>

This is free software under the terms of the Perl Artistic License.

=cut
