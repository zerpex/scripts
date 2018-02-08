#!/bin/bash
#
# -- securize_server.sh --
#
# INTRODUCTION:
#--------------
#
# This script install and configure a set of tools in order to increase the 
# security level of your server :
#  1- It tweaks ssh :
#      - Change default port
#      - Remove root hability to log in
#      - Restrict allowed users to a specified list
#  2- Configure a basic firewall with iptables.
#  3- Configure port knocking to hide the real ssh port.
#  4- Install and configure portsentry.
#  5- Install a ssh honeypot on port 22 (requires docker).
#  6- Install and configure fail2ban.
#
# HOW TO USE THIS SCRIPT :
#-------------------------
#
# 1- Adapt variables.
# 3- Execute the script.
#
# NOTES :
#--------
#
# To add :
# - ssh double authent

# Set the port you want to use for ssh :
SSH_PORT=42069

# Set users (separated with a space) that will have the right to log in through ssh :
SSH_USER="zer"

# Set ban time in seconds (default to 1h):
F2B_BAN_TIME=600

# Set max retries before ban (default to 3):
F2B_RETRY=3

# Set the ports you need to be open :
PORT_OPEN[0]=80     # HTTP
PORT_OPEN[1]=443    # HTTPS
PORT_OPEN[2]=53     # DNS
PORT_OPEN[3]=913    # OpenVPN
PORT_OPEN[4]=25     # SMTP
PORT_OPEN[5]=587    # SMTP SARTTLS
PORT_OPEN[6]=993    # IMAPS SSL/TLS
PORT_OPEN[7]=4190   # Sieve SARTTLS
PORT_OPEN[8]=22     # SSH : used for honeypotting

# Set knock sequense :
PORT_KNOCK[0]=7000
PORT_KNOCK[1]=8000
PORT_KNOCK[2]=9000
PORT_KNOCK[3]=10000
PORT_KNOCK[4]=11000

# Portsentry ignore IPs:
PORTSENTRY_IGNORE[0]=8.8.8.8
PORTSENTRY_IGNORE[1]=8.8.4.4

# Telegram messaging:
# ( See https://github.com/zerpex/scripts/tree/master/telegram for script and how to. )
TELEGRAM=Yes                                                 # Send messages through telegram ( Yes / No ) ?
TELEGRAM_PATH=/data/scripts/telegram/telegram_notify.sh      # Full path to telegram script to send messages.

###################################################################################
#                                     /!\                                         #
#   /!\  Unless you know exactly what you're doing, do not change anything  /!\   #
#                                     /!\                                         #
###################################################################################

# Check is linux is Debian based:
if [ ! -f /etc/debian_version ]; then
  echo -e "[ ERR ] This script has been writen for Debian-based distros."
  exit 1
fi

# Check if root or sudo:
if [[ $(id -u) -ne 0 ]] ; then 
  echo 'Please run me as root or with sudo'
  exit 1
fi

WAN=$(route | grep '^default' | grep -o '[^ ]*$')
DEBIAN_FRONTEND='noninteractive'

echo -e " "
echo -e "/!\ At this point, this script does NOT check if this tools are installed /!\ "
echo -e "Please ensure that :"
echo -e " - ssh is set with default values."
echo -e " - you don't have iptables specific rules (or you'll have to reset them)."
echo -e " - Docker is installed."
echo -e "Write 'yes' if it's ok :"
read -r OKTOGO
echo -e " "

if [ "$OKTOGO" != "yes" ]; then
  echo -e "See ya !"
  exit 0
fi

# Install needed softwares :
apt update
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt -y install iptables iptables-persistent knockd fail2ban libpam-google-authenticator portsentry

###############
#     SSH     #
###############

sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config                     # Change ssh port
sed -i "s/Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config                      # Change ssh port for other cases
sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config      # Desactivate root login 

# Tell sshd which users are alllowed to log in :
{
  echo " "
  echo "# Users allowed to use ssh :"
  echo "AllowUsers "$SSH_USER""
} >> /etc/ssh/sshd_config

# Restart ssh :
systemctl restart ssh

###############
#  iptables   #
###############

# Base iptables rules :
iptables -F                                                              # Flush existing rules.
iptables -X                                                              # Delete user defined rules.
iptables -P INPUT DROP                                                   # Drop all input connections.
iptables -P OUTPUT ACCEPT                                                  # Drop all output connections.
iptables -P FORWARD DROP                                                 # Drop all forward connections.
iptables -A INPUT -i lo -j ACCEPT                                        # Allow input on loopback.
#iptables -A OUTPUT -o lo -j ACCEPT                                       # Allow input on loopback.
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT   # Don't break established connections.
iptables -A INPUT -p icmp -j ACCEPT                                      # Allow ping request
#iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT          # Don't break established connections.
for i in "${PORT_OPEN[@]}"; do
  iptables -A INPUT -p tcp --dport $i -j ACCEPT                          # Set specified rules.
  #iptables -A OUTPUT -p tcp --sport $i -j ACCEPT                          # Set specified rules.
done

# # Docker specific
# if [ -z $(docker --version | grep "not found") ]; then   
  # # Remove iptables auto-generating capability from docker
  # service docker stop
  # mkdir -p /etc/systemd/system/docker.service.d/
