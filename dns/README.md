
## Creating RVS / DNS Entry for HIP

### Script

To create everything in one go:
```
sudo ./hip-dns.sh -a /path/to/my/host/identities/file.xml rvs.server.fqdn
```

For just the HIP RR record to add to a DNS:
```
sudo ./hip-dns.sh -d /path/to/my/host/identities/file.xml
```

For just the RVS Server record:
```
./hip-dns.sh -r rvs.server.fqdn
```

### Manual

Using the statically linked libraries directly:
```
sudo ./hi2dns /usr/local/etc/hip/my_host_identities.xml > my_hi2dns
./djbrvs fqdn_of_rvs_server > my_rvs
```

Or by using the scripts:
```
sudo ./hip-dns.sh -d /path/to/my/host/identities/file.xml
./hip-dns.sh -r rvs.server.fqdn
```

We now append my_rvs to the end of my_hi2dns (the two files created in the steps above):
```
echo `cat my_hi2dns``tail -1 my_rvs` > my_hi2dns_rvs
```

If you dont have RVS just do the hi2dns line.

## DNS Change (TinyDNS)

Add the output of the file my_hi2dns_rvs (or my_hi2dns) to your TinyDNS instance file (/etc/tinydns/root/data) and then rebuild for TinyDNS (sudo make.
Just finish the FQDN for the item added (adam-desktop --> adam-desktop.critical.com).

This only adds a HIP record, no A record though. If you are the one establishing over HIP then A record is not needed.

## RVS Server

// TODO

## ZIPS

\*.tar.gz == OLD JIM SETUP WITH WORKING STATIC CONFIGURATION THAT IS MESSY
