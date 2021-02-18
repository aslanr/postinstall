#
# before.sh for all OPERATING_SYSTEMs and TYPEs
#

#
# User Configuration
#

# My default username
export MY_USERNAME='iqm'
export MY_USERNAME_COMMENT='IQ Messenger'

# Check if user exists, if not create user and add to group wheel (for sudo)
if id -u "$MY_USERNAME" >> "$INSTALL_LOG" 2>&1; then
	echo -e "\nuser $MY_USERNAME found" >>"$INSTALL_LOG"
else
	echo -e "\ncreate new user $MY_USERNAME" >>"$INSTALL_LOG"
	echo_step "  Create user and add to group 'wheel'"
	echo_step_info "$MY_USERNAME"
	case $OPERATING_SYSTEM in
		REDHAT)
			if command_exists adduser; then
				if adduser --shell "/bin/bash" --password "paqemd8ny15g2" --comment "$MY_USERNAME_COMMENT" --create-home --user-group "$MY_USERNAME" >> "$INSTALL_LOG" 2>&1; then
					if grep "wheel" /etc/group >> "$INSTALL_LOG" 2>&1; then
						usermod -a -G wheel "$MY_USERNAME" >> "$INSTALL_LOG" 2>&1
					fi
					echo_success
				else
					echo_warning "User '$MY_USERNAME' could not be created, will attempt to continue"
				fi
			else
				echo_warning "Command 'adduser' not found, will attempt to continue"
			fi
			;;
	esac
	
	# Change password
	if id -u "$MY_USERNAME" >> "$INSTALL_LOG" 2>&1; then
		if [ -z "$TRAVIS" ]; then
			echo_step "  Change password"
			echo
			echo
			echo -e "\n passwd $MY_USERNAME" >>"$INSTALL_LOG"
			passwd "$MY_USERNAME"
			echo
		else
			echo "!!! Travis CI detected. No password change !!!" >>"$INSTALL_LOG"
		fi
	fi
fi

# Get primary user group from user
echo_step "  Get primary user group from user"
echo_step_info "$MY_USERNAME"
echo -e "\nid -gn $MY_USERNAME" >>"$INSTALL_LOG"
if id -gn "$MY_USERNAME" >> "$INSTALL_LOG" 2>&1; then
	MY_PRIMARY_GROUP=$(id -gn "$MY_USERNAME" >> "$INSTALL_LOG" 2>&1)
	export MY_PRIMARY_GROUP
	echo "primary user group from user $MY_USERNAME is $MY_PRIMARY_GROUP" >>"$INSTALL_LOG"
	echo_success
else
	echo_warning "User '$MY_USERNAME' does not exist, will attempt to continue"
fi