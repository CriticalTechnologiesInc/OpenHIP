## Creating OpenHIP Statically Linked Binaries

This document is an amendmum to the instructions [here](http://openhip.sourceforge.net/wiki/index.php/Installation) in attempts to get OpenHIP built statically (on Ubuntu 14.04.3 LTS) or with an older version of OpenSSL (on Ubuntu 18.04 LTS).

### Prequisites

To build OpenHIP the CTI way you must have the following:

- Ubuntu 14.04.3 LTS / Ubuntu 18.04.2 LTS
- OpenSSL 1.0.1f / OpenSSL 1.0.1r
- A zip of 'master' branch of OpenHIP from [here](https://bitbucket.org/openhip/openhip). We used commit f59947e (also known as the 'release-0.9' tag) as our base.

These instructions are taken from notes and may be incomplete at this time.

## Building OpenHIP Statically

### Ubuntu 18.04.2 LTS

Build and install [OpenSSL v1.0.1r](https://github.com/openssl/openssl/archive/OpenSSL_1_0_1r.tar.gz):
```
./config
make
sudo make install
```

Build and install [libxml2 v2.9.9](http://xmlsoft.org/sources/libxml2-2.9.0.tar.gz):
```
./configure
vim Makefile
```

On line 473: Change CFLAGS from "-g -02" to "-std=gnu99"

```
make
sudo make install
```

Now begin your OpenHIP install:
```
unzip release-0.9.zip
cd openhip-openhip-f59947ed4a92/
export CFLAGS="-std=c99"
./bootstrap.sh
```

Before the next step edit the 'src/Makefile.am' to comment out the line for the "color-tests" as this breaks the build:
```
vim src/Makefile.am
```

Move onto the next step:
```
./configure --prefix=/usr/local
```

If it complains that it doesnt have openssl-devel, install this to fix:
```
sudo apt install libssl-dev
```

We must edit the 'src/Makefile' now to statically link libraries:
```
cp src/Makefile src/Makefile.orig
vim src/Makefile
vim src/util/Makefile
```

src/Makefile

- On line 200, add to the DEFAULT_INCLUDES variable "-I/usr/local/ssl/include -I/usr/local/include"
- On line 501, add to the CFLAG variable "-static" and "-std=c99" and remove "-Werror"
- On line 521, add to the LDFLAGS variable "-static -L/usr/local/ssl/lib -L/usr/local/lib"
- On line 523, set the LIBS variable "-lpthread -lcrypto -lcrypto  -lm -llzma -lxml2 -ldl"
- On line 614, set the INCLUDES variable to "-I./include -I/usr/include/libxml2"
- On line 615, set the LDADD variable to "-lxml2 -lz -ldl" (remove -L...)

src/util/Makefile

- On line 129, add to the CFLAGS variable "-static -I/usr/local/ssl/include"

From here continue on at [Source Code Changes](#source-code-changes).

### Ubuntu 14.04.3 LTS

Begin your OpenHIP install:
```
unzip release-0.9.zip
cd openhip-openhip-f59947ed4a92/
export CFLAGS="-std=c99"
./bootstrap.sh
```

Before the next step edit the 'src/Makefile.am' to comment out the line for the "color-tests" as this breaks the build:
```
vim src/Makefile.am
```

Move onto the next step:
```
./configure --prefix=/usr/local
```

We must edit the 'src/Makefile' now to statically link libraries:
```
cp src/Makefile src/Makefile.orig
vim src/Makefile
```

We need to change a number of things to statically build the binaries. Note that the steps below are from trail and error - you may need to add or rearrange flags on your system to fix dependency resolutions. If this not your intentions drop down into the next section "Using Older/Manual Installed OpenSSL".

Make the following changes to 'src/Makefile':

- On line 501, add to the CFLAG variable "-static" and remove "-Werror". 
- On line 521 also add the "-static" to LDFLAGS. 
- At the end of line 523 (LIBS) add "-ldl". 
- From a Ubuntu 18.04 LTS system copy the file '/usr/lib/x86_64-linux-gnu/libresolv.a' to the local 'src/' directory in your HIP build folders. On line ??? (hip_LINK) add to the end of the line "libresolv.a".

### Source Code Changes

We also need to make a change in the source code. In 'src/usermode/hip_dns.c' change:
```
// dnsh->flags = htons(DNS_FLAG_MASK_STDQUERY);
dnsh->flags = htons(0x0100);
```

This is to enable DNS queries to be properly formatted otherwise they are dropped by the DNS server (for unknown reasons). You could also change the declaration of "DNS_FLAG_MASK_STDQUERY" in 'src/include/hip_dns.h' instead.

### Finishing the Build

Packages the `make` will most likely need:
```
sudo apt install lzma lzma-dev liblzma-dev
```

We can now build HIP:
```
make
```

This should complete and produce some binaries in 'src/'. Check their properties by running:
```
ldd hip
ldd hipstatus
ldd hitgen
```

These should output with no dynamic links, confirming the build was successful. These are now ready for use. The next step is optional.

To continue to build on this host (installing everything in '/usr/local/sbin/') run the following:
```
sudo make install
```

OpenHIP is now ready to be configured and run.

## Building OpenHIP DNS Utilities Statically
```
cd openhip-openhip-f59947ed4a92/patches
cp openhip-bind.static.tar.gz .
tar -zxvf openhip-bind.static.tar.gz
cd openhip-bind.static/
make -f Makefile.static
```

NOTE: The 'openhip-bind.static' package provided by CTI contains changes to the 'hi2dns' utility as well as the Makefile.static to properly build.

To build the DJB-RVS utility statically:
```
gcc -static dhbrvs.c -o djbvrs
```

## Create the CTI OpenHIP package

Create the script titled 'stopHIP' which has the following contents:
```
#!/bin/bash

# get HIP pids
psOut=$(ps ax | grep hip)

# break the output into array
words=()
for word in $psOut; do
	# echo $word
	words+=( $word )
done

# grab the PID
hipPID=${words[0]}

# kill HIP
sudo kill -9 $hipPID
sudo rm /var/run/hip.pid
```

Also create an 'install.sh' script with the following contents:
```
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
```

Also create the 'hipdns' utility script:
```
#!/bin/bash

print_message() 
{
	echo
	echo "Welcome to CTI HIP to DNS Creator!"
	echo
}

display_usage()
{
	echo
	echo "Usage:"
	echo "	sudo $0 -a <path_to_my_host_id_file> <fqdn_of_rvs_server>"
	echo "	sudo $0 -d <path_to_my_host_id_file>"
	echo "	$0 -r <fqdn_of_rvs_server>"
	echo
	echo "Options:"
	echo "	-h, --help           Display usage instructions"
	echo "	-a, --all            Create HIP RR + RVS Entry for DJBDNS"
	echo "	-d, --hip-to-dns     Create HIP RR Entry for DJBDNS"
	echo "	-r, --rvs-djbdns     Create RVS Entry for DJBDNS"
	echo "	-h, --help           Display usage instructions"
	echo
}

hip_to_dns()
{
	sudo ./hi2dns --djb $1 > my_hi2dns
}

djbdns_rvs()
{
	./djbrvs $1 > my_rvs
}

raise_error() 
{
	local error_message="$@"
	echo "${error_message}" 1>&2;
}

case $1 in
	-a|--all)
		echo "Creating an HIP RR record and RVS entry for DJBDNS..."
		hip_to_dns $2
		djbdns_rvs $3
		echo `cat my_hi2dns``tail -1 my_rvs` > my_hi2dns_rvs
		;;
	-d|--hip-to-dns)
		echo "Creating an HIP RR record for DJBDNS..."
		hip_to_dns $2
		;;
	-r|--rvs-djbdns)
		echo "Creating an RVS entry for DJBDNS..."
		djbdns_rvs $2
		;;
	-h|--help)
		display_usage
		;;
	-p|--print)
		print_message
		;;
	*)
		raise_error "Unknown argument: $1"
		display_usage
		;;
esac

exit 0
```

Place the binaries of the previous sections (plus the 'stopHIP' and 'hipdns' scripts) into folder called 'usr-local-sbin/' along with 'install.sh' into a folder titled "cti-openhip-v1" and zip up the folder using:
```
zip -r cti-openhip-v1.zip cti-openhip-v1/
```

We now have an install package for other hosts to use these binaries nd utilities.

## Experimental Stuff & Notes

CFLAGS="-static -I/usr/local/ssl/include" LDFLAGS="-ldl -L/usr/lib -L/usr/local/ssl/lib" ./configure --prefix=/usr/local