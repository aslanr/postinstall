#!/bin/bash

# postinstall.sh

# Bash Script to automate post-installation steps. 

################################################################################
#### Configuration Section
################################################################################

# Where is the default base url or dir. Without / at the end
# Filesystem directory: BASE="/root/install/base"
# Can be overwritten with -b <BASE> at runtime
BASE="/root/install/base"

# Default type of installation
# Can be overwritten with -t <TYPE> at runtime
TYPE="server"

################################################################################
#### END Configuration Section
################################################################################

ME=$(basename "$0")
DATETIME=$(date "+%Y-%m-%d-%H-%M-%S")
MY_INSTALL="install"

if [[ ! $LC_CTYPE ]]; then
	export LC_CTYPE='en_US.UTF-8'
fi
if [[ ! $LC_ALL ]]; then
	export LC_ALL='en_US.UTF-8'
fi


################################################################################
# Usage
################################################################################

function usage {
	returnCode="$1"
	echo -e "Usage: $ME [-t <TYPE>] [-b <BASE>] [-h]:
	[-t <TYPE>]\t sets the type of installation (default: $TYPE)
	[-b <BASE>]\t sets the base url or dir (default: $BASE)
	[-h]\t\t displays help (this message)"
	exit "$returnCode"
}

################################################################################
# Terminal output helpers
################################################################################

# echo_equals() outputs a line with =
#   seq does not exist under OpenBSD
function echo_equals() {
	COUNTER=0
	while [  $COUNTER -lt "$1" ]; do
		printf '='
		(( COUNTER=COUNTER+1 ))
	done
}

