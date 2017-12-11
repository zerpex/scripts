#!/bin/bash
# set -x
#
# -- disk_usage.sh --
#
# INTRODUCTION:
#--------------
#
# This script monitor the disk space and send a message on alert.
#
# HOW TO USE THIS SCRIPT :
#-------------------------
#
# 1- Copy disk_usage_sample.conf to disk_usage_hostname.conf where "hostname" is the hostname of the server.
# 2- Edit disk_usage_hostname.conf and set all parameters as you wish.
# 3- Execute the script.
#    You can call it through crontab directly.
#
###################################################################################
#                                     /!\                                         #
#   /!\  Unless you know exactly what you're doing, do not change anything  /!\   #
#   /!\ on this file, set your parameters on the file backup_hostname.conf  /!\   #
#                                     /!\                                         #
###################################################################################

# Determine where this script is stored :
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPT_PATH=${WHEREAMI%/*}

CONF_FILE=$WHEREAMI/disk_usage_$(hostname).conf

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
   echo "[ ${LRED}KO${END} ] ${LCYAN}"$SCRIPT_PATH/functions.sh"{END} does not exist or is empty."
   echo "-> Please put the functions.sh file on the right path and start this script again."
   exit 1
fi

# Server configuration : If configuration file exist, load it. Else exit.
if [ -s "$CONF_FILE" ]; then
   source $CONF_FILE
else
   echo "[ ${LRED}KO${END} ] ${LCYAN}"$CONF_FILE"{END} does not exist or is empty."
   echo "-> Please set your configuration and start this script again."
   exit 1
fi

#
#::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
#

for i in "${PARTITION[@]}"; do
  DISK_USAGE=$(df $i -h | tail -n +2 | awk '{print $5}' | sed 's/.$//')
  if [ $DISK_USAGE -ge $ALERT ] ; then
     ALARM+=(- $i: $DISK_USAGE%\\n)
  fi
done

if [ ! -z "$ALARM" ]; then
  MSG="Running out of space on server $(hostname):\n${ALARM[@]}"
  telegram error "$MSG"
fi
