package Dirvish::Build;
use Module::Build;
@ISA = qw(Module::Build);

       sub ACTION_build {
	 my $self = shift;
	 $self->SUPER::ACTION_build;

	 my $destdir = $self->{properties}{destdir};
	 $destdir = '' unless defined $destdir;

	 my $installdirs = $self->{properties}{installdirs};
	 my $installprefix = $self->{config}{$installdirs . 'prefix'};
	 print Data::Dumper->Dump([$self->{config}]);

	 $self->do_system('./configure', ("--prefix=$destdir$installprefix"));
       }

       sub ACTION_install {
	 my $self = shift;
	 $self->SUPER::ACTION_install;

	 $self->do_system('make', ("install"));
       }
     
1;
