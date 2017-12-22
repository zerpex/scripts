#!/bin/bash
#
# -- ssh_logon.sh --
#
# INTRODUCTION:
#--------------
#
# This script send a telegram message each time a user login to
# your server through ssh.
#
# HOW TO USE THIS SCRIPT :
#-------------------------
#
# 1. Just execute it manually one time with root privileges.

# Determine where this script is stored :
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_PATH=${WHEREAMI%/*}

# Global variables : If var.sh file exist, load it. Else exit.
if [ -s "$SCRIPT_PATH/vars.sh" ]; then
   source $SCRIPT_PATH/vars.sh
else
   echo "[ ${LRED}KO${END} ] ${LCYAN}"$SCRIPT_PATH/vars.sh"{END} does not exist or is empty."
   echo "-> Please put the var.sh file on the right path and start this script again."
   exit 1
fi

# Functions : If functions.sh file exist, load it. Else exit.
if [ -s "$SCRIPT_PATH/functions.sh" ]; then
   source $SCRIPT_PATH/functions.sh
else
   echo "[ ${LRED}KO${END} ] "$SCRIPT_PATH/functions.sh" does not exist or is empty."
   echo "-> Please put the functions.sh file on the right path and start this script again."
   exit 1
fi

# Activate script on first start :
if grep -q "ssh_logon.sh" /etc/pam.d/sshd; then
  # Send the message :
  telegram question "User "$PAM_USER" just logged in on "$HOSTNAME" :\nRemote host: "$PAM_RHOST"\nRemote user: "$PAM_RUSER"\nService: "$PAM_SERVICE"\nTTY: "$PAM_TTY""
else
  echo -e "[ ${LYELLOW}WARNING${END} ] The script is not activated yet."
  echo -e "Activating now..."
{
  echo " "
  echo "# Send telegram message on ssh login :"
  echo "session optional pam_exec.so type=open_session seteuid "$WHEREAMI"/ssh_logon.sh"
} >> /etc/pam.d/sshd
  if grep -q "ssh_logon.sh" /etc/pam.d/sshd; then
    echo -e "[ ${LGREEN}OK${END} ] The script is activated."
  else
    echo -e "[ ${LRED}KO${END} ] I was not able to activate the script. Please be sure to run the script with root privileges."
    echo -e "Or you can do it manually by adding the following command at the end of /etc/pam.d/sshd :"
    echo -e "session optional pam_exec.so type=open_session seteuid "$WHEREAMI"/ssh_logon.sh"
  fi
fi
