#!/bin/bash

function item_not_in_list {
  local item="$1"
  local list="$2"
  if [[ $list =~ (^|[[:space:]])"$item"($|[[:space:]]) ]]
  then  # item in list
      retval=1
  else # item not in list
      retval=0
  fi
  return $retval
}

function sudoer {
    local prompt
    retval=1
    prompt=$(sudo -nv 2>&1)
    if [ $? -eq 0 ]
    then
	retval=0
    elif echo $prompt | grep -q '^sudo:'
    then
	retval=0
    else
	retval=1
    fi
    return $retval
}

function user_exists {
    local prompt
    prompt=$(id "$1" 2>&1)
    return $?
}

function create_conda_user_if_needed {
    if [ "$USER" == "root" ]
    then
        if ! `user_exists conda`
        then
	    case $OS_NAME in
		"Linux")
		    `adduser --system --disabled-password --disabled-login --group conda`
		    ;;
		"MacOSX")
                    `sysadminctl -addUser conda -admin`
		    ;;
		*)
		    printf "WOOPS: Creating a 'conda' user is not implemented yet for $OS_NAME\\n"
		    ;;
	    esac
        fi
    fi
}

THIS_DIR=$(DIRNAME=$(dirname "$0"); cd "$DIRNAME"; pwd)
THIS_FILE=$(basename "$0")
THIS_PATH="$THIS_DIR/$THIS_FILE"
AUTO_PREFIX=true
HELP=0
BATCH=0
FORCE=0
SKIP_SCRIPTS=0
TEST=0
REINSTALL=0

SIZES="minimal nominal maximal"
SIZE_LIST=${SIZES// /|}
AUTO_SIZE=true

IMPLS="CPython PyPy"
IMPL_LIST=${IMPLS// /|}
AUTO_IMPL=true

# for now squash them all to Mini
MIN_SIZE_NAME="Mini"  # "Mini" resolves to eg : Miniforge3-4.8.3-4-Linux-aarch64.sh
NOM_SIZE_NAME="Mini"  # "Nomi" resolves to eg : Nomiforge3-4.8.3-4-Linux-aarch64.sh
MAX_SIZE_NAME="Mini"  # "Maxi" resolves to eg : Maxiforge3-4.8.3-4-Linux-aarch64.sh

if which getopt > /dev/null 2>&1; then
    OPTS=$(getopt x:i:bfhp:sut "$*" 2>/dev/null)
    if [ ! $? ]; then
	HELP=1
    fi

    eval set -- "$OPTS"

    while true; do
        case "$1" in
	    -x)
		if `item_not_in_list "$2" "$SIZES"`
		then
		    printf "ERROR: -x argument must be one of [$SIZE_LIST] and it is '$2'\\n"
		    exit 1
		else
		    SIZE="$2"
		    AUTO_SIZE=false
		    shift
		    shift
		fi
		;;
	    -i)
		if `item_not_in_list "$2" "$IMPLS"`
		then
		    printf "ERROR: -i argument must be one of [$IMPL_LIST] and it is '$2'\\n"
		    exit 1
		else
		    IMPL="$2"
		    AUTO_IMPL=false
		    shift
		    shift
		fi
		;;
	    -h)
		HELP=1
		shift
                ;;
            -b)
                BATCH=1
                shift
                ;;
            -f)
                FORCE=1
                shift
                ;;
            -p)
                PREFIX="$2"
		AUTO_PREFIX=false
                shift
                shift
                ;;
            -s)
                SKIP_SCRIPTS=1
                shift
                ;;
            -u)
                FORCE=1
                shift
		;;
            -t)
                TEST=1
                shift
                ;;
            --)
                shift
		break
                ;;
            *)
                printf "ERROR: did not recognize option '%s', please try -h\\n" "$1"
                exit 1
                ;;
        esac
    done
else
    while getopts "x:i:bfhp:sut" x; do
        case "$x" in
            x)
		printf "--> set size to %s" $OPTARG
                SIZE="$OPTARG"
                AUTO_SIZE=false
                ;;
            i)
		printf "--> set implementation to %s" $OPTARG
                IMPL="$OPTARG"
	        AUTO_IMPL=false
                ;;
	    h)
		HELP=1
		;;
            b)
                BATCH=1
                ;;
            f)
                FORCE=1
                ;;
            p)
                PREFIX="$OPTARG"
		AUTO_PREFIX=false
                ;;
            s)
                SKIP_SCRIPTS=1
                ;;
            u)
		FORCE=1
                ;;
            t)
                TEST=1
                ;;
            ?)
                printf "ERROR: did not recognize option '%s', please try -h\\n" "$x"
		exit 1
                ;;
        esac
    done
fi

### OS, CPU & USER ###
OS=`uname -s`
case $OS in
    "Linux")
        OS_NAME="Linux"
	SYS_HOME="/home"
        ;;
    "Darwin")
        OS_NAME="MacOSX"
	SYS_HOME="/Users"
        ;;
    *)
        printf "WOOPS: OS '%s' is not yet implemented...\\n" $OS
        exit 1
        ;;
