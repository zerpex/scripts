#!/bin/bash
#
# -- check_websites.sh --
# 
# INTRODUCTION:
# -------------
#
# This script scan all containers exposed to the front-end looking for the url associated.
# Then, it check the service behind for a 200 http code.
# If not found, it restart the container and check again.
# if still KO, send a telegram notification with docker logs of the container.
#
# TESTED WITH :
# ------------
#
#  - Traefik
#  - nginx from jwilder
#  - custom label cw.check.url
#
# HOW TO USE THIS SCRIPT :
# ------------------------
# 
# 1- Edit check-websites.conf and set all parameters as you wish.
# 3- Execute the script.
#    You can call it through crontab directly.
#
# PRE-REQUISITES :
# ----------------
#
#   - Get telegram-notify.sh & telegram-notify.conf from Nicolas Bernaerts :
#      wget https://raw.githubusercontent.com/NicolasBernaerts/debian-scripts/master/telegram/telegram-notify-install.sh
#      wget https://raw.githubusercontent.com/NicolasBernaerts/debian-scripts/master/telegram/telegram-notify.conf
#   - Create a telegram bot :
#      Follow steps 1 to 13 here : https://github.com/topkecleon/telegram-bot-bash
#      /!\ Note down the API key given by @BotFather
#   - Get user ID :
#      + Send a message to your Bot from your Telegram client
#      + Call the following URL from any web browser. XXXXX = your API key.
#          https://api.telegram.org/botXXXXX/getUpdates
#          In the page displayed, you'll get some information. search for "from":"id":YYYYY, ". YYYYY is your user ID.
#   - Update telegram-notify.conf with your telegram API key and user ID.
# 
# AUTHOR :
# --------
#   Baltho ( cg.cpam@gmail.com )
#
# VERSIONS :
# ----------
#   - 2017-11-29: v1.2 - Separate script configuration for better readability.
#   - 2017-07-31: v1.1 - Custom URL test : If you have a url different from the base one to test,
#                                          you can set a new label to your container :
#                                          cw.check.url=sdom.domain.tld/location/file.ext
#                      - Better log management : Only 1 line used when all checks are OK. 
#                                          You cant see details of the last test on the .last file
#                                          stored on the same location thant the log file.
#   - 2017-07-28: v1.0 - First release.
#
###################################################################################
#                                     /!\                                         #
#   /!\  Unless you know exactly what you're doing, do not change anything  /!\   #
#   /!\  on this file, set your parameters on the file check-websites.conf  /!\   #
#                                     /!\                                         #
###################################################################################

# Determine where this script is stored :
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Includes :
source $WHEREAMI/check-websites.conf          # Load configuration
source ${WHEREAMI%/*}/vars.sh                 # Global variables
source ${WHEREAMI%/*}/functions.sh            # Functions

# Paths
SCRIPT_LOG_FILE=$LOGS_PATH/$LOG_FILE_NAME.log
LOG_TEMP=$LOGS_PATH/$LOG_FILE_NAME.last

#--- Set log header
echo " " > $LOG_TEMP
echo "+----------------+---------------+--------------+" >> $LOG_TEMP
echo "| $DATE" >> $LOG_TEMP
echo "|" >> $LOG_TEMP

cd $TELEGRAM_PATH
# Check all running containers
for i in $(docker network inspect $DOCKER_FRONTEND_NETWORK | grep Name | sed 1d | awk -F\" '{print $4}')
 do
   # Get url associated to the container from traefik label "traefik.frontend.rule" or from environnement variable "VIRTUAL_HOST" if using nginx
   URL=$(docker inspect $i | grep cw.check.url | awk -F"\"" '{print $4}')
   if [ -z "$URL" ]; then
     URL=$(docker inspect $i | grep traefik.frontend.rule | awk -F":" '{print $3}' | awk -F\" '{print $1}')
     if [ -z "$URL" ]; then
       URL=$(docker inspect $i | grep VIRTUAL_HOST | awk -F"=" '{print $2}' | awk -F\" '{print $1}')
     fi
   fi
   DOCKER_SCRIPT_LOG_FILE=$LOGS_PATH/cw_$i.log
   if [ ! -z "$URL" ]; then
     # If there is a URL on that container, get http code associated
     RESULT=$(curl -s -o /dev/null -w "%{http_code}" -L $URL)
     if [ "$RESULT" != "200" ]; then
	   # If website is KO, restart the container
       echo [ ${LRED}KO${END} ] ${LYELLOW}https://$URL${END} down with code $RESULT. Try restarting container $i... >> $LOG_TEMP
       docker restart $i >/dev/null
       sleep 10
       RESULT2=$(curl -s -o /dev/null -w "%{http_code}" -L $URL)
	   # If website is still KO after a container restart, notify through telegram with container's logs
       if [ "$RESULT2" != "200" ]; then
         echo [ ${LRED}ERR${END} ] ${LYELLOW}https://$URL${END} is still ${LRED}KO${END} with http code : $RESULT2. Please check $i ! >> $LOG_TEMP
         if [ ! -f $NOTIFIED_LIST ] || [[ ! " $(cat $NOTIFIED_LIST) " =~ " $i " ]]; then
		   docker logs $i > $DOCKER_SCRIPT_LOG_FILE 2>/dev/null
           ./telegram_notify.sh --error --text "https://"$URL" is DOWN\nhttp code "$RESULT2"\nPlease check "$i" logs" --document $DOCKER_SCRIPT_LOG_FILE
           echo $i >> $NOTIFIED_LIST
         fi
	   else
	     # If website if OK after a container's restart, notify it through telegram
	     ./telegram_notify.sh --success --text "https://"$URL" was KO, but is OK after $i's restart"
       fi
     else
       echo [ ${LGREEN}OK${END} ] https://$URL is up. >> $LOG_TEMP
       while read line; do
         if [ $line = "$i" ]; then
		   # If a previously KO website is now OK, notify it through telegram
           ./telegram_notify.sh --success --text "https://"$URL" is back online"
           sed -i /$i/d $NOTIFIED_LIST
         fi
       done < $NOTIFIED_LIST
     fi
   fi
done

while read CHECK; do
  CHECK_KO=$(echo $CHECK | grep ERR)
  CHECK_STRING=${CHECK_KO/]/] $DATE : }
  if [ ! -z "$CHECK_KO" ]; then
    echo $CHECK_STRING >> $SCRIPT_LOG_FILE
    SITE_KO=1
  fi
done < $LOGS_PATH/$LOG_FILE_NAME.last
if [ "$SITE_KO" != "1" ]; then
  echo [ ${LGREEN}OK${END} ] $DATE : All checks are OK >> $SCRIPT_LOG_FILE
fi

if [ ! -s $NOTIFIED_LIST ]
then
  # If previously notified list is empty, remove file
  rm -f $NOTIFIED_LIST
fi 
