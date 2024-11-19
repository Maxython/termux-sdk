#!/data/data/com.termux/files/usr/bin/bash

set -e -u

export ANDROID_HOME="${ANDROID_HOME:=${PREFIX}/opt/android-sdk}"
export SHELL_PATH="${SHELL_PATH:=${PREFIX}/glibc/bin/bash}"
export BOX64_PATH="${BOX64_PATH:=${PREFIX}/glibc/bin/box64}"
RUN_COMMAND="$@"
DIRS_ANDROID_HOME=""
DO_UPDATE_SDKMANAGER="${DO_UPDATE_SDKMANAGER:=true}"
DIR_ORG_SRC="${DIR_ORG_SRC:=orgsrc}"

if [ -z "${BINS_IGNORE-}" ]; then
	BINS_IGNORE=('ld' 'lld')
else
	BINS_IGNORE=(${BINS_IGNORE})
fi
if [ -z "${DIRS_IGNORE-}" ]; then
	DIRS_IGNORE=('site-packages')
else
	DIRS_IGNORE=(${DIRS_IGNORE})
fi
DIRS_IGNORE+=("${DIR_ORG_SRC}")
if [ -z "${PKGS_IGNORE-}" ]; then
	PKGS_IGNORE=('platforms')
else
	PKGS_IGNORE=(${PKGS_IGNORE})
fi
if [ -z "${LIBS_CHECK-}" ]; then
	LIBS_CHECK=('lib' 'lib64')
else
	LIBS_CHECK=(${LIBS_CHECK})
fi
if [ -z "${RENAME_BINS-}" ]; then
	RENAME_BINS=('cmake')
else
	RENAME_BINS=(${RENAME_BINS})
fi

BLUE='\033[0;34m'
Red='\033[0;31m'
NOCOLOR='\033[0m'

info() {
	echo -e "${BLUE}${1}${NOCOLOR}"
}

error() {
	echo -e "${RED}${1}${NOCOLOR}"
	exit 1
}

help_message() {
	echo "$0"
	echo ' is a script that installs and configures files'
	echo ' from the sdk so that they can be used in Termux.'
	echo ''
	echo 'Configured values:'
	echo " ANDROID_HOME=${ANDROID_HOME}"
	echo " SHELL_PATH=${SHELL_PATH}"
	echo " BOX64_PATH=${BOX64_PATH}"
	echo " DO_UPDATE_SDKMANAGER=${DO_UPDATE_SDKMANAGER}"
	echo " DIR_ORG_SRC=${DIR_ORG_SRC}"
	echo " BINS_IGNORE=(${BINS_IGNORE[@]})"
	echo " DIRS_IGNORE=(${DIRS_IGNORE[@]})"
	echo " PKGS_IGNORE=(${PKGS_IGNORE[@]})"
	echo " LIBS_CHECK=(${LIBS_CHECK[@]})"
	echo " RENAME_BINS=(${RENAME_BINS})"
	echo ''
	echo 'Run with `--help` flag to get more information from `sdkmanager`.'
	exit 0
}

check_programs() {
	info "Checking programs"
	for prog in "${SHELL_PATH}" "${BOX64_PATH}"; do
		if [ ! -f "${prog}" ]; then
			error "program '${prog}' not found"
		fi
	done
	if ! type pip &> /dev/null; then
		error "program 'pip' not found"
	fi
}

run_sdkmanager() {
	if [ "${DO_UPDATE_SDKMANAGER}" = "true" ]; then
		info "Updating sdkmanager"
		pip install sdkmanager --upgrade
	fi
	info "Launching sdkmanager"
	sdkmanager $RUN_COMMAND
}

add_lib() {
	if grep -Eq "/($(tr ' ' '|' <<< ${LIBS_CHECK[@]}))$" <<< "${1}" && [ -d "${1}" ]; then
		echo ":${1}"
	fi
}

