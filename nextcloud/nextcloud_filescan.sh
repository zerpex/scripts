#!/bin/bash
#
# -- nextcloud_filescan.sh --
#
# INTRODUCTION:
#--------------
#
# This simple script automate files scanning and database cleaning for nextcloud.
# It is not recommanded for daily use, but I did not find any other way to keep
# an updated nextcloud database while making change on the filesystem by any other
# way than nextcloud itself.
# Actualy, If you upload a file through ftp to your server, it will not be displayed
# on nextcloud until a filescan is made.
# 
# HOW TO USE THIS SCRIPT :
#-------------------------
# 
# 1- Set the few variable bellow to meet your configuration.
# 2- Execute the script.
#    You can call it through crontab directly.
# 

# Is nextcloud installed through docker or not ( Yes / No ) ?
DOCKER=Yes

# If nextcloud is installed through docker, set container name :
CONTAINER_NAME=cloud-nextcloud

# If nextcloud is installed locally, set the full path :
NEXTCLOUD_PATH=/var/www/html/nextcloud

# Set log file path and name :
LOG_FILE=/var/log/nextcloud_filescan.log

###################################################################################
#                                     /!\                                         #
#   /!\  Unless you know exactly what you're doing, do not change anything  /!\   #
#                                     /!\                                         #
###################################################################################

# Determine where this script is stored :
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Includes :
source $WHEREAMI/check-websites.conf          # Load configuration
source ${WHEREAMI%/*}/vars.sh                 # Global variables
source ${WHEREAMI%/*}/functions.sh            # Functions

echo " " >> $LOG_FILE
echo "+----------------+---------------+--------------+" >> $LOG_FILE
echo "| $DATE |" >> $LOG_FILE
echo " " >> $LOG_FILE
echo "Scanning files..." >> $LOG_FILE
if [ "$DOCKER" == "Yes" ]; then
   COMMAND="/usr/bin/docker exec "$CONTAINER_NAME" occ files:scan --all" >> $LOG_FILE
else
   COMMAND="$NEXTCLOUD_PATH/occ files:scan --all" >> $LOG_FILE
fi

echo " " >> $LOG_FILE
echo "Cleaning up files..." >> $LOG_FILE
if [ "$DOCKER" == "Yes" ]; then
   COMMAND="/usr/bin/docker exec "$CONTAINER_NAME" occ files:cleanup" >> $LOG_FILE
else
   COMMAND="$NEXTCLOUD_PATH/occ files:cleanup" >> $LOG_FILE
fi

echo "| Files scann & cleaning complete." >> $LOG_FILE
echo "+----------------+---------------+--------------+" >> $LOG_FILE
