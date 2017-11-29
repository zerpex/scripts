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

CONF_FILE=$WHEREAMI/backup_$(hostname).conf

# Includes :
source $CONF_FILE                             # Server configuration
source ${WHEREAMI%/*}/vars.sh                 # Global variables
source ${WHEREAMI%/*}/functions.sh            # Functions

# Check if config exist :
if [ ! -s "$CONF_FILE" ]; then
   echo "[ ${LRED}KO${END} ] "$CONF_FILE" does not exist or is empty."
   echo "-> Please set your configuration and stat this script again."
   exit 1
fi

# Other variables :
ARCHIVES=$BACKUP_DIR/$HNAME/$ARCH_DIR

# Define compression level and extension to use :
case $COMPRESSION in
  No)
    LVL=
    EXT=
    ;;
  gzip)
    LVL=z
    EXT=.gz
    ;;
  bzip2)
    LVL=j
    EXT=.bz2
    ;;
  lzma)
    LVL=J
    EXT=.xz
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
   for i in "${COLD_SERVICE[@]}"; do
      SUCCESS="[ ${LGREEN}OK${END} ] Service "$i" stopped."
      FAILED="[ ${LRED}KO${END} ] Service "$i" did not stop as expected."
      /etc/init.d/"$i" stop
      verify
   done
fi

# Set exclusion's pattern
EXCLUDES=()
for j in "${BCK_EXCLUDE[@]}"; do
    EXCLUDES+=(--exclude "$j")
done

# Do the backup :
echo -e " "
echo ${LCYAN}-- Backups :${END}
for i in "${BCK_TARGET[@]}"; do
   START=$(date +%s)
   SUCCESS="[ ${LGREEN}OK${END} ] Backup of "$i" successfull."
   FAILED="[ ${LRED}KO${END} ] "$i"'s backup is KO."
   FOLDER="$(echo "$i" | awk -F/ '{print $3}')"
   if [ "$BCK_METHOD" == "Copy" ]; then
      cp -r "$i" "$BCK_DIR"/
   elif [ "$BCK_METHOD" == "Archive" ]; then
      tar cf"$LVL" \
          "${EXCLUDES[@]}" \
          "$BCK_DIR"/"$FOLDER"-"$(date +"%Y%m%d-%H%M%S")"-"$BCK_TYPE".tar"$EXT" \
          -g "$BCK_DIR"/"$SNAP_DIR"/"$FOLDER".snar \
          "$i"
   fi
   verify
   echo -e "$i backup duration: $(time-taken $START)
done

# Start services if needed :
if [ "$BCK_TYPE" == "FULL" ] && [ "$COLD_BCK" == "Yes" ]; then 
   for i in "${COLD_SERVICE[@]}"; do
      SUCCESS="[ ${LGREEN}OK${END} ] Service "$i" started."
      FAILED="[ ${LRED}KO${END} ] Service "$i" did not start as expected."
      /etc/init.d/"$i" start
	  verify
   done
fi

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
      echo -e "$i synchonization duration: $(time-taken $START)
   done
fi 

echo -e " "
echo -e "Total backup duration: $(time_since $SCRIPT_START)."