set_bins() {
	info "Setting up binaries"
	local dirs=$(find $ANDROID_HOME -type d -maxdepth 4 -mindepth 1 2>/dev/null)
	if [[ "$dirs" = "${DIRS_ANDROID_HOME}" ]]; then
		return
	fi
	if [[ -n "$DIRS_ANDROID_HOME" ]]; then
		for dir in ${DIRS_ANDROID_HOME}; do
			dirs=$(sed "/^${dir////\\/}$/d" <<< "${dirs}")
		done
	fi
	dirs=$(sed "s|${ANDROID_HOME}/||g" <<< ${dirs} | tr " " "\n" | awk -F '/' '{printf "'$ANDROID_HOME'/" $1 "\n"}' | sort -u | grep -Ev "/($(tr ' ' '|' <<< ${PKGS_IGNORE[@]}))$" || true)
	if [[ -z "${dirs}" ]]; then
		return
	fi
	for bin in $(find $dirs \( -type l -o -type f \) -exec grep -ILs . "{}" \; | sed 's/ /@SPACE@/g'); do
		bin=${bin//@SPACE@/ }
		local path_bin="$(dirname ${bin})"
		local path_orgsrc="${path_bin}/${DIR_ORG_SRC}"
		local path_orgbin="${path_orgsrc}"
		if [ "$(basename ${path_bin})" = "bin" ]; then
			path_orgbin+="/bin"
		fi
		local path_link="$(readlink -f ${bin})"
		local linkname="$(basename ${path_link})"
		if [ -f "${path_orgbin}/${linkname}" ]; then
			path_link="${path_orgbin}/${linkname}"
		fi
		if $(file "${path_link}" | grep -q 'ld-linux-x86-64.so.2') && \
			! grep -Eq "^($(tr ' ' '|' <<< ${BINS_IGNORE[@]}))$" <<< "${linkname}" && \
			! grep -Eq "/($(tr ' ' '|' <<< ${DIRS_IGNORE[@]}))/" <<< $(sed "s|^${ANDROID_HOME}||" <<< "${bin}"); then
			echo "Set up ${bin}"
			mkdir -p "${path_orgbin}"
			if [ "$(basename ${path_orgbin})" = "bin" ]; then
				for src in $(find "${path_orgsrc}/../.." -maxdepth 1 -mindepth 1 ! -name bin | grep -Ev "/($(echo $(find ${path_orgsrc} -maxdepth 1 -mindepth 1 -printf '%f\n') | tr ' ' '|'))$"); do
					ln -sr "${src}" "${path_orgsrc}"
				done
			fi
			path_orgbin+="/$(basename ${bin})"
			if grep -Eq "/($(tr ' ' '|' <<< ${RENAME_BINS[@]}))$" <<< "${path_orgbin}"; then
				ln -sr "${bin}" "${path_orgbin}"
				path_orgbin+="_orgbin"
			fi
			mv "${bin}" "${path_orgbin}"
			{
				echo '[ -z "${RUNNING_IN_GLIBC_RUNNER}" ] && unset LD_PRELOAD'
				local path_ld="${path_bin}"
				for lib in ${LIBS_CHECK[@]}; do
					path_ld+=$(add_lib $(sed "s|/bin$|/${lib}|" <<< "${path_bin}"))$(add_lib "${path_bin}/${lib}")
				done
				echo "exec ${SHELL_PATH} -c \"BOX64_NOBANNER=1 BOX64_LOG=0 BOX64_LD_LIBRARY_PATH='${path_ld}' exec ${BOX64_PATH} ${path_orgbin} \$(while [ \"\$#\" != \"0\" ]; do echo -n \" '\${1}'\"; shift 1; done)\""
			} > "${bin}"
			chmod +x "${bin}"
		fi
	done
}

# MAIN
if [ $(uname -m) != "aarch64" ]; then
	error "$0 is only supported on aarch64"
fi
if [[ -z "${RUN_COMMAND}" ]]; then
	help_message
fi
check_programs
if [ ! -d ${ANDROID_HOME} ]; then
	mkdir -p $ANDROID_HOME
fi
DIRS_ANDROID_HOME=$(find $ANDROID_HOME -type d -maxdepth 4 -mindepth 1 2>/dev/null)
run_sdkmanager
set_bins
info "Successful completion"
