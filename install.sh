#!/bin/bash

sudo cp usr-local-sbin/* /usr/local/sbin/
cd /usr/local/sbin/

if [[ $1 -eq "-s" ]]
then
	sudo ./hitgen
	sudo ./hitgen -conf
	sudo ./hitgen -publish
	sudo chmod 755 /usr/local/etc/hip
	sudo mv hip.conf *.pub.xml /usr/local/etc/hip/
fi