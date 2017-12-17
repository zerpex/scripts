#!/bin/bash
#
# -- backup.sh --
#
# INTRODUCTION:
#--------------
#
# This script backup specified folders using different methods :
#  - Simple copy
#  - Archive without compression
#  - Archive with compression :
#     low = gzip
#     medium = bzip2
#     high = lzma
#
# HOW TO USE THIS SCRIPT :
#-------------------------
#
# 1- Copy backup_sample.conf to backup_hostname.conf where "hostname" is the hsotname of the server.
# 2- Edit backup_hostname.conf and set all parameters as you wish.
# 3- Execute the script.
#    You can call it through crontab directly.
#
# NOTES :
#--------
#
# - If you want to start a manual full backup, just start the script with "full" parameter. ie :
#    /data/scripts/backup.sh full
#
# Crontab : Each days at 4am:
# 0 4 * * * /data/scripts/backup.sh
#
# To restore an incremental backup, use :
#   tar -xjpf BACKUP_FULL.tar.bz2
# and then :
#   tar -xjpf BACKUP_INC.tar.bz2
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

CONF_FILE=$WHEREAMI/backup_$(hostname).conf

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

# Other variables :
ARCHIVES=$BACKUP_DIR/$HNAME/$ARCH_DIR

# Set exclusion's pattern
EXCLUDES=()
for j in "${BCK_EXCLUDE[@]}"; do
    EXCLUDES+=(--exclude "$j")
done

# Define compression level and extension to use :
case $COMPRESSION in
  No)
    LVL=
    EXT=
    ;;
  gzip)
    LVL=z
    EXT=.gz
    COMPRESS=gzip
    ;;
  bzip2)
    LVL=j
    EXT=.bz2
    COMPRESS=bzip2
    ;;
  lzma)
    LVL=J
    EXT=.xz
    COMPRESS="xz -k9"
    ;;
esac

# Calendar checks to determine day number of the full backup :
case $FULL_BCK_DAY in
  Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)
	for i in $(ncal -h | grep ${FULL_BCK_DAY:0:2} | grep -o '\<[0-9]\+'); do
		if [ "$CUR_DAY" == "$i" ]; then
			DDAY=$i
		fi
	done
    ;;
  [1-28])
    DDAY=$FULL_BCK_DAY
    ;;
  [29-31])
    echo -e " [ ${LYELLOW}WARNING${END} ] Full backup ${LRED}wont${END} be done some months ( February ...)"
    echo -e "Please enter value from 1 to 28 or use other cycle methods or 'LastDay'."
    exit 1
    ;;
  LastDay)
    DDAY=$(cal | awk 'NF {DAYS = $NF}; END {print DAYS}')
    ;;
  *)
    echo -e "Please enter correct value."
    exit 1
    ;;
esac

# Determine if Full or Incremental backup :
if [ "$CUR_DAY" == "$DDAY" ] || [ "$1" == "full" ]; then
   BCK_DIR=$BACKUP_DIR/$HNAME/$DATE
   BCK_TYPE=FULL
   echo -e "Let's start a full backup on this wonderfull "$FULL_BCK_DAY" !"
   if [ -d "$BACKUP_DIR"/"$HNAME" ]; then
      mv "$BACKUP_DIR"/"$HNAME"/"$(ls -t "$BACKUP_DIR"/"$HNAME" | grep -v "$ARCH_DIR" | head -1)" "$ARCHIVES"
   fi
   mkdir -p "$BCK_DIR"/"$SNAP_DIR" "$ARCHIVES"
else
   BCK_DIR="$BACKUP_DIR"/"$HNAME"/"$(ls -tr "$BACKUP_DIR"/"$(hostname)"/ | grep -v "$ARCH_DIR" | head -1)"
   BCK_TYPE=INC
   echo -e "Let's start an incremental backup !"
fi

# Stop services if needed for full backups :
if [ "$BCK_TYPE" == "FULL" ] && [ "$COLD_BCK" == "Yes" ]; then
   # If using check_websites.sh, disable it :
   echo "$( crontab -l | sed 's/.*check_websites.sh/#&/' )" | crontab
   for i in "${COLD_SERVICE[@]}"; do
      SUCCESS="[ ${LGREEN}OK${END} ] Service "$i" stopped."
      FAILED="[ ${LRED}KO${END} ] Service "$i" did not stop as expected."
      /etc/init.d/"$i" stop
      verify
   done
fi

