#!/bin/bash
# This script will return the following set of system information:

# -Hostname information:
echo -e "\e[31;43m***** HOSTNAME INFORMATION *****\e[0m"
hostnamectl
echo ""
echo "            Uptime: $(uptime | awk '{print $3" "$4" "$5}' | awk -F"," '{print $1" & "$2}')"
echo "      $(uptime | awk '{ for (i=8; i<=NF; i++) printf $i" " }')"
echo ""


# -Online information :
echo -e "\e[31;43m***** ONLINE INFORMATION *****\e[0m"
for i in $(hostname -I); do
  j=$(echo "$i" | grep -E -v '^(192\.168|10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.)')
  if [ ! -z "$j" ]; then
    WANS+=("$j")
  fi
done
j=1
for ip in ${WANS[@]}; do
  echo "     Public IP "$j": "$ip""
  FQDN=$(dig +noall +answer -x "$ip" | awk '{print $NF}')
  FQDN=${FQDN::-1}
  echo "          FQDN "$j": "$FQDN""
  echo ""
  ((j++))
done

# -System information:
echo -e "\e[31;43m***** SYSTEM INFORMATION *****\e[0m"
MEM_KO=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_GO=$(expr $MEM_KO / 1024 / 1024)
SWAP_KO=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
SWAP_MO=$(expr $SWAP_KO / 1024)
j=0
for i in $(dmidecode -t memory | grep Size | grep -v "No Module" | sort -u | awk '{print $2}'); do
  MEM_SLOTS[$j]=$(dmidecode -t memory | grep $i | wc -l)
  MEM_CAPA[$j]=$(expr $i / 1024)
  ((j++))
done
j=0
for k in "${MEM_SLOTS[@]}"; do
    MEM_DETAIL=$(echo "$k" slots x "${MEM_CAPA[$j]} Gio")
  ((j++))
done

echo "- Processor:"
j=1
for i in $(grep "physical id" /proc/cpuinfo | sort -u | awk '{print $1}'); do
  PHYS_ID=$(grep "physical id" /proc/cpuinfo | sort -u | tail -n +$j)
  echo "        CPU "$j":$(grep -B 5 "$PHYS_ID" /proc/cpuinfo | grep "model name" | sort -u | cut -d: -f2-)"
  echo "   NB cores "$j": $(grep -A 2 "$PHYS_ID" /proc/cpuinfo | grep "core id" | sort -u | wc -l)"
  echo " Nb threads "$j": $(grep -A 1 "$PHYS_ID" /proc/cpuinfo | grep siblings | head -1 | awk '{print $NF}')"
  ((j++))
done
echo ""
echo "- Memory:"
echo "        RAM: "$MEM_GO" Gio in $MEM_DETAIL ( Used: "$(free | grep Mem | awk '{print $3/$2 * 100.0}' | awk '{printf("%.2f\n", $1)}')"% )"
echo "       SWAP: "$SWAP_MO" Mio ( Used: "$(free | grep Swap | awk '{print $3/$2 * 100.0}' | awk '{printf("%.2f\n", $1)}')"% )"
echo ""
echo "- Drives:"

for d in $(lsblk -o NAME,TYPE | grep disk | awk '{print $1}'); do
  CAPACITY=$(fdisk -l /dev/$d | grep "/dev/$d:" | awk '{print $3$4}' | rev | cut -c 4- | rev)
  echo "   /dev/$d:     $CAPACITY"
  lsblk /dev/$d -o NAME,SIZE,MOUNTPOINT | grep -v "$d \|NAME" | sed 's/^/         /'
done
echo ""
echo "- Other mounts :"
df -h --output=source,fstype,pcent,target | grep -v "/var/lib/docker\|tmpfs\|udev\|/dev/sd" | sed 's/^/         /'
echo ""

# -Logged-in users:
echo -e "\e[31;43m***** CURRENTLY LOGGED-IN USERS *****\e[0m"
who
echo ""

# -Top 5 processes as far as memory usage is concerned
echo -e "\e[31;43m***** TOP 5 MEMORY-CONSUMING PROCESSES *****\e[0m"
ps -eo pid,%mem,%cpu,comm --sort=-%mem | head -n 6
echo ""

# -Top 5 processes as far as cpu usage is concerned
echo -e "\e[31;43m***** TOP 5 CPU-CONSUMING PROCESSES *****\e[0m"
ps -eo pid,%mem,%cpu,comm --sort=-%cpu | head -n 6
echo ""

# -Docker information:
echo -e "\e[31;43m***** DOCKER INFORMATION *****\e[0m"
docker --version
docker-compose --version
echo ""
echo -e "\e[1;32mDone.\e[0m"