# cat > /etc/systemd/system/docker.service.d/noiptables.conf <<- EOM
# [Service]
# ExecStart=
# ExecStart=/usr/bin/dockerd -H fd:// --dns 8.8.8.8 --dns 8.8.4.4 --iptables=false  
# EOM
  # systemctl daemon-reload
  # service docker start
  # # Add rules for docker to work:
  # iptables -A FORWARD -i docker0 -o $WAN -j ACCEPT -m comment --comment "Docker forwaring"
  # iptables -A FORWARD -i $WAN -o docker0 -j ACCEPT -m comment --comment "Docker forwaring"
# fi

iptables -A INPUT -j DROP                                                # Drop anything else

netfilter-persistent save         # Save rules.
netfilter-persistent reload       # Reload rules.

systemctl stop docker
systemctl start docker

###############
#   knockd    #
###############

KNOCK_SEQ=
for i in "${PORT_KNOCK[@]}"; do
  if [ -z "$KNOCK_SEQ" ]; then
    KNOCK_SEQ=$i
  else
    KNOCK_SEQ=$KNOCK_SEQ","$i
  fi
done

# Set knockd config :
cat > knockd.tmp <<- EOM
[options]
      logfile   = /var/log/knockd.log
      interface = WAN
[SSH]
      sequence      = KNOCK_SEQ
      seq_timeout   = 5
      start_command = /sbin/iptables -I INPUT -s %IP% -p tcp --dport SSH_PORT -j ACCEPT
      tcpflags      = syn
      cmd_timeout   = 10
      stop_command = /sbin/iptables -D INPUT -s %IP% -p tcp --dport SSH_PORT -j ACCEPT
EOM

sed -i "s/WAN/$WAN/g" knockd.tmp
sed -i "s/KNOCK_SEQ/$KNOCK_SEQ/g" knockd.tmp
sed -i "s/SSH_PORT/$SSH_PORT/g" knockd.tmp

cat knockd.tmp > /etc/knockd.conf && rm knockd.tmp

# Set autostart for knockd :
sed -i 's/START_KNOCKD=0/START_KNOCKD=1/g' /etc/default/knockd

# Start knockd :
systemctl start knockd

###############
# Portsentry  #
###############

# Add white-listed IPs to ignore list:
for i in "${PORTSENTRY_IGNORE[@]}"; do
  echo $i >> /etc/portsentry/portsentry.ignore
done

# Change mode to auto (more efficient):
sed -i 's/TCP_MODE="tcp"/TCP_MODE="atcp"/g' /etc/default/portsentry
sed -i 's/UDP_MODE="udp"/UDP_MODE="audp"/g' /etc/default/portsentry

# Enable scanports detection:
sed -i 's/BLOCK_TCP="0"/BLOCK_TCP="1"/g' /etc/portsentry/portsentry.conf
sed -i 's/BLOCK_UDP="0"/BLOCK_UDP="1"/g' /etc/portsentry/portsentry.conf

# Send a message through telegram:
sudo echo "KILL_RUN_CMD=\"$TELEGRAM_PATH/telegram_notify.sh --error --text 'PortSentry blocked IP:\n\$TARGET$ \$PORT$ \$MODE$'\"" >> /etc/portsentry/portsentry.conf

# Redirect portsentry logs to a dedicated log file:
echo -e ":msg,contains,\"portsentry \" /var/log/portsentry.log" >> /etc/rsyslog.d/portsentry.conf
service rsyslog restart

# Restart service:
systemctl restart portsentry

###############
#  honeypot   #
###############

if [ -z $(docker --version | grep "not found") ]; then   
  docker pull txt3rob/docker-ssh-honey
  docker run -d -m 256m --cpus=".5" -p 22:22 --name ssh-honeypot_droberson txt3rob/docker-ssh-honey
else
  echo " "
  echo -e "/!\ Can't use honeypot : Docker is NOT installed :"
  echo " "
fi

# Crontab command :
#docker stop ssh-honeypot_droberson && docker rm ssh-honeypot_droberson && docker run -d -m 512m --cpus=".5" -p 22:22 --name ssh-honeypot_droberson txt3rob/docker-ssh-honey

###############
#  Fail2ban   #
###############

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

sed -i "s/bantime  = 600/bantime  = $F2B_BAN_TIME/g" /etc/fail2ban/jail.local
sed -i "s/maxretry = 5/maxretry = $F2B_RETRY/g" /etc/fail2ban/jail.local
sed -i "s/port    = ssh/port    = $SSH_PORT/g" /etc/fail2ban/jail.local

fail2ban-client reload

###############
#  Finishing  #
###############

echo -e " "
echo -e "Everything is installed."
echo -e " "
echo -e "Please, open a second terminal with the user that will use OTP and execute :"
echo -e "google-authenticator"
echo -e "It will generate a QR Code that you need to flash using your smartphone and Google authenticator."
echo -e "Quick answers : y/y/n/y (better read questions before answering :p )"
echo -e " "
echo -e "Once done, write 'yes' here :"
echo -e "/!\ Ensure that you really did it and save the codes somewhere."
read -r GO
if [ "$GO" == "yes" ]; then
  # Activate OTP on login :
  {
    echo " "
    echo "# Activate One Time Password on login :"
    echo "    auth required pam_google_authenticator.so"
  } >> /etc/pam.d/sshd
  sed -i "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g" /etc/ssh/sshd_config

  # Restart ssh :
  /etc/init.d/ssh restart
  echo " "
  echo -e "OTP was activated."
else
  echo " "
  echo -e "OTP was not activated."
fi

echo " "
echo -e "IMPORTANT:"
echo -e "----------"
echo " "
echo -e "Before closing this session, open a second one and try to connect to this server."
echo -e "If the connection is successfull, then you can close safelly."