# Do the backup :
echo -e " "
echo ${LCYAN}-- Backups :${END}
j=0
START_TOTAL=$(date +%s)
for i in "${BCK_TARGET[@]}"; do
   START=$(date +%s)
   SUCCESS="[ ${LGREEN}OK${END} ] Backup of "$i" successfull."
   FAILED="[ ${LRED}KO${END} ] "$i"'s backup terminated with exceptions."
   FOLDER[$j]="$(echo "$i" | awk -F/ '{print $3}')"
   if [ "$BCK_METHOD" == "Copy" ]; then
      cp -r "$i" "$BCK_DIR"/
   elif [ "$BCK_METHOD" == "Archive" ]; then
      BCK_FILE[$j]="$BCK_DIR"/"${FOLDER[$j]}"-"$(date +"%Y%m%d-%H%M%S")"-"$BCK_TYPE".tar
      tar cf \
          "${BCK_FILE[$j]}" \
          "${EXCLUDES[@]}" \
          -g "$BCK_DIR"/"$SNAP_DIR"/"$FOLDER".snar \
          "$i"
	  ((j++))
   fi
   verify
   echo -e "$i backup duration: $(time_since $START)"
done
echo -e " "
echo -e "Total backup duration: $(time_since $START_TOTAL)"

# Start services if needed :
if [ "$BCK_TYPE" == "FULL" ] && [ "$COLD_BCK" == "Yes" ]; then
   if [ "$COLD_SCRIPT" == "Yes" ]; then
      source "$COLD_SCRIPT_FILE"
   fi
   for i in "${COLD_SERVICE[@]}"; do
      SUCCESS="[ ${LGREEN}OK${END} ] Service "$i" started."
      FAILED="[ ${LRED}KO${END} ] Service "$i" did not start as expected."
      /etc/init.d/"$i" start
	  verify
   done
   # If using check_websites.sh, enable it back :
   echo "$( crontab -l | sed '/.*check_websites.sh/s/^#//' )" | crontab
fi

# Compress files if needed :
START_TOTAL=$(date +%s)
if [ "$COMPRESSION" == "gzip" ] || [ "$COMPRESSION" == "bzip2" ] || [ "$COMPRESSION" == "lzma" ]; then
   for i in "$(ls "$BCK_DIR"/*.tar)"; do
      START=$(date +%s)
      SUCCESS="[ ${LGREEN}OK${END} ] "$i" compressed."
      FAILED="[ ${LRED}KO${END} ] "$i" was not compressed."
      $COMPRESS $i
	  if [ "$COMPRESSION" == "lzma" ]; then rm $i; fi
	  verify
      echo -e "$i compression duration: $(time_since $START)"
   done
fi
echo -e "Total compression duration: $(time_since $START_TOTAL)"

# Remove older archives than wanted :
while [ "$(ls "$ARCHIVES" | wc -l)" -gt "$RETENTION" ]; do
   OLDEST=$(ls -tr "$ARCHIVES" | head -1)
   rm -r "$OLDEST"
   echo -e ""$OLDEST" removed."
done

# Synchronize backups with other sites :
if [ "$SYNCRONIZATION" == "Yes" ]; then
   echo -e " "
   echo ${LCYAN}-- Synchronizations :${END}
   for i in "${BCK_SYNC[@]}"; do
      START=$(date +%s)
      SUCCESS="[ ${LGREEN}OK${END} ] Synchronization with "$i" is successfull."
      FAILED="[ ${LRED}KO${END} ] Synchronization with "$i" is KO."
      rsync -rtuv --delete-after "$BACKUP_DIR"/"$HNAME" "$i"
      if [ "$DIST_BCK" == "Yes" ]; then
         rsync -rtuv --delete-after "$i"/"$DIST_HOST" "$BACKUP_DIR"
      fi
      verify
      echo -e "$i synchonization duration: $(time_since $START)"
   done
fi

echo -e " "
echo -e "Total backup duration: $(time_since $SCRIPT_START)."

# Send a message through telegram :
if [ "$SEND_TELEGRAM_MSG" == "Yes" ]; then
  MSG_DATA=()
  j=0
  for i in "${FOLDER[@]}"; do
     BCK_FILE_SIZE=$(ls -lash "${BCK_FILE[$j]}""$EXT" | awk '{print $6}')
     MSG_DATA+=(- $i: $BCK_FILE_SIZE\\n)
	 ((j++))
  done
  MSG="Backup finished !\n$(time_since $SCRIPT_START)\nBackuped archives: \n${MSG_DATA[@]}"
	telegram success "$MSG" /var/log/backup.log
  #$TELEGRAM_PATH/telegram_notify.sh --success --text "$MSG" --document /var/log/backup.log
fi
