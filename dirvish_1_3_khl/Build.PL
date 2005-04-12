#!/usr/bin/perl -w
# Build.PL Script for dirvish
# Version 0.3,  Keith Lofstrom,  2005-Apr-11
#
# This install file is neither complete nor well tested;  it is a
# placeholder to gather comments about my probable misuse of Module::Build . 
# I'm pretty sure I am doing a lot of things the hard way.
#
# Dirvish is installed with the following three step process:
#
#  ./Build.PL <options>
#  ./Build
#  ./Build install 
#
# The default install locations are given in the "install_path" hash.
# You can change these locations with options on the command line of
# Build.PL, for example:
#
#       --install_path share=/usr/local/share
#       --install_path sbin=/usr/local/sbin
#
# Because the "share" and the "config" locations are used as part of
# the re-writing of the dirvish application scripts, these must be
# set when Build.PL runs, meaning that the options cannot be added
# later in the process.

use strict                 ;
use Module::Build 0.26     ; # Debian will need to know about dependency
use Pod::Html              ;
use Pod::Man               ;

my $build = Module::Build->new (

   module_name  => 'dirvish',
   dist_version => '1.3.1',
   license      => 'open_source',
   create_makefile_pl => 'traditional',

   requires => {
      'perl'                => '>= 5.6.0',
   #  'File::chmod'         => '>= 0.31',
      'File::Find'          => 0,
      'Getopt::Long'        => 0,
      'Time::ParseDate'     => 0,
      'Time::Period'        => 0
   },

   install_path => { 
      conf                  => '/etc/dirvish',
      share                 => '/usr/share',
      sharedoc              => '/usr/share/doc',
      man5dir               => '/usr/share/man/man5',
      man8dir               => '/usr/share/man/man8',
      sbin                  => '/usr/sbin' 
   },

   admin_files => {
      'dirvish.8'           => 'man8dir/dirvish.8',
      'dirvish-locate.8'    => 'man8dir/dirvish-locate.8',
      'dirvish-expire.8'    => 'man8dir/dirvish-expire.8',
      'dirvish-runall.8'    => 'man8dir/dirvish-runall.8',
      'dirvish.conf.html'   => 'man5dir/dirvish.conf.html',
      'CHANGELOG'           => 'sharedoc/dirvish/CHANGELOG',
      'COPYING'             => 'sharedoc/dirvish/COPYING',
      'README'              => 'sharedoc/dirvish/README',
      'dirvish.html'        => 'sharedoc/dirvish.html',
      'dirvish-locate.html' => 'sharedoc/dirvish-locate.html',
      'dirvish-expire.html' => 'sharedoc/dirvish-expire.html',
      'dirvish-runall.html' => 'sharedoc/dirvish-runall.html',
      'dirvish.conf.5'      => 'sharedoc/dirvish.conf.5',
      'RELEASE.html'        => 'sharedoc/dirvish/RELEASE.html',
      'INSTALL.html'        => 'sharedoc/dirvish/INSTALL.html',
      'TODO.html'           => 'sharedoc/dirvish/TODO.html',
      'FAQ.html'            => 'sharedoc/dirvish/FAQ.html',
      'debian.howto.html'   => 'sharedoc/dirvish/debian.howto.html',
      'RELEASE.man'         => 'sharedoc/dirvish/RELEASE.man',
      'INSTALL.man'         => 'sharedoc/dirvish/INSTALL.man',
      'TODO.man'            => 'sharedoc/dirvish/TODO.man',
      'FAQ.man'             => 'sharedoc/dirvish/FAQ.man',
      'debian.howto.man'    => 'sharedoc/dirvish/debian.howto.man',
      'dirvishlib.pl'       => 'share/dirvish/dirvishlib.pl',
      'dirvish'             => 'sbin/dirvish',
      'dirvish-locate'      => 'sbin/dirvish-locate',
      'dirvish-expire'      => 'sbin/dirvish-expire',
      'dirvish-runall'      => 'sbin/dirvish-runall'
   }
);

