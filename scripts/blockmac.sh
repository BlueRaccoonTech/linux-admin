#!/bin/bash

echo "Note: MAC addresses can be easily spoofed."
echo "Please be mindful of this when considering security."

if [ $# -ge 2 ]; then
	if [ $2 = '--revert' ]; then
		echo "Unblocking $1"
		/usr/sbin/iptables -D INPUT -m mac --mac-source $1 -j DROP
	else
		echo "Blocking $1"
		/usr/sbin/iptables -I INPUT 1 -m mac --mac-source $1 -j DROP
	fi
else
	echo "Blocking $1"
	/usr/sbin/iptables -I INPUT 1 -m mac --mac-source $1 -j DROP
fi
