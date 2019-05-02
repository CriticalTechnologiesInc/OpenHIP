## Getting Started

Jim has some stuff from 2016 that he created for DNS and HIP. We are going to use that and reverse engineer it.

Plan is to setup a HIP Rendevous Server (RVS) and have everything go through that to setup DNS to make it more static and make it so HIP HIs don't have to be shared with everyone in the network.

http://openhip.sourceforge.net/wiki/index.php/Usage#HIP_DNS_records

## Building / Compiling

cd openhip-..../patches
cp openhip-bind.static.tar.gz .
tar -zxvf openhip-bind.static.tar.gz
cd openhip-bind.static/
make -f Makefile.static

Add -ldl and -llzma to hi2dns line

This got lost so what works in the Makefile.static works....

tto build djbrvs to static:
```
gcc -static dhbrvs.c -o djbvrs
```

## Creating RVS / DNS Entry

Obtain statically linked version of binaries...

```
sudo ./hi2dns /usr/local/etc/hip/my_host_identities.xml > my_hi2dns
./djbrvs fqdn_of_rvs_server > my_rvs
```

We now append my_rvs to the end of my_hi2dns
Note that we must full concat them together

```
echo `cat my_hi2dns``tail -1 my_rvs` > my_hi2dns_rvs
```

If you dont have RVS just do the hi2dns line.

## DNS Change

Add the output of the file my_hi2dns_rvs (or my_hi2dns) to your TinyDNS instance file. (/etc/tinydns/root/data && sudo make)
Just finish the FQDN for the item added (adam-desktop --> adam-desktop.critical.com).

This only adds a HIP record, no A record though. If you are the one establishing over HIP then A record is not needed.

## RVS Server

// TODO