esac
CPU=`uname -m`
case $CPU in
    "x86_64")
        CPU_NAME="x86_64"
        ;;
    "aarch64")
        CPU_NAME="aarch64"
        ;;
    *)
        printf "WOOPS: CPU '%s' is not yet implemented...\\n" $OS
        exit 1
        ;;
esac
USER=`whoami`
if [ "$USER" == "root" ]
then
    USERS="**ALL** users!"
else
    USERS="user '$USER'."
fi

### SIZE & PREFIX ###
if $AUTO_SIZE
then
    if [ "$USER" == "root" ]
    then
        SIZE="nominal"
    else
        SIZE="maximal"
    fi
fi
if `item_not_in_list "$SIZE" "$SIZES"`
then
    printf "ERROR: size %s not in [%s] !\\n" $SIZE $SIZES
    exit 1
fi
if $AUTO_PREFIX
then
    if [ "$USER" == "root" ]
    then
        PREFIX="$SYS_HOME/conda/forge"
	case $SIZE in
	    "minimal")
		SIZE_NAME=$MIN_SIZE_NAME
		;;
	    "nominal")
		SIZE_NAME=$NOM_SIZE_NAME 
		;;
	    "maximal")
		SIZE_NAME=$MAX_SIZE_NAME
		;;
	    *)
		printf "WTF: can't end up here !"
		exit 1
	esac
    else
	case $SIZE in
	    "minimal")
		SIZE_NAME=$MIN_SIZE_NAME
		PREFIX="$SYS_HOME/$USER/miniconda-forge"
		;;
	    "nominal")
		SIZE_NAME=$NOM_SIZE_NAME
		PREFIX="$SYS_HOME/$USER/conda-forge"
		;;
	    "maximal")
		SIZE_NAME=$MAX_SIZE_NAME
		PREFIX="$SYS_HOME/$USER/maxiconda-forge"
		;;
	    *)
		printf "WTF: can't end up here!"
		exit 1
	esac	  
    fi
else
    first_char="$(printf '%s' "$PREFIX" | cut -c1)"
    if [ "$first_char" != "/" ]
    then
	printf "ERROR: the prefix '$PREFIX' doesn't start with a '/' !\\n"
	exit 1
    fi
    case $SIZE in
        "minimal")
            SIZE_NAME=$MIN_SIZE_NAME
            ;;
        "nominal")
            SIZE_NAME=$NOM_SIZE_NAME
            ;;
        "maximal")
            SIZE_NAME=$MAX_SIZE_NAME
            ;;
        *)
            printf "WTF: can't end up here!"
            exit 1
    esac
fi

### IMPLEMENTATION ###
if $AUTO_IMPL
then
    IMPL="CPython"
fi
if `item_not_in_list "$IMPL" "$IMPLS"`
then
    printf "ERROR: $IMPL not in [$IMPL_LIST] !\\n"
    exit 1
fi
case $IMPL in
    "CPython")
        IMPL_NAME="forge3"
        ;;
    "PyPy")
        IMPL_NAME="forge-pypy3"
        ;;
    *)
	printf "WOOPS: $IMPL is in [$IMPL_LIST] but not yet implemented!\\n"
        exit 1
        ;;
esac

### PASS THROUGH ARGUMENTS ###
if [ "$BATCH" == "1" ]
then
    B="-b "
else
    B=""
fi
if [ "$FORCE" == "1" ]
then
    F="-f "
else
    F=""
fi
P="-p $PREFIX "
if [ "$SKIP_SCRIPTS" == "1" ]
then
    S="-s "
else
    S=""
fi
if [ "$TEST" == "1" ]
then
    T="-t "
fi
PTA="$(echo -e "$B$F$P$S$T" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

### URI's & COMMANDS ###
BASE_URL="https://github.com/conda-forge/miniforge/releases/latest/download/"
VERSION_URL="https://github.com/conda-forge/miniforge/releases/latest/"
[[ `curl -s $VERSION_URL` =~ [^0-9]+([^\"]+)\" ]]
VERSION=${BASH_REMATCH[1]}
INSTALLER="$SIZE_NAME$IMPL_NAME-$VERSION-$OS_NAME-$CPU_NAME.sh"
RUN_INSTALLER="bash $INSTALLER $PTA"
SHA256="$INSTALLER.sha256"
INSTALLER_URL="$BASE_URL$INSTALLER"
DOWNLOAD_INSTALLER="curl -SL $INSTALLER_URL --output $INSTALLER"
SHA256_URL="$BASE_URL$SHA256"
DOWNLOAD_SHA256="curl -SL $SHA256_URL --output $SHA256"
SHA256SUM="sha256sum ./$INSTALLER"

### USAGE ###
NOTICE="Miniforge3 version '$VERSION' on a '$OS/$CPU' platform for $USERS
The install size is '$SIZE' and the base Python implementation is '$IMPL'
The installation directory is '$PREFIX'
The underlaying installer is '$INSTALLER'
"
USAGE_TXT="
usage: $0 [options]

Installs $NOTICE

-x SIZE    The install package SIZE is one of [$SIZE_LIST]
       	     - minimal = Python + minimal conda
             - nominal = Python + full conda + full mamba
             - maximal = conda-forge equivalent of 'anaconda'
           the SIZE defaults to 'maximal' when installing as user
           the SIZE defaults to 'nominal' when installing as root
-i IMPL    The python IMPLementation is one of [$IMPL_LIST]
           the implementation defaults to 'CPython'
-h         Print this help message and exit

the below arguments are passed through to the actual installer.

-b         Run install in batch mode (without manual intervention),
           it is expected the license terms are agreed upon
-f         No error if install prefix already exists
-p PREFIX  Install prefix, defaults to $PREFIX, must not contain spaces.
-s         Skip running pre/post-link/install scripts
-u         Update an existing installation
-t         Run package tests after installation (may install conda-build)
"
if [ "$HELP" = "1" ]
then
    printf "%s\\n" "$USAGE_TXT"
    exit
fi

### Go ###
printf "\\nInstalling %s" "$NOTICE"

if [ "$USER" != "root" ] && [ "$BATCH" == "0" ] && [ "$FORCE" == "0" ] && `sudoer`
then
    printf "\\nYou are installing as non-root eventhough you are a sudo-er.\\n"
    printf "It is much better you install as root for all users on this system!\\n"
    printf "Do you want to continue anyway? [yes|no]\\n"
    printf "[no] >>> "
    read -r ans
    if [ "$ans" != "yes" ] && [ "$ans" != "Yes" ] && [ "$ans" != "YES" ] && \
           [ "$ans" != "y" ]   && [ "$ans" != "Y" ]
    then
        printf "Whise choice!\\n"
        exit 2
    fi
fi

printf "\\nStep #1: Downloading '$INSTALLER'\\n"
printf -- "-------------------------------------------------------------------------------\\n"
$DOWNLOAD_INSTALLER

printf "\\nStep #2: Downloading '$SHA256'\\n"
printf -- "-------------------------------------------------------------------------------\\n"
$DOWNLOAD_SHA256

printf "\\nStep #3: Checking installer integrity ..."
CALCULATED_CHECKSUM=`$SHA256SUM`
GIVEN_CHECKSUM=$(head -n 1 $SHA256)
if [ "$CALCULATED_CHECKSUM" == "$GIVEN_CHECKSUM" ]
then
    printf "PASS\\n"
else
    printf "FAIL:\\n"
    printf "Calculated: '%s'\\n" $CALCULATED_CHECKSUM
    printf "     Given: '%s'\\n" $GIVEN_CHECKSUM
    exit 1
fi
printf -- "-------------------------------------------------------------------------------\\n"

printf "\\nStep #4: Preparing to install ... "
create_conda_user_if_needed
printf "Done.\\n"
printf -- "-------------------------------------------------------------------------------\\n"

printf "\\nStep #5: Installing '$INSTALLER $PTA'\\n"
printf -- "-------------------------------------------------------------------------------\\n"
$RUN_INSTALLER

printf "\\nStep #6: post-processing installation ... "
if [ "$USER" == "root" ]
then
    # https://docs.anaconda.com/anaconda/install/multi-user/
    `chgrp -R conda $PREFIX` # does this work also for macOS?
    `chmod 770 -R $PREFIX`   # does this work also for macOS?
fi
printf "Done.\\n"
printf -- "-------------------------------------------------------------------------------\\n"

printf "\\nStep #7: Cleaning up ... "
`rm -f $INSTALLER`
`rm -f $SHA256`
printf "Done.\\n"
printf -- "-------------------------------------------------------------------------------\\n"

printf "\\nYou are all set and ready to go!\\n"
if [ "$USER" == "root" ]
then
    case $OS_NAME in
	"MacOSX")
	    printf "\\nRemember:\\n"
	    printf "  1) add desired users to the 'conda' group by doing\\n"
	    printf "       \$ sysadminctl  usermod -a -G conda <user>\\n"
	    printf "  2) the user can now initialize conda by doing\\n"
	    printf "       \$ $PREFIX/condabin/conda init --all\\n"
	    printf "  3) the user need to logout/login for the changes to take effect.\\n\\n"
	    ;;
	"Linux")
	    printf "\\nRemember:\\n"
	    printf "  1) add desired users to the 'conda' group by doing\\n"
	    printf "       # usermod -a -G conda <user>\\n"
	    printf "  2) the user can now initialize conda by doing\\n"
	    printf "       \$ $PREFIX/condabin/conda init --all\\n"
	    printf "  3) the user need to logout/login for the changes to take effect.\\n\\n"
	    ;;
	*)
	    ;;
fi
printf "Bon voyage!\\n"
