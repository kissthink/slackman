#!/usr/bin/env bash
# env: FAKEROOT TMP OUTPUT SBO_VER LOG

# sudo will break (gpg) permissions
if [[ $UID == 0 ]]
then
	read -rep $'Warning! You are now building as root. [^C to exit]\n'
	FAKEROOT=0
fi

# Set to 1 to build as a regular user
# Needs fakeroot (system/fakeroot) for correct permissions
# TODO: consider fakeroot-ng
FAKEROOT=${FAKEROOT:-1}

if [[ $FAKEROOT == 1 ]]
then
	# Slackbuild variables (mkdir -p)
	export TMP="${TMP:-$HOME/tmp/SBo}"
	export OUTPUT="${OUTPUT:-$HOME}"
fi

# non-interactive mode
if [[ $1 =~ .*/.* ]]
then
	SBO_QRY="$1"
else
	read -rep "Enter the package group and name (e.g. libraries/libsodium) " SBO_QRY
fi

SBO_VER="${SBO_VER:-14.1}"
SBO_REP="http://slackbuilds.org/slackbuilds/$SBO_VER"
SBO_PKG="${SBO_QRY##*/}"
SBO_URL="$SBO_REP/$SBO_QRY.tar.gz"

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
	# Split strings to arrays
	DOWNLOAD=( $DOWNLOAD ); DOWNLOAD_x86_64=( $DOWNLOAD_x86_64 )
	MD5SUM=( $MD5SUM ); MD5SUM_x86_64=( $MD5SUM_x86_64 )
	REQUIRES=( $REQUIRES )

	local i; i=0
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
	# Dirty hack. Root/non-root sections differ per SlackBuild.
	if [[ $FAKEROOT == 1 ]]
	then
		# sed -i 's|^chown|#chown|' ${SBO_PKG}.SlackBuild
		fakeroot ./"$SBO_PKG".SlackBuild
	else
		./"$SBO_PKG".SlackBuild
	fi
}

trap sbo_exit EXIT

# Logging
SBO_LOG="/tmp/slackman-$SBO_PKG.log"

if [[ $LOG == 0 ]] || ! touch "$SBO_LOG"
then
	echo "Logging is disabled."
	SBO_LOG='/dev/stdout'
fi

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