# echo_title() outputs a title padded by =, in yellow.
function echo_title() {
	TITLE=$1
	NCOLS=$(tput cols)
	NEQUALS=$(((NCOLS-${#TITLE})/2-1))
	tput setaf 3 0 0 # 3 = yellow
	echo_equals "$NEQUALS"
	printf " %s " "$TITLE"
	echo_equals "$NEQUALS"
	tput sgr0  # reset terminal
	echo
}

# echo_step() outputs a step collored in cyan, without outputing a newline.
function echo_step() {
	tput setaf 6 0 0 # 6 = cyan
	echo -n "$1"
	tput sgr0  # reset terminal
}

# echo_step_info() outputs additional step info in cyan, without a newline.
function echo_step_info() {
	tput setaf 6 0 0 # 6 = cyan
	echo -n " ($1)"
	tput sgr0  # reset terminal
}

# echo_right() outputs a string at the rightmost side of the screen.
function echo_right() {
	TEXT=$1
	echo
	tput cuu1
	tput cuf "$(tput cols)"
	tput cub ${#TEXT}
	echo "$TEXT"
}

# echo_failure() outputs [ FAILED ] in red, at the rightmost side of the screen.
function echo_failure() {
	tput setaf 1 0 0 # 1 = red
	echo_right "[ FAILED ]"
	tput sgr0  # reset terminal
}

# echo_success() outputs [ OK ] in green, at the rightmost side of the screen.
function echo_success() {
	tput setaf 2 0 0 # 2 = green
	echo_right "[ OK ]"
	tput sgr0  # reset terminal
}

# echo_warning() outputs a message and [ WARNING ] in yellow, at the rightmost side of the screen.
function echo_warning() {
	tput setaf 3 0 0 # 3 = yellow
	echo_right "[ WARNING ]"
	tput sgr0  # reset terminal
	echo "    ($1)"
}

# exit_with_message() outputs and logs a message before exiting the script.
function exit_with_message() {
	echo
	echo "$1"
	echo -e "\n$1" >>"$INSTALL_LOG"
	if [[ $INSTALL_LOG && "$2" -eq 1 ]]; then
		echo "For additional information, check the install log: $INSTALL_LOG"
	fi
	echo
	debug_variables
	echo
	exit 1
}

# exit_with_failure() calls echo_failure() and exit_with_message().
function exit_with_failure() {
	echo_failure
	exit_with_message "FAILURE: $1" 1
}


################################################################################
# Other helpers
################################################################################

# debug_variables() print all script global variables to ease debugging
debug_variables() {
	echo "USERNAME: $USERNAME"
	echo "SHELL: $SHELL"
	echo "BASH_VERSION: $BASH_VERSION"
	echo
	echo "BASE: $BASE"
	echo "TYPE: $TYPE"
	echo "HOSTNAME_FQDN: $HOSTNAME_FQDN"
	echo "OPERATING_SYSTEM: $OPERATING_SYSTEM"
	echo "OPERATING_SYSTEM_TYPE: $OPERATING_SYSTEM_TYPE"
	echo "ARCHITECTURE: $ARCHITECTURE"
	echo "INSTALL_LOG: $INSTALL_LOG"
	echo "MY_INSTALLER: $MY_INSTALLER"
	echo "MY_INSTALL: $MY_INSTALL"
	echo "PACKAGES_LIST: $PACKAGES_LIST"
	echo "BEFORE_SCRIPT: $BEFORE_SCRIPT"
	echo "AFTER_SCRIPT: $AFTER_SCRIPT"
	echo "FETCHER: $FETCHER"
	echo "ASSUME_ALWAYS_YES: $ASSUME_ALWAYS_YES"
	echo "SUDO_USER: $SUDO_USER"
}

# command_exists() tells if a given command exists.
function command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# check if the hostname can be resolved locally
function detect_hostname_fqdn() {
	echo_step "Detecting FQDN"
	if hostname -f &>/dev/null; then
		echo -e "\nhostname -f" >>"$INSTALL_LOG"
		HOSTNAME_FQDN=$(hostname -f)
		echo_step_info "$HOSTNAME_FQDN"
		echo_success
	elif hostname &>/dev/null; then
		echo -e "\nhostname" >>"$INSTALL_LOG"
		HOSTNAME_FQDN=$(hostname)
		echo_step_info "$HOSTNAME_FQDN"
		echo_success
	else
		echo -e "\nhostname could not be determined" >>"$INSTALL_LOG"
		HOSTNAME_FQDN="foo.bar"
		echo_step_info "$HOSTNAME_FQDN"
		echo_warning "Hostname could not be determined, will attempt to continue"
	fi
	export HOSTNAME_FQDN
}

# check_if_root_or_die() verifies if the script is being run as root and exits
# otherwise (i.e. die).
function check_if_root_or_die() {
	echo_step "Checking installation privileges"
	echo -e "\nid -u" >>"$INSTALL_LOG"
	SCRIPT_UID=$(id -u)
	if [ "$OPERATING_SYSTEM" = "CYGWIN" ]; then
		# Administrator really isn't equivalent to POSIX root.
		echo_step_info "Cygwin, no need for root"
	elif [ "$OPERATING_SYSTEM" = "TERMUX" ]; then
		# Termux does nor supply tools for rooting.
		echo_step_info "Termux, no need for root"
	elif [ "$OPERATING_SYSTEM" = "HAIKU" ]; then
		# Haiku is a single-user system
		echo_step_info "Haiku, no need for root"
	elif [ "$SCRIPT_UID" != 0 ]; then
		exit_with_failure "$ME should be run as root"
	fi
	echo_success
}

# check_travis() check travis (https://travis-ci.org/Cyclenerd/postinstall) environment
function check_travis() {
	if [ -n "$TRAVIS" ]; then
		MY_HOMEBREW_USER="travis"
		export MY_HOMEBREW_USER
		echo "!!! Travis CI detected. Behavior is somewhat different !!!" >>"$INSTALL_LOG"
		echo_step "Travis CI detected. Behavior is somewhat different!"
		echo_success
	fi
}

# check_bash() check if current shell is bash
function check_bash() {
	echo_step "Checking if current shell is bash"
	if [[ "$0" == *"bash" ]]; then
		exit_with_failure "Failed, your current shell is $0"
	fi
	echo_success
}

# check_fetcher() check if curl is installed
function check_fetcher() {
	echo_step "  Checking if curl is installed"
	if command_exists curl; then
		# -f = Fail silently (no output at all) on server errors (404, 301, ...).
		export FETCHER="curl -fs"
	else
		echo_step_info "Try to install curl"
		echo -e "\n$MY_INSTALLER $INSTALL curl" >>"$INSTALL_LOG"
		if $MY_INSTALLER $MY_INSTALL "curl" >>"$INSTALL_LOG" 2>&1; then
			export FETCHER="curl -fs"
		else
			exit_with_failure "'curl' is needed. Please install 'curl'. More details can be found at https://curl.haxx.se/"
		fi
	fi
	echo_success
}

# detect_architecture() obtains the system architecture
function detect_architecture() {
	echo_step "Detecting architecture"
	echo -e "\nuname -m" >>"$INSTALL_LOG"
	ARCHITECTURE=$(uname -m)
	export ARCHITECTURE
	echo_step_info "$ARCHITECTURE"
	echo_success
}

# detect_operating_system() obtains the operating system and exits if it's not
# one of: Debian, Ubuntu, Fedora, RedHat, CentOS, SuSE, macOS, FreeBSD or Cycwin
function detect_operating_system() {
	echo_step "Detecting operating system"
	echo -e "\nuname" >>"$INSTALL_LOG"
	# https://en.wikipedia.org/wiki/Uname
	# Within the bash shell, the environment variable OSTYPE contains a value similar (but not identical) to the value of uname (-o)
	# macOS = uname -o: illegal option -- o
	OPERATING_SYSTEM_TYPE=$(uname)
	export OPERATING_SYSTEM_TYPE
	if [ -f /etc/redhat-release ] || [ -f /etc/system-release-cpe ]; then
		echo -e "\ntest -f /etc/redhat-release || test -f /etc/system-release-cpe" >>"$INSTALL_LOG"
		echo_step_info "Red Hat / Fedora / CentOS"
		OPERATING_SYSTEM="REDHAT"
	else
		{
			echo -e "\ntest -f /etc/redhat-release || test -f /etc/system-release-cpe"

		} >>"$INSTALL_LOG"
		exit_with_failure "Unsupported operating system"
	fi
	echo_success
	export OPERATING_SYSTEM
}

# detect_installer() obtains the operating system package management software and exits if it's not installed
function detect_installer() {
	echo_step "  Checking installation tools"
	case $OPERATING_SYSTEM in
		REDHAT)
			# https://fedoraproject.org/wiki/Dnf
			if command_exists dnf; then
				echo -e "\ndnf found" >>"$INSTALL_LOG"
				export MY_INSTALLER="dnf"
				export MY_INSTALL="-y install"
			# https://fedoraproject.org/wiki/Yum
			# As of Fedora 22, yum has been replaced with dnf.
			elif command_exists yum; then
				echo -e "\nyum found" >>"$INSTALL_LOG"
				export MY_INSTALLER="yum"
				export MY_INSTALL="-y install"
			else
				exit_with_failure "Either 'dnf' or 'yum' are needed"
			fi
			# RPM
			if command_exists rpm; then
				echo -e "\nrpm found" >>"$INSTALL_LOG"
			else
				exit_with_failure "Command 'rpm' not found"
			fi
			;;
	esac
	echo_success
}

# resync_installer() re-synchronize the package index and install the newest versions of all packages currently installed
function resync_installer() {
	echo_step "  Re-sync. the package index and install the newest versions (please wait, sometimes takes a little longer...)"
	case $MY_INSTALLER in
		dnf|yum)
			$MY_INSTALLER -y update >>"$INSTALL_LOG" 2>&1
			if [ "$?" -ne 0 ]; then
				exit_with_failure "Failed to do $MY_INSTALLER update"
			fi
			;;
	esac
	echo_success
}

# use the given INSTALL_LOG or set it to a random file in /tmp
function set_install_log() {
	if [[ ! $INSTALL_LOG ]]; then	
		# Termux
		if [ -d "$PREFIX/tmp" ]; then
			export INSTALL_LOG="$PREFIX/tmp/install_$DATETIME.log"
		# Normal
		else
			export INSTALL_LOG="/tmp/install_$DATETIME.log"
		fi
	fi
	if [ -e "$INSTALL_LOG" ]; then
		exit_with_failure "$INSTALL_LOG already exists"
	fi
}

# use the given PACKAGES_LIST or set it to a random file in /tmp
function set_packages_list() {
	if [[ ! $PACKAGES_LIST ]]; then
		# Termux
		if [ -d "$PREFIX/tmp" ]; then
			export PACKAGES_LIST="$PREFIX/tmp/packages_$DATETIME.list"
		# Normal
		else
			export PACKAGES_LIST="/tmp/packages_$DATETIME.list"
		fi
	fi
	if [ -e "$PACKAGES_LIST" ]; then
		exit_with_failure "$PACKAGES_LIST already exists"
	fi
}

# use the given BEFORE_SCRIPT or set it to a random file in /tmp
function set_before_script() {
	if [[ ! $BEFORE_SCRIPT ]]; then
		# Termux
		if [ -d "$PREFIX/tmp" ]; then
			export BEFORE_SCRIPT="$PREFIX/tmp/before_$DATETIME.sh"
		# Normal
		else
			export BEFORE_SCRIPT="/tmp/before_$DATETIME.sh"
		fi
	fi
	if [ -e "$BEFORE_SCRIPT" ]; then
		exit_with_failure "$BEFORE_SCRIPT already exists"
	fi
}

# use the given AFTER_SCRIPT or set it to a random file in /tmp
function set_after_script() {
	if [[ ! $AFTER_SCRIPT ]]; then
		# Termux
		if [ -d "$PREFIX/tmp" ]; then
			export AFTER_SCRIPT="$PREFIX/tmp/after_$DATETIME.sh"
		# Normal
		else
			export AFTER_SCRIPT="/tmp/after_$DATETIME.sh"
		fi
	fi
	if [ -e "$AFTER_SCRIPT" ]; then
		exit_with_failure "$AFTER_SCRIPT already exists"
	fi
}

function build_script() {
	INPUT_ARRAY_NAME=("$@")
	((last_idx=${#INPUT_ARRAY_NAME[@]} - 1))
	OUTPUT_NAME=${INPUT_ARRAY_NAME[last_idx]}
	unset "INPUT_ARRAY_NAME[last_idx]"
	
	echo_step "  '$OUTPUT_NAME'"
	
	echo '#/bin/bash' > "$OUTPUT_NAME"
	
	if [[ "$BASE" == "http"* ]]; then
		for INPUT_NAME in "${INPUT_ARRAY_NAME[@]}"; do
			echo -e "\nchecking $INPUT_NAME" >>"$INSTALL_LOG"
			echo -e "\n\n#$INPUT_NAME\n" >> "$OUTPUT_NAME"
			echo -e "\n$FETCHER $INPUT_NAME >> $OUTPUT_NAME" >>"$INSTALL_LOG"
			$FETCHER -H 'Cache-Control: no-cache' "$INPUT_NAME" >> "$OUTPUT_NAME"
			echo >> "$OUTPUT_NAME"
		done
	else
		for INPUT_NAME in "${INPUT_ARRAY_NAME[@]}"; do
			echo -e "\nchecking $INPUT_NAME" >>"$INSTALL_LOG"
			echo -e "\n\n#$INPUT_NAME\n" >> "$OUTPUT_NAME"
			if [ -f "$INPUT_NAME" ]; then
				echo -e "\ncat $INPUT_NAME >> $OUTPUT_NAME" >>"$INSTALL_LOG"
				cat "$INPUT_NAME" >> "$OUTPUT_NAME"
				if [ "$?" -ne 0 ]; then
					exit_with_failure "Failed to append $INPUT_NAME to $OUTPUT_NAME"
				fi
				echo >> "$INPUT_NAME"
			fi
		done
	fi
	echo_success
}

################################################################################
# MAIN
################################################################################

while getopts ":b:t:h" opt; do
	case $opt in
	b)
		BASE="$OPTARG"
		;;
	t)
		TYPE="$OPTARG"
		;;
	h)
		usage 0
		;;
	*)
		echo "Invalid option: -$OPTARG"
		usage 1
		;;
	esac
done

if ! command_exists tput; then
	echo "'tput' is needed. Please install 'tput' ('ncurses')."
	exit 9
fi

echo
echo
echo_title "Check Prerequisites"

check_bash
set_install_log
set_before_script
set_after_script
set_packages_list
detect_hostname_fqdn
detect_operating_system
detect_architecture
check_if_root_or_die
check_travis

echo_step "Preparing to Install"; echo

# Detect package manager 
detect_installer

# Re-sync package index
resync_installer

# Checking if curl is installed
#  If not try to install curl
check_fetcher


echo_step "Creating scripts from base '$BASE'"; echo

# Set script sources
PACKAGE_SOURCES=(
	"$BASE/packages.list"
	"$BASE/$HOSTNAME_FQDN/packages.list"
	"$BASE/$TYPE/packages.list"
	"$BASE/$OPERATING_SYSTEM/packages.list"
	"$BASE/$OPERATING_SYSTEM/$TYPE/packages.list"
)

BEFORE_SOURCES=(
	"$BASE/before.sh"
	"$BASE/$HOSTNAME_FQDN/before.sh"
	"$BASE/$TYPE/before.sh"
	"$BASE/$OPERATING_SYSTEM/before.sh"
	"$BASE/$OPERATING_SYSTEM/$TYPE/before.sh"
)

AFTER_SOURCES=(
	"$BASE/after.sh"
	"$BASE/$HOSTNAME_FQDN/after.sh"
	"$BASE/$TYPE/after.sh"
	"$BASE/$OPERATING_SYSTEM/after.sh"
	"$BASE/$OPERATING_SYSTEM/$TYPE/after.sh"
)

# Create the script that runs BEFORE the installation.
build_script "${BEFORE_SOURCES[@]}" "$BEFORE_SCRIPT"

# Create the script that runs AFTER the installation.
build_script "${AFTER_SOURCES[@]}" "$AFTER_SCRIPT"

# Create a list of packages to install
build_script "${PACKAGE_SOURCES[@]}" "$PACKAGES_LIST"

echo_title "Install"

# macOS: Install the latest command line tools from XCode.
if command_exists xcode-select; then
	echo_step "Install the latest command line tools from XCode"
	xcode-select --install >>"$INSTALL_LOG" 2>&1
	# 0 = OK
	# 1 = command line tools are already installed
	if [ "$?" -gt 1 ]; then
		echo_warning "Failed to do xcode-select --install, will attempt to continue"
	else
		echo_success
	fi
fi

# Run BEFORE_SCRIPT
echo_step "Running BEFORE script"; echo
if [ -f "$BEFORE_SCRIPT" ]; then
	echo -e "\nsource $BEFORE_SCRIPT" >>"$INSTALL_LOG"
	# https://github.com/koalaman/shellcheck/wiki/SC1090
	# shellcheck source=/dev/null
	source "$BEFORE_SCRIPT"
else
	exit_with_failure "'$BEFORE_SCRIPT' not found."
fi

# Install all packages from PACKAGES_LIST
echo_step "Installing Packages"; echo
if [ -f "$PACKAGES_LIST" ]; then
	echo -e "\npackages list $PACKAGES_LIST" >>"$INSTALL_LOG"
	# IFS='' (or IFS=) prevents leading/trailing whitespace from being trimmed.
	# -r prevents backslash escapes from being interpreted.
	# || [[ -n $line ]] prevents the last line from being ignored if it doesn't end with a \n (since read returns a non-zero exit code when it encounters EOF).
	while IFS='' read -r PACKAGE || [[ -n "$PACKAGE" ]]; do
		if [[ "$PACKAGE" == [a-z]* ]] || [[ "$PACKAGE" == [A-Z]* ]]; then
			echo_step "  $PACKAGE"
			echo -e "\n$MY_INSTALLER $INSTALL $PACKAGE" >>"$INSTALL_LOG"
			if [[ $MY_INSTALLER == "brew" ]]; then
				$MY_INSTALLER $MY_INSTALL "$PACKAGE" | sudo tee -a "$INSTALL_LOG" 2>&1
			elif [[ $MY_INSTALLER == "slackpkg" ]]; then
				# not silent
				$MY_INSTALLER $MY_INSTALL "$PACKAGE"
			else
				$MY_INSTALLER $MY_INSTALL "$PACKAGE" >>"$INSTALL_LOG" 2>&1
			fi
			if [ "$?" -ne 0 ]; then
				echo_warning "Failed to install, will attempt to continue"
			else
				echo_success
			fi
		fi
	done < "$PACKAGES_LIST"
else
	exit_with_failure "'$PACKAGES_LIST' not found."
fi

# Run AFTER_SCRIPT
echo_step "Running AFTER script"; echo
if [ -f "$AFTER_SCRIPT" ]; then
	echo -e "\nsource $AFTER_SCRIPT" >>"$INSTALL_LOG"
	# shellcheck source=/dev/null
	source "$AFTER_SCRIPT"
else
	exit_with_failure "'$AFTER_SCRIPT' not found."
fi

echo_title "Done"

echo
echo
{ echo; debug_variables; } >>"$INSTALL_LOG"
