#!/bin/bash
#
# -- new_server.sh --
#
# INTRODUCTION:
#--------------
#
# This fully customizable script install and configure base things for a new server :
# - Create groups and users
# - Install tools
# - Set aliases
# - Install Oh My zsh
# - Install docker & docker-compose
# - Install and set replicated folders using glusterfs
# - Install and set merged folders using mergerfs
# 
# HOW TO USE THIS SCRIPT :
#-------------------------
# 
# 1- Copy new_install_sample.conf to new_install_hostname.conf where "hostname" is the hsotname of the server.
# 2- Edit new_install_hostname.conf and set all parameters as you wish.
# 3- Execute the script.
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

CONF_FILE=$WHEREAMI/new_install_$(hostname).conf

# Server configuration : If configuration file exist, load it. Else exit.
if [ -s "$CONF_FILE" ]; then
   source $CONF_FILE
else
   echo "[ ${LRED}KO${END} ] ${LCYAN}"$CONF_FILE"{END} does not exist or is empty."
   echo "-> Please set your configuration and start this script again."
   exit 1
fi

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

# Check if config exist :
if [ ! -s "$CONF_FILE" ]; then
   echo "[ ${LRED}KO${END} ] "$CONF_FILE" does not exist or is empty."
   echo "-> Please set your configuration and stat this script again."
   exit 1
fi

NB_REPLICA="${#REPLICA[@]}"
NB_REPLICA_SRC="${#REPLICA_SRC[@]}"

# Update local repository & upgrade system
apt update
apt -y upgrade

# Set locales
cp /etc/locale.gen /etc/locale.gen.old
sed -i "s@# $TZ UTF-8@$TZ UTF-8@g" /etc/locale.gen
/usr/sbin/locale-gen
export LANG=$TZ

# Install pre-requiresites
apt -y install \
  $(if [ "$BASE_TOOLS" == "Yes" ]; then  \
	echo -n "sudo "; \
        echo -n "lshw "; \
	echo -n "htop "; \
	echo -n "locate "; \
	echo -n "wget "; \
	echo -n "pwgen "; \
	echo -n "git "; \
	echo -n "curl "; \
	echo -n "smartmontools "; \
	echo -n "smem "; \
	echo -n "ncdu "; \
	echo -n "ntp "; \
	echo -n "ntpdate "; \
  fi) \
  $(if [ "$NETWORK_TOOLS" == "Yes" ]; then  \
	echo -n "dnsutils "; \
	echo -n "nfs-common "; \
	echo -n "sshfs "; \
	echo -n "sshpass "; \
  fi) \
  $(if [ "$VOLUME_TOOLS" == "Yes" ]; then  \
	echo -n "aufs-tools "; \
	echo -n "glusterfs-server "; \
	echo -n "mergerfs "; \
  fi) \
  $(if [ "$OH_MY_ZSH" == "Yes" ]; then  \
	echo -n "zsh "; \
  fi) \
  $(if [ "$DOCKER" == "Yes" ]; then  \
	echo -n "apt-transport-https "; \
	echo -n "ca-certificates "; \
	echo -n "gnupg2 "; \
	echo -n "software-properties-common "; \
  fi) 

# Create groups
if [ "$CREATE_GROUP" == "Yes" ]; then 
	j=0
    START=$(date +%s)
	export i
	echo ${LCYAN}-- Group creation${END}
	for i in "${GROUP[@]}"; do
        SUCCESS="[ ${LGREEN}OK${END} ] Group "$i" created successfully."
        FAILED="[ ${LRED}KO${END} ] Group "$i" creation failled."
		groupadd "${GROUP[$j]}" "$(if [ ! -z "${GROUP_ID[$j]}" ]; then echo -n "-g ${GROUP_ID[$j]}"; fi)"
		((j++))
        verify
	done
    echo -e "Groups creation duration: $(time-taken $START)"
	echo " "
fi
# Create users
if [ "$CREATE_USER" == "Yes" ]; then 
	j=0
    START=$(date +%s)
	export i
	echo ${LCYAN}-- Users creation${END}
	for i in "${USER[@]}"; do
        SUCCESS="[ ${LGREEN}OK${END} ] User "$i" created successfully."
        FAILED="[ ${LRED}KO${END} ] User "$i" creation failled."
		adduser --disabled-password --gecos "" "${USER[$j]}"
		USER_PASS=${USER_PASS[$j]}
		UPASS="${USER_PASS:-$(pwgen -s 24 1)}"
		echo "${USER[$j]}:$UPASS" | chpasswd
		echo -e " [ ${LGREEN}OK${END} ] User ${USER[$j]} created with password : $UPASS"
		if [ "${USER_SUDO[$j]}" == "Yes" ]; then adduser "${USER[$j]}" sudo; fi
		if [ "${USER_DOCKER[$j]}" == "Yes" ]; then adduser "${USER[$j]}" docker; fi
		if [ ! -z "${USER_GROUP[$j]}" ]; then adduser "${USER[$j]}" "${USER_GROUP[$j]}"; fi
		echo " "
		((j++))
        verify
	done
    echo -e "Groups creation duration: $(time-taken $START)"
	echo " "
