#!/data/data/com.termux/files/usr/bin/bash

set -e -u

export ANDROID_HOME=${ANDROID_HOME:=${PREFIX}/opt/android-sdk}
RUN_COMMAND="$@"
FILES_ANDROID_HOME=""
if [ -z "${BINS_IGNORE_SET-}" ]; then
	BINS_IGNORE_SET=('ld')
else
	BINS_IGNORE_SET=(${BINS_IGNORE_SET})
fi
BLUE='\033[0;34m'
NOCOLOR='\033[0m'

info() {
	echo -e "${BLUE}${1}${NOCOLOR}"
}

is_ingoring() {
	local binfile="$1"
	for _len_bin in $(seq 0 $((${#BINS_IGNORE_SET[@]}-1))); do
		if [ "${BINS_IGNORE_SET[${_len_bin}]}" = "${binfile}" ]; then
			return 0
		fi
	done
	return 1
}

help_message() {
	echo "$0"
	echo ' is a script that installs and configures files'
	echo ' from the sdk so that they can be used in Termux.'
	echo ''
	echo 'Configured values:'
	echo " ANDROID_HOME=${ANDROID_HOME}"
	echo " BINS_IGNORE_SET=(${BINS_IGNORE_SET[@]})"
	echo ''
	echo 'Run with `--help` flag to get more information from `sdkmanager`.'
	exit 0
}

run_sdkmanager() {
	if ! type sdkmanager &> /dev/null; then
		info "Installing sdkmanager"
		pip install sdkmanager
	fi
	info "Launching sdkmanager"
	sdkmanager $RUN_COMMAND
}

set_bins() {
	info "Setting up binaries"
	local files=$(find $ANDROID_HOME -type f | sed 's/ /@SPACE@/g')
	if [[ -n "$FILES_ANDROID_HOME" ]]; then
		for file in ${FILES_ANDROID_HOME}; do
			files=$(echo "${files}" | grep -v "$file" || echo "")
		done
	fi
	for bin in ${files}; do
		bin=${bin//@SPACE@/ }
		if $(file "${bin}" | grep -q 'ld-linux-x86-64.so.2') && ! is_ingoring "$(basename ${bin})" && ! $(echo "${bin}" | grep -q '_orginal_bin'); then
			echo "Set up ${bin}"
			mv "${bin}" "${bin}_orginal_bin"
			echo 'grun --shell BOX64_NOBANNER=1 BOX64_LOG=0 box64 '"${bin}"'_orginal_bin $@' > "${bin}"
			chmod +x "${bin}"
		fi
	done
}

# MAIN
if [ $(uname -m) != "aarch64" ]; then
	echo "$0 is only supported on aarch64"
	exit 1
fi
if [[ -z "${RUN_COMMAND}" ]]; then
	help_message
fi
FILES_ANDROID_HOME=$(find $ANDROID_HOME -type f | sed 's/ /@SPACE@/g')
run_sdkmanager
set_bins
info "End"
