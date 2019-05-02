#!/bin/bash

# Critical Technologies Inc.
# Adam Wiethuechter <adam.wiethuechter@critical.com>
# April 20, 2019
#
# This script will setup to capture HIP traffic on
# its tunnels (hip0) and well as the physical interface
# (in this case enp3s0).
#
# To use this script place it into the directory you
# wish to save the ouput files to and run:
#
# ./hip-dump.sh <option>
# ping <lsi>
# ./hip-dump.sh
#
# Options: 
# '-p' : flag for ping or no ping
# '-np' : to stop this job

PWD=$(pwd)
echo $PWD

if [[ $1 == "-np" ]]
then
	echo "Starting up tcpdump and hip to recieve pings..."
	sudo tcpdump -i enp3s0 -s 0 -w ${HOSTNAME}-enp.dump &
	sudo /usr/local/sbin/hip -v < /dev/null >& ${PWD}/${HOSTNAME}-hip.log &
	sleep 5
	sudo tcpdump -i hip0 -s 0 -w ${HOSTNAME}-hip.dump &
elif [[ $1 == "-p" ]] 
then
	echo "Starting up tcpdump and hip to send pings..."
	sudo tcpdump -i enp3s0 -s 0 -w ${HOSTNAME}-enp-ping.dump &
	sudo /usr/local/sbin/hip -v < /dev/null >& ${PWD}/${HOSTNAME}-hip-ping.log &
	sleep 5
	sudo tcpdump -i hip0 -s 0 -w ${HOSTNAME}-hip-ping.dump &
else
	echo "Killing all related processes..."
	/usr/local/sbin/stopHIP	
	/usr/local/sbin/stopHIP	
	sudo killall -9 tcpdump
fi
