#!/bin/sh

# local or remote ?
BACKUP_TARGET=local

# If remote, set 
BACKUP_REMOTE_IP=
BACKUP_REMOTE_USER=
BACKUP_REMOTE_PASS=

# Target directory (needed for local AND remote)
BACKUP_DIR=/data/sysbackup

SYS_FILE[0]=/etc/init.d/iptables
SYS_FILE[1]=/etc/fstab
SYS_FILE[2]=/etc/hostname
SYS_FILE[3]=/root/crontab

HOME[0]=/root
HOME[1]=/home

DATA[0]=

crontab -l > /root/crontab

CUR_DATE=$(date +%Y%m%d)
HOSTNAME=$(hostname)

SYS_DIR=$BACKUP_DIR/$HOSTNAME-$CUR_DATE/system
HOME_DIR=$BACKUP_DIR/$HOSTNAME-$CUR_DATE/home
DATA_DIR=$BACKUP_DIR/$HOSTNAME-$CUR_DATE/data

# Create local or remote directories
if [ "$BACKUP_TARGET" == "local" ]; then
	mkdir -p $SYS_DIR $HOME_DIR $DATA_DIR
elif [ "$BACKUP_TARGET" == "remote" ]; then
	sshpass -p '$BACKUP_REMOTE_PASS' ssh $BACKUP_REMOTE_USER@$BACKUP_REMOTE_IP "mkdir -p $SYS_DIR $HOME_DIR $DATA_DIR"
fi

# Copy files and folders
for i in "${FILE[@]} ${HOME[@]} ${DATA[@]}"; do
	if [ "$BACKUP_TARGET" == "local" ]; then
		cp -r $i $SYS_DIR/
	elif [ "$BACKUP_TARGET" == "remote" ]; then
		sshpass -p '$BACKUP_REMOTE_PASS' scp -r $i $BACKUP_REMOTE_USER@$BACKUP_REMOTE_IP:/$SYS_DIR
	fi
done
