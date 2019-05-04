#!/bin/bash

# Critical Technologies Inc. (CTI)
# Adam Wiethuechter <adam.wiethuechter@critical.com>
# 2019-05-02

sudo cp usr-local-sbin/* /usr/local/sbin/
cd /usr/local/sbin/

if [[ $1 == "-s" ]]
then
	sudo ./hitgen
	sudo ./hitgen -conf
	sudo ./hitgen -publish
	sudo chmod 755 /usr/local/etc/hip
	sudo mv hip.conf *.pub.xml /usr/local/etc/hip/
fi