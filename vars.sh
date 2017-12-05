#!/bin/bash
#
# Set generic variables

#--- Set the current day number :
CUR_DAY=$(date +%-d)

# Set the current day :
DATE=$(date +%Y%m%d)

#--- Mark script starting date
SCRIPT_START=$(date +%s)

# Determine where the script is stored :
WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Path of the telegram-notify.sh script :
TELEGRAM_PATH=${WHEREAMI%/*}/telegram

#--- Define text colors
RED=$(echo -en '\033[00;31m')
GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
BLUE=$(echo -en '\033[00;34m')
PURPLE=$(echo -en '\033[00;35m')
CYAN=$(echo -en '\033[00;36m')
LGRAY=$(echo -en '\033[00;37m')
LRED=$(echo -en '\033[01;31m')
LGREEN=$(echo -en '\033[01;32m')
LYELLOW=$(echo -en '\033[01;33m')
LBLUE=$(echo -en '\033[01;34m')
LPURPLE=$(echo -en '\033[01;35m')
LCYAN=$(echo -en '\033[01;36m')
WHITE=$(echo -en '\033[01;37m')
END=$(echo -en '\033[0m')

# Test
#echo ${RED}RED ${GREEN}GREEN ${YELLOW}YELLOW ${BLUE}BLUE ${PURPLE}PURPLE ${CYAN}CYAN ${WHITE}WHITE${RESTORE}
#echo ${LRED}LRED ${LGREEN}LGREEN ${LYELLOW}LYELLOW ${LBLUE}LBLUE ${LPURPLE}LPURPLE ${LCYAN}LCYAN ${LGRAY}LIGHTGRAY${END}

#--- Define local system variables
LAN=$(hostname -I | awk '{print $1}')
WAN=$(dig +short myip.opendns.com @resolver1.opendns.com)
FQDN=$(hostname -f)
HNAME=$(hostname)