#--------------------------------------------------------------------
# Modify the app files
#
# We need to add the location of the /config file/ and of the /library/
# to each application.  

my $library                 = 'dirvish.pl' ;

my %apps_to_modify = (
   'dirvish.PL'             => 'dirvish' ,
   'dirvish-expire.PL'      => 'dirvish-expire',
   'dirvish-locate.PL'      => 'dirvish-locate',
   'dirvish-runall.PL'      => 'dirvish-runall'
) ;

my  $conf  = $build->{properties}{install_path}{conf}       ;
my  $share = $build->{properties}{install_path}{share}  ;
my  $dat   = localtime ;

my @apps_header = (
   "#!/usr/bin/perl              \n",  #FIXME should this be config'ed?
   "#----------------------------\n",
   "#Configured by Module::Build \n",
   "#on $dat                     \n",
   "# these lines prepended by $0\n",
   "                             \n",
   "\$CONFDIR = $conf;           \n",
   "use        $share/$library;  \n",
   "#----------------------------\n"
);

while ( my ( $sourcefile, $targetfile ) = each  %apps_to_modify ) {
   open( SOURCEFILE, "<$sourcefile" )
      or die "$0: cannot open $sourcefile for reading, $!";
   open( TARGETFILE, ">$targetfile" )
      or die "$0: cannot open $targetfile for writing, $!";
   print TARGETFILE @apps_header ;  # copy header
   print TARGETFILE <SOURCEFILE> ;  # copy rest of file
   close( SOURCEFILE ) or die "$0 cannot close $sourcefile, $!";
   close( TARGETFILE ) or die "$0 cannot close $targetfile, $!";
}

$build->add_to_cleanup( values %apps_to_modify );

#--------------------------------------------------------------------
# make man pages out of pod files

my $parser  = Pod::Man->new( section => 1 );

my %pod_to_man = (
      'dirvish.pod'        => 'dirvish.8',
      'dirvish-locate.pod' => 'dirvish-locate.8',
      'dirvish-expire.pod' => 'dirvish-expire.8',
      'dirvish-runall.pod' => 'dirvish-runall.8',
      'dirvish.conf.pod'   => 'dirvish.conf.5',
      'RELEASE.pod'        => 'RELEASE.man',
      'INSTALL.pod'        => 'INSTALL.man',
      'TODO.pod'           => 'TODO.man',
      'FAQ.pod'            => 'FAQ.man',
      'debian.howto.pod'   => 'debian.howto.man'
);

while ( my ( $sourcefile, $targetfile ) = each  %pod_to_man ) {
   # print "$sourcefile ---> $targetfile\n";
   $parser->parse_from_file( $sourcefile, $targetfile );
};

$build->add_to_cleanup( values %pod_to_man );

#--------------------------------------------------------------------
# make html pages out of pod files

my %pod_to_html = (
      'dirvish.pod'        => 'dirvish.html',
      'dirvish-locate.pod' => 'dirvish-locate.html',
      'dirvish-expire.pod' => 'dirvish-expire.html',
      'dirvish-runall.pod' => 'dirvish-runall.html',
      'dirvish.conf.pod'   => 'dirvish.conf.html',
      'RELEASE.pod'        => 'RELEASE.html',
      'INSTALL.pod'        => 'INSTALL.html',
      'TODO.pod'           => 'TODO.html',
      'FAQ.pod'            => 'FAQ.html',
      'debian.howto.pod'   => 'debian.howto.html'
);

while ( my ( $sourcefile, $targetfile ) = each  %pod_to_html ) {
   # print "$sourcefile ---> $targetfile\n";
   Pod::Html::pod2html(
      "--title=dirvish",
      "--infile=$sourcefile",
      "--outfile=$targetfile",
   );
};

$build->add_to_cleanup( values %pod_to_html );


# for some reason there are left over files called pod2htm*, delete them

unlink <pod2htm*> ;

#--------------------------------------------------------------------
# move the files into appropriate places in blib

$build->add_build_element('admin');

#-----------------------------------------------
# make the Build script

$build->create_build_script;
