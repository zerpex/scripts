#!/bin/bash

# Exit script if system is not debian based
is_debian_based() {
  if [ ! -f /etc/debian_version ]; then
    echo -e "${LRED}[ ERR ]${END} This script has been writen for Debian-based distros."
    exit 0
  fi
}

# Check if a package is installed
# $1 = Package to check
# 0 = No
# 1 = Yes
is_package_installed() {
  if [[ ! -z $1  ]]; then
    echo $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c ' installed')
  fi
}

# Function to convert time in seconds to be human readable
time_convert () {
  SECS="$1"
  DAYS_TAKEN=$((SECS/86400))
  if [ "$DAYS_TAKEN" -ne "0" ]; then
     DAYS_DISPLAYED=""$DAYS_TAKEN"d & "
  fi
  echo "$DAYS_DISPLAYED"$(date -d "1970-01-01 + $SECS seconds" "+%-Hh %-Mmn %-Ss")
}

# Function to determine time taken to complete decryption/extraction
time_since () {
  NOW=$(date +%s)
  DIFF=$(( $NOW - $1 ))
  echo -e "Task duration: $(time_convert $DIFF)."
  echo -e " "
}

# Function to verify previous task completed successfully
verify () {
  if [ $? -eq 0 ]
  then
    echo -e " "
    echo -e "${SUCCESS}"
    echo -e " "
  else
    echo -e " "
    echo -e "${FAILED}" 1>&2
    echo -e " "
    if [ "$1" == "exit" ]; then
      exit 1
    fi
  fi
}

# Function to send a telegram message.
# Usage exemple :
#  telegram error "this is the message.\nIn two or\nmore lines." /var/log/mail.log
# File is optionnal.
telegram () {
  $TELEGRAM_PATH/telegram_notify.sh --"$1" --text "$2" $(if [ ! -z "$3" ]; then echo -n "--document "$3""; fi)
}
