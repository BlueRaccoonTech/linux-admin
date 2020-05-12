#!/bin/bash

if [ $# -ge 2 ]; then
        if [ $2 = '--revert' ]; then
                echo "Unblocking $1"
                /usr/sbin/iptables -D INPUT -s $1 -j DROP
        else
                echo "Blocking $1"
                /usr/sbin/iptables -I INPUT 1 -s $1 -j DROP
        fi
else
        echo "Blocking $1"
        /usr/sbin/iptables -I INPUT 1 -s $1 -j DROP
fi

