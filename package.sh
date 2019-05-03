#!/bin/bash

# Critical Technologies Inc. (CTI)
# Adam Wiethuechter <adam.wiethuechter@critical.com>
# 2019-05-02

# check for dos2unix
if ! dpkg -s dos2unix >/dev/null 2>&1; then
	sudo apt install dos2unix
fi

# grab the commit id
commit=$(git log --oneline -1)

# create the package manually
mkdir cti-openhip_$(date +%Y%m%d)_${commit:0:7}
echo $(date +%Y%m%d)_${commit:0:7} > cti-openhip_$(date +%Y%m%d)_${commit:0:7}/VERSION
cp -r usr-local-sbin/ docs/ install.sh INSTALL cti-openhip_$(date +%Y%m%d)_${commit:0:7}

# run dos2unix to clean up anything nasty
find cti-openhip_$(date +%Y%m%d)_${commit:0:7} -type f -print0 | xargs -0 dos2unix

# zip up the package with name and date and remove the folder to leave zip
zip -r cti-openhip_$(date +%Y%m%d)_${commit:0:7}.zip cti-openhip_$(date +%Y%m%d)_${commit:0:7}
rm -rf cti-openhip_$(date +%Y%m%d)_${commit:0:7}/