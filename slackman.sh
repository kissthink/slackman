#!/usr/bin/env bash
#
# Slackman - a simple SBo manager
# Alad Wenter © 2014 MIT license

SBO_VER="${SBO_VER:-14.1}"
SBO_REP="http://slackbuilds.org/slackbuilds/$SBO_VER"
FROOT="${FROOT:-1}"
CORE="${CORE:-2}"
LOG="${LOG:-1}"

if [[ $UID == 0 ]]
then
	read -rep $'You are now building as root. Continue?\n'
	FROOT=0
fi

# Set to 1 to build packages without root access
# Needs fakeroot (system/fakeroot) for correct permissions
if [[ $FROOT == 1 ]]
then
	# Slackbuild variables (mkdir -p)
	export TMP="${TMP:-$HOME/tmp/SBo}"
	export OUTPUT="${OUTPUT:-$HOME}"
fi

# non-interactive mode; specify the package name to the command line
if [[ $1 =~ .*/.* ]]
then
	SBO_QRY="$1"
else
	read -rep "Enter the package group and name (e.g. libraries/libsodium) " SBO_QRY
fi

SBO_PKG="${SBO_QRY##*/}"
SBO_URL="$SBO_REP/$SBO_QRY.tar.gz"

# Slackbuild makeflags
# http://www.linuxquestions.org/questions/slackware-14/is-there-a-way-to-speed-up-slackbuilds-887355/
if [[ $CORE =~ ^[0-9]?[0-9]$ ]]
then
	export MAKEFLAGS="-j$CORE"
fi

# Redirect output to logfile
SBO_LOG="/tmp/slackman-$SBO_PKG.log"

if [[ $LOG == 0 ]] || ! touch "$SBO_LOG"
then
	echo "Logging is disabled."
	SBO_LOG='/dev/stdout'
fi

################################################################################

sbo_exit() {
 	echo "Cleaning up..."
	popd >/dev/null
	rm -r "$SBO_PKG" "$SBO_PKG".tar.gz "$SBO_PKG".tar.gz.asc
}

sbo_failcheck() {
	if [[ $? != 0 ]]
	then
		echo "Something went wrong. $SBO_LOG" >&2
		if [[ $SBO_LOG != /dev/stdout ]] 
		then
			echo "-------------"
			tail "$SBO_LOG" >&2
			echo "-------------"
		fi
		read -rep $'Continue anyway? [^C to exit]\n'
	fi
}

sbo_download() {
	wget "$SBO_URL".asc
	wget "$SBO_URL"
}

sbo_verify() {
	gpg --keyserver keys.gnupg.net --recv-keys 9C7BA3B6
	gpg --verify "$SBO_PKG".tar.gz.asc
}

sbo_unpack() {
	tar xvf "$SBO_PKG".tar.gz
	pushd "$SBO_PKG"
}

sbo_source() {
	echo "PKGNAM VERSION HOMEPAGE DOWNLOAD MD5SUM DOWNLOAD REQUIRES MAINTAINER EMAIL"
	source "$SBO_PKG".info
	# Split strings into arrays to handle multiple URLs
	DOWNLOAD=( $DOWNLOAD ); DOWNLOAD_x86_64=( $DOWNLOAD_x86_64 )
	MD5SUM=( $MD5SUM ); MD5SUM_x86_64=( $MD5SUM_x86_64 )
	REQUIRES=( $REQUIRES )

	local i; i=0 # Arrays start count at 0
	if [[ $(uname -m) == x86_64 && -n $DOWNLOAD_x86_64 ]]
	then
		for DLSUM64 in "${DOWNLOAD[@]}"; do
			wget "$DLSUM64"
			md5sum --check --strict <<< $(echo "${MD5SUM_x86_64[$i]}  ${DLSUM64##*/}")
			let ++i  # return 0, i must not equal -1
		done
	else
	       	for DLSUM in "${DOWNLOAD[@]}"; do
			wget "$DLSUM"
			md5sum --check --strict <<< $(echo "${MD5SUM[$i]}  ${DLSUM##*/}")
			let ++i
		done
	fi
}

sbo_deps() {
	local i; i=
	for i in "${REQUIRES[@]}"
	do
		SBO_INS+=( $(ls /var/log/packages | grep -o "$i") )
	done

	if [[ ${REQUIRES[@]} != ${SBO_INS[@]} ]]
	then
		echo "-------------"
		echo "SBo required:  ${REQUIRES[@]}"
		echo "SBo installed: ${SBO_INS[@]}"
		echo "-------------"
		read -rep $'Continue? [^C to exit]\n'
	fi
}

sbo_build() {
	if [[ $FROOT == 1 ]]
	then
		# FIXME: Root/non-root sections differ per SlackBuild, so the entire
		# Slackbuild is run with fakeroot
		fakeroot ./"$SBO_PKG".SlackBuild
	else
		./"$SBO_PKG".SlackBuild
	fi
}

################################################################################

trap sbo_exit EXIT

# Make sure we don't break systems with custom umask:
# installpkg overwrites existing permissions
# http://www.adras.com/12-2-installpkg-messing-up-perms.t8907-75.html
umask 0022

# Build starts here
echo "Downloading SBo..."
sbo_download	>> "$SBO_LOG" 2>&1
sbo_failcheck

echo "Verifying SBo..."
sbo_verify	>> "$SBO_LOG" 2>&1
sbo_failcheck

echo "Unpacking SBo..."
sbo_unpack	>> "$SBO_LOG" 2>&1
sbo_failcheck

echo "Downloading and verifying sources..."
sbo_source	>> "$SBO_LOG" 2>&1
sbo_failcheck

echo "Checking dependencies..."
sbo_deps

echo "Building the package to $OUTPUT..."
sbo_build	>> "$SBO_LOG" 2>&1
sbo_failcheck

echo "Done!"
unset MAKEFLAGS TMP OUTPUT
