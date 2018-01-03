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
#  4- Install a ssh honeypot on port 22 (requires docker).
#  5- Install and configure fail2ban.
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

###################################################################################
#                                     /!\                                         #
#   /!\  Unless you know exactly what you're doing, do not change anything  /!\   #
#                                     /!\                                         #
###################################################################################

# Check is linux is Debian based:
if [ ! -f /etc/debian_version ]; then
  echo -e "[ ERR ] This script has been writen for Debian-based distros."
  exit 0
fi

WAN=$(route | grep '^default' | grep -o '[^ ]*$')

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
sudo apt update
sudo echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
sudo echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
sudo apt -y install iptables iptables-persistent knockd fail2ban libpam-google-authenticator

###############
#     SSH     #
###############

sudo sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config                                    # Change ssh port
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/g' /etc/ssh/sshd_config      # Desactivate root login 

# Tell sshd which users are alllowed to log in :
{
  sudo echo " "
  sudo echo "# Users allowed to use ssh :"
  sudo echo "AllowUsers "$SSH_USER""
} >> /etc/ssh/sshd_config

# Restart ssh :
sudo /etc/init.d/ssh restart

###############
#  iptables   #
###############

# Base iptables rules :
sudo iptables -F                                                              # Flush existing rules.
sudo iptables -X                                                              # Delete user defined rules.
sudo iptables -P INPUT DROP                                                   # Drop all input connections.
sudo iptables -P OUTPUT ACCEPT                                                  # Drop all output connections.
sudo iptables -P FORWARD DROP                                                 # Drop all forward connections.
sudo iptables -A INPUT -i lo -j ACCEPT                                        # Allow input on loopback.
#sudo iptables -A OUTPUT -o lo -j ACCEPT                                       # Allow input on loopback.
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT   # Don't break established connections.
sudo iptables -A INPUT -p icmp -j ACCEPT                                      # Allow ping request
#sudo iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT          # Don't break established connections.
for i in "${PORT_OPEN[@]}"; do
  sudo iptables -A INPUT -p tcp --dport $i -j ACCEPT                          # Set specified rules.
  #sudo iptables -A OUTPUT -p tcp --sport $i -j ACCEPT                          # Set specified rules.
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
  # sudo iptables -A FORWARD -i docker0 -o $WAN -j ACCEPT -m comment --comment "Docker forwaring"
  # sudo iptables -A FORWARD -i $WAN -o docker0 -j ACCEPT -m comment --comment "Docker forwaring"
# fi

sudo iptables -A INPUT -j DROP                                                # Drop anything else

sudo netfilter-persistent save         # Save rules.
sudo netfilter-persistent reload       # Reload rules.

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

sudo cat knockd.tmp > /etc/knockd.conf && rm knockd.tmp

# Set autostart for knockd :
sudo sed -i 's/START_KNOCKD=0/START_KNOCKD=1/g' /etc/default/knockd

# Start knockd :
sudo /etc/init.d/knockd start

###############
#  honeypot   #
###############

if [ -z $(docker --version | grep "not found") ]; then   
  sudo docker pull txt3rob/docker-ssh-honey
  sudo docker run -d -m 256m --cpus=".5" -p 22:22 --name ssh-honeypot_droberson txt3rob/docker-ssh-honey
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

sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

sudo sed -i "s/bantime  = 600/bantime  = $F2B_BAN_TIME/g" /etc/fail2ban/jail.local
sudo sed -i "s/maxretry = 5/maxretry = $F2B_RETRY/g" /etc/fail2ban/jail.local
sudo sed -i "s/port    = ssh/port    = $SSH_PORT/g" /etc/fail2ban/jail.local

sudo fail2ban-client reload

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
    sudo echo " "
    sudo echo "# Activate One Time Password on login :"
    sudo echo "    auth required pam_google_authenticator.so"
  } >> /etc/pam.d/sshd
  sudo sed -i "s/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g" /etc/ssh/sshd_config

  # Restart ssh :
  sudo /etc/init.d/ssh restart
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
