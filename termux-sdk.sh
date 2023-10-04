#!/data/data/com.termux/files/usr/bin/bash

set -e -u

export ANDROID_HOME=${ANDROID_HOME:=${PREFIX}/opt/android-sdk}
SHELL_PATH=${SHELL_PATH:=${PREFIX}/bin/bash}
RUN_COMMAND="$@"
DIRS_ANDROID_HOME=""
if [ -z "${BINS_IGNORE_SET-}" ]; then
	BINS_IGNORE_SET=('ld' 'lld')
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
	echo " SHELL_PATH=${SHELL_PATH}"
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
	local dirs=$(find $ANDROID_HOME -type d -maxdepth 4 -mindepth 1 2>/dev/null)
	if [ "$dirs" = "${DIRS_ANDROID_HOME}" ]; then
		return
	fi
	if [[ -n "$DIRS_ANDROID_HOME" ]]; then
		for dir in ${DIRS_ANDROID_HOME}; do
			dirs=$(echo "${dirs}" | sed "s|^${dir}$||")
		done
	fi
	dirs=$(tr " " "\n" <<< $(echo $dirs | sed "s|${ANDROID_HOME}/||g") | awk -F '/' '{printf "'$ANDROID_HOME'/" $1 "\n"}' | sort -u)
	for bin in $(find $dirs -type f -exec grep -IL . "{}" \; | sed 's/ /@SPACE@/g'); do
		bin=${bin//@SPACE@/ }
		if $(file "${bin}" | grep -q 'ld-linux-x86-64.so.2') && ! is_ingoring "$(basename ${bin})" && ! $(echo "${bin}" | grep -q '_orginal_bin'); then
			echo "Set up ${bin}"
			mv "${bin}" "${bin}_orginal_bin"
			echo "#!${PREFIX}/bin/bash" > "${bin}"
			echo 'grun --shell BOX64_NOBANNER=1 BOX64_LOG=0 box64 '"${bin}"'_orginal_bin $@' >> "${bin}"
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
if [ ! -d ${ANDROID_HOME} ]; then
	mkdir -p $ANDROID_HOME
fi
DIRS_ANDROID_HOME=$(find $ANDROID_HOME -type d -maxdepth 4 -mindepth 1 2>/dev/null)
run_sdkmanager
set_bins
info "End"
