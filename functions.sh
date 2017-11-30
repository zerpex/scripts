#!/bin/bash

# Function to convert time in seconds to be human readable 
time_convert () {
   SECS="$1"
   echo $((SECS/86400))" days "$(date -d "1970-01-01 + $SECS seconds" "+%H hours %M minutes %S seconds")
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
    exit 1
   fi
}

# Function to send a telegram message.
# Usage exemple :
#  telegram error "this is the message.\nIn two or\nmore lines." /var/log/mail.log
# File is optionnal.
telegram () {
   cd $TELEGRAM_PATH
   ./telegram_notify.sh --"$1" --text "$2" $(if [ -z "$3" ]; then echo -n "--document "$3""; fi)
   cd $WHEREAMI
}
