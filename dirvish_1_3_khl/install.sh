#! /bin/sh

###  This will be replaced with Makefile.pl , make 
###  KHL
###

case `echo "testing\c"; echo 1,2,3`,`echo -n testing; echo 1,2,3` in
	*c*,-n*) ECHO_N= ECHO_C='
' ECHO_T='      ' ;;
  *c*,*  ) ECHO_N=-n ECHO_C= ECHO_T= ;;
  *)       ECHO_N= ECHO_C='\c' ECHO_T= ;;
esac

EXECUTABLES="dirvish dirvish-runall dirvish-expire dirvish-locate"
MANPAGES="dirvish.8 dirvish-runall.8 dirvish-expire.8 dirvish-locate.8"
MANPAGES="$MANPAGES dirvish.conf.5"

while :
do
	PERL=`which perl`
	if [ -z "$PERL" ]
	then
		PERL=/usr/bin/perl
	fi
	echo $ECHO_N "perl to use ($PERL) $ECHO_C"
	read ans
	if [ -n "$ans" ] 
	then
		PERL="$ans"
	fi

	until [ -n "$PREFIX_OK" ]
	do
		EXECDIR="/usr/sbin"
		CONFDIR="/etc/dirvish"
		MANDIR="/usr/share/man"

		echo $ECHO_N "What installation prefix should be used? ($PREFIX) $ECHO_C"
		read ans
		if [ -n "$ans" ] 
		then
			PREFIX="$ans"
			if [ "$PREFIX" == "/" ]
			then
				PREFIX=""
			fi
		fi
		if [ -n "$PREFIX" -a  ! -d "$PREFIX" ]
		then
			echo $ECHO_N "$PREFIX doesn't exist, create it? (n) $ECHO_C"
			read ans
			if [ `expr "$ans" : '[yY]'` -ne 0 ]
			then
				CREATE_PREFIX="$PREFIX directory will be created"
				PREFIX_OK="yes"
			else
				continue
			fi
		else
			PREFIX_OK="yes"
		fi

		if [ -d "$PREFIX/sbin" ]
		then
			BINDIR=$PREFIX/sbin
		else
			BINDIR=$PREFIX/bin
		fi

		if [ -d "$PREFIX/share/man" ]
		then
			MANDIR=$PREFIX/share/man
		elif [ -d "$PREFIX/usr/share/man" ]
		then
			MANDIR=$PREFIX/usr/share/man
		elif [ -d "$PREFIX/usr/man" ]
		then
			MANDIR="$PREFIX/usr/man" ]
		else
			MANDIR=$PREFIX/man
		fi
		if [ `expr "$PREFIX" : '.*dirvish.*'` -gt 0 ]
		then
			CONFDIR="$PREFIX/etc"
		else
			CONFDIR="/etc/dirvish"
		fi
	done


	echo $ECHO_N "Directory to install executables? ($BINDIR) $ECHO_C"
	read ans
	if [ -n "$ans" ] 
	then
		BINDIR="$ans"
	fi

	echo $ECHO_N "Directory to install MANPAGES? ($MANDIR) $ECHO_C"
	read ans
	if [ -n "$ans" ] 
	then
		MANDIR="$ans"
	fi

	echo $ECHO_N "Configuration directory ($CONFDIR) $ECHO_C"
	read ans
	if [ -n "$ans" ] 
	then
		CONFDIR="$ans"
	fi

	cat <<EOSTAT

Perl executable to use is $PERL
Dirvish executables to be installed in $BINDIR
Dirvish manpages to be installed in $MANDIR
Dirvish will expect its configuration files in $CONFDIR

$CREATE_PREFIX

EOSTAT

	echo $ECHO_N "Is this correct? (no/yes/quit) $ECHO_C"
	read ans
	if [ `expr "$ans" : '[qQ]'` -ne 0 ]
	then
		exit
	elif [ `expr "$ans" : '[yY]'` -ne 0 ]
	then
		break
	fi
done

HEADER="#!$PERL

\$CONFDIR = \"$CONFDIR\";

"

for f in $EXECUTABLES
do
	echo "$HEADER" >$f
	cat $f.pl >>$f
	cat loadconfig.pl >>$f
	chmod 755 $f
done

echo
echo "Executables created."
echo

echo $ECHO_N "Install executables and manpages? (no/yes) $ECHO_C"
read ans
if [ `expr "$ans" : '[yY]'` -ne 0 ]
then
	echo
	if [ -n "$CREATE_PREFIX" ]
	then
		mkdir -p "$PREFIX"
	fi
	if [ ! -d $BINDIR ]
	then
		if [ -z "$CREATE_PREFIX" -o `expr "$BINDIR" : "$PREFIX"` -ne `expr "$PREFIX" : '.*'` ]
		then
			echo "$BINDIR doesn't exist, creating"
		fi
		mkdir -p "$BINDIR"
	fi
	if [ ! -d $MANDIR ]
	then
		if [ -z "$CREATE_PREFIX" -o `expr "$MANDIR" : "$PREFIX"` -ne `expr "$PREFIX" : '.*'` ]
		then
			echo "$MANDIR doesn't exist, creating"
		fi
		mkdir -p "$MANDIR"
	fi

	if [ ! -d "$CONFDIR" ]
	then
		mkdir -p "$CONFDIR"
	fi

	for f in $EXECUTABLES
	do
		echo "installing $BINDIR/$f"
		cp $f $BINDIR/$f
		chmod 755 $BINDIR/$f
	done
	for f in $MANPAGES
	do
		s=`expr "$f" : '.*\(.\)$'`
		if [ ! -d "$MANDIR/man$s" ]
		then
			mkdir -p "$MANDIR/man$s"
		fi
		echo "installing $MANDIR/man$s/$f"
		cp $f $MANDIR/man$s/$f
		chmod 644 $MANDIR/man$s/$f
	done
	echo
	echo "Installation complete"
fi

echo $ECHO_N "Clean installation directory? (no/yes) $ECHO_C"
read ans
if [ `expr "$ans" : '[yY]'` -ne 0 ]
then
	for f in $EXECUTABLES
	do
		rm $f
	done
	echo "Install directory cleaned."
fi