fi

# Install docker
if [ "$DOCKER" == "Yes" ]; then 
	echo ${LCYAN}-- Docker installation${END}
	curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add 
	add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
	apt-get update
	apt-get -y install docker-ce
	if [ -z $(docker --version | grep "not found") ];
		then echo -e "[ ${LGREEN}OK${END} ] Docker installed"
		else echo -e "[ ${LRED}KO${END} ] /!\ Docker is NOT installed"
	fi
	echo " "
fi

# Install docker-compose
if [ "$DOCKER_COMPOSE" == "Yes" ]; then 
	echo ${LCYAN}-- Docker-compose installation${END}
	DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-$(curl https://github.com/docker/compose/releases | grep releases/tag | grep -v rc | awk -F">" '{print $2}' | awk -F"<" '{print $1}' | head -1)}"
	curl -L https://github.com/docker/compose/releases/download/"$DOCKER_COMPOSE_VERSION"/docker-compose-"$(uname -s)"-"$(uname -m)" > /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	if [ -z "$(docker-compose --version | grep "not found")" ];
		then echo -e "[ ${LGREEN}OK${END} ] Docker installed"
		else echo -e "[ ${LRED}KO${END} ] /!\ Docker is NOT installed"
	fi
	echo " "
fi

# Mount SSHFS volumes
if [ "$SSHFS" == "Yes" ]; then
	j=0
	export i
	ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa
	echo ${LCYAN}-- SSHFS volumes creation${END}
	for i in "${REMOTE_HOST[@]}"; do
		echo -e "${REMOTE_IP[$j]}  ${REMOTE_HOST[$j]}" >> /etc/hosts
		mkdir -p "${MOUNT_TARGET[$j]}"
		sshpass -p "${REMOTE_USER_PASS[$j]}" ssh-copy-id -o StrictHostKeyChecking=no -i /root/.ssh/id_rsa.pub "${REMOTE_USER[$j]}"@"${REMOTE_IP[$j]}"
		echo -e "sshfs#${REMOTE_USER[$j]}@${REMOTE_IP[$j]}:${REMOTE_PATH[$j]}                ${MOUNT_TARGET[$j]}          fuse            port=22,user,noauto,noatime,allow_other     0 0" >> /etc/fstab
		mount "${MOUNT_TARGET[$j]}"
		if [ -z "$(df -hT | grep "${MOUNT_TARGET[$j]}")" ]; then
			echo -e "[ ${LRED}KO${END} ] /!\ ${MOUNT_TARGET[$j]} is NOT mounted."
		else
			echo -e "[ ${LGREEN}OK${END} ] ${MOUNT_TARGET[$j]} is mounted."
		fi
		((j++))
	done
	echo " "
fi

# Set and mount replicated folders :
if [ "$REPLICATE_FOLDERS" == "Yes" ]; then 
	k=0
	l=0
	for i in "${REPLICA_SRC[@]}"; do
		HOSTNAME="$(echo "$i" | awk -F: '{print $1}')"
		REPLICA_PATH[$k]="$(echo "$i" | awk -F: '{print $2}')"
		while [ "$l" -lt "$NB_REPLICA" ]; do
			REPLICA_NAME="$(echo "${REPLICA[$l]}" | awk -F/ '{print $NF}')"
			mkdir -p "${REPLICA_PATH[$k]}""$REPLICA_NAME"
			((l++))
		done
		l=0
		((k++))
	done

	j=0
	while [ "$j" -lt "$NB_REPLICA" ]; do
        SUCCESS="[ ${LGREEN}OK${END} ] "${REPLICA[$j]}" created successfully."
        FAILED="[ ${LRED}KO${END} ] "${REPLICA[$j]}" creation failled."
		REPLICA_NAME="$(echo "${REPLICA[$j]}" | awk -F/ '{print $NF}')"
		gluster volume create "$REPLICA_NAME" replica "$NB_REPLICA_SRC" transport tcp $(for m in "${REPLICA_SRC[@]}"; do echo -n "$m$REPLICA_NAME "; done) force
		gluster volume start "$REPLICA_NAME"

		gluster volume set "$REPLICA_NAME" network.ping-timeout 1
		gluster volume set "$REPLICA_NAME" client.event-threads 3
		gluster volume set "$REPLICA_NAME" server.event-threads 5

		mkdir -p "${REPLICA[$j]}"
		echo "$HOSTNAME:/$REPLICA_NAME ${REPLICA[$j]} glusterfs defaults,_netdev,backupvolfile-server=$HOSTNAME,fetch-attempts=10 0 2" >> /etc/fstab
		mount "${REPLICA[$j]}"
		verify
		((j++))
	done
fi

# Set and mount merged folders :
if [ "$MERGE_FOLDERS" == "Yes" ]; then 
	k=0
	l=0
	for i in "${MERGE_SRC[@]}"; do
		HOSTNAME="$(echo "$i" | awk -F: '{print $1}')"
		MERGE_PATH[$k]="$(echo "$i" | awk -F: '{print $2}')"
		while [ "$l" -lt "$NB_MERGE" ]; do
			MERGE_NAME="$(echo "${MERGE[$l]}" | awk -F/ '{print $NF}')"
			mkdir -p "${MERGE_PATH[$k]}""$MERGE_NAME"
			((l++))
		done
		l=0
		((k++))
	done

	j=0
	while [ "$j" -lt "$NB_MERGE" ]; do
        SUCCESS="[ ${LGREEN}OK${END} ] "${MERGE[$j]}" created successfully."
        FAILED="[ ${LRED}KO${END} ] "${MERGE[$j]}" creation failled."
		MERGE_NAME="$(echo "${MERGE[$j]}" | awk -F/ '{print $NF}')"
		mkdir -p "${MERGE[$j]}"
		LAST_MERGE=${MERGE_SRC[${#MERGE_SRC[@]} + 1]}
        echo "$(for m in "${MERGE_SRC[@]}"; do echo -n "${MERGE_SRC[$m]}$MERGE_NAME"; if [ ! -z ${LAST_MERGE+x} ]; then echo -n ":"; fi; done) ${MERGE[$j]} fuse.mergerfs defaults,allow_other,direct_io,use_ino,category.create=$MERGE_POLICY,moveonenospc=true,minfreespace=$MERGE_MIN_FREE_SPACE,fsname=mergerfsPool 0 0" >> /etc/fstab
		mount "${MERGE[$j]}"
		verify
		((j++))
	done
fi

# Install Oh my zsh & Set aliases
for i in $(ls -d /home/*/ /root/)
do
	USER=$(echo "$i" | awk -F/ '{print $(NF-1)}')
	cd "$i" || return
	if [ "$OH_MY_ZSH" == "Yes" ]; then
		sudo -i -u "$USER" wget -q https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O - | sudo -i -u "$USER" sh > /dev/null 2>&1
		sed -i -e 's/^\ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"bira\"/g' .zshrc
		sed -i -e 's/^\# DISABLE_AUTO_UPDATE=\"true\"/DISABLE_AUTO_UPDATE=\"true\"/g' .zshrc
		sed -i -e "s@\\/home\\/$USER:\\/bin\\/bash@\\/home\\/$USER:\\/bin\\/zsh@g" /etc/passwd
		echo -e "[ ${LGREEN}OK${END} ] Oh my zsh is installed for $USER."
	fi
	cat >> "$(if [ "$OH_MY_ZSH" == "Yes" ]; then echo -n ".zshrc"; else echo -n ".bashrc"; fi)" <<- EOM
alias ls='ls --color'
alias ll='ls -lash'
alias .='cd ..'
alias ..='cd ../..'
alias ...='cd ../../..'
mkcd() { mkdir -p "$@" && cd "$@"; }
EOM
	if [ "$DOCKER_COMPOSE" == "Yes" ]; then 
		cat >> "$(if [ "$OH_MY_ZSH" == "Yes" ]; then echo -n ".zshrc"; else echo -n ".bashrc"; fi)" <<- EOM
alias docps='docker ps --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}" -a | (read -r; printf "%s\\n" "$REPLY"; sort)'
alias dc='docker-compose'
alias dcps='docker-compose ps'
alias dcdown='docker-compose down'
EOM
	fi
	cat >> "$(if [ "$OH_MY_ZSH" == "Yes" ]; then echo -n ".zshrc"; else echo -n ".bashrc"; fi)" <<- EOM
alias dcup="docker-compose up -d"
EOM
done

echo -e " "
echo -e "Total backup duration: $(time_since $SCRIPT_START)."
echo -e "Installation Finished."
exit 0
