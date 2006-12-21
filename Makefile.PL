use 5.004;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Tk::DirSelect',
    'VERSION_FROM' => 'DirSelect.pm',
    'PREREQ_PM'    => {'Tk' => 800},
    ($] >= 5.005 ?
      (ABSTRACT_FROM => 'DirSelect.pm',
       AUTHOR        => 'Michael J. Carman <mjcarman@mchsi.com>') : ()),
);
