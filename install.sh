#!/bin/bash

# Critical Technologies Inc. (CTI)
# Adam Wiethuechter <adam.wiethuechter@critical.com>
# 2019-07-13

display_usage()
{
	echo
	echo "Usage:"
	echo "	sudo $0 ./install -n <server_fqdn>"
	echo "	sudo $0 ./install -a <server_fqdn>"
	echo "	sudo $0 ./install -d"
	echo "	sudo $0 ./install -c"
	echo "	$0 -h"
	echo
	echo "Options:"
	echo " -h, --help   : Display usage instructions"
	echo " -n, --new    : Create new HI and setup HIP"
	echo " -a, --append : Create and Append new HI to existing HIP install"
	echo " -d, --dns    : Create 'myhi2dns' file for DNS RR entries"
	echo " -c, --conf   : Create new conf file for HIP"
	echo
}

hit_gen()
{
	if [[ $2 -eq "-a" ]]
	then
		echo "Running 'hitgen'; appending new HI..."
		sudo ./hitgen -name $1 -append -noinput
	else
		echo "Running 'hitgen'; creating new HI..."
		sudo ./hitgen -name $1 -noinput
	fi
	echo "Running 'hitgen'; publishing HI file..."
	sudo ./hitgen -publish
	echo "Checking to see if public HI file already exists..."
	if [[ -f /usr/local/etc/hip/*.pub.xml ]]
	then
		echo "Public HI file already exists, saving with current date..."
		sudo mv /usr/local/etc/hip/*.pub.xml /usr/local/etc/hip/*.pub.xml.$(date +%Y%m%d)
	fi
	echo "Moving new public HI file into place..."
	sudo mv *.pub.xml /usr/local/etc/hip/
}

hit_conf()
{
	echo "Running 'hitgen'; creating conf file..."
	sudo ./hitgen -conf
	echo "Checking to see if conf file already exists..."
	if [[ -f /usr/local/etc/hip/hip.conf ]]
	then
		echo "Conf file already exists, saving..."
		sudo mv /usr/local/etc/hip/hip.conf /usr/local/etc/hip/hip.$(date +%Y%m%d)
	fi
	echo "Moving new conf file into place..."
	sudo mv hip.conf /usr/local/etc/hip/
}

hit_dns()
{
	echo "Running 'hipdns'; creating 'myhi2dns' file..."
	sudo hipdns -d /usr/local/etc/hip/my_host_identites.xml
	echo "Moving 'myhi2dns' file into safe location..."
	sudo mv myhi2dns /usr/local/etc/hip/
}

echo
echo "============================================"
echo "Starting CTI OpenHIP installer/helper script"
echo "============================================"
echo

start=$SECONDS
if [[ ! -f /usr/local/sbin/hitgen ]]
then
	echo "HIP utilities not found; copying HIP utility files into place..."
	sudo cp usr-local-sbin/* /usr/local/sbin/
fi

echo "Moving into /usr/local/sbin to use HIP utilities..."
cd /usr/local/sbin/

case $1 in 
	-n|--new)
		echo
		echo "Configuring new HIP installation..."
		echo "==================================="
		echo

		hit_gen $2
		sudo chmod 755 /usr/local/etc/hip
		hit_conf
		hit_dns
		;;
	-a|--append)
		echo
		echo "Appending a new HI in existing HIP installation..."
		echo "=================================================="
		echo

		hit_gen $2 -a
		hit_dns
		;;
	-c|--conf)
		echo
		echo "Generating new HIP configuration file..."
		echo "========================================"
		echo

		hit_conf
		;;
	-d|--dns)
		echo
		echo "Generating HIP RR entries file..."
		echo "================================="
		echo

		hit_dns
		;;
	*)
		display_usage
		;;
esac

echo "Installion/helper script complete, shutting down..."
end=$SECONDS
echo "Finished script $0 on $(date)"
echo "Duration: $((end-start)) seconds."