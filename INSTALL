## Installing OpenHIP Binaries & Utilities

Move the CTI supplied OpenHIP package to your host system, unzip it and run the installer.
```
unzip cti-openhip-v1.zip
cd cti-openhip-v1/
sudo ./install.sh
```

To see how this package was created see [this document](docs/static-building.html) for details.

## Setting Up & Configuring

### System Level Configuration

On Ubuntu 18.04 LTS there are a few things that need to be done prior to starting the HIP daemon.

First we need to disable Ubuntu built in DNS stub-resolver as it will get in the way of starting HIPs own DNS resolver. This is managed by the systemd-resolver process and can be soft disabled with a configuration change. Open up the configuration file and uncomment the "DNSStubListener=yes" entry changing the "yes" to "no". Restart the service for the change to take effect.
```
sudo vim /etc/systemd/resolver.conf
sudo service systemd-resolver restart
```

Next we need to break the sym-link between '/etc/resolv.conf' and '/run/systemd/stub-resolv.conf'. The best way to do this is by copying the contents into a new file and deleting the old one (which has the link):
```
sudo cat /etc/resolv.conf > resolv.tmp
sudo rm /etc/resolv.conf
sudo cat resolv.tmp > /etc/resolv.conf
sudo rm resolv.tmp
```

In the new '/etc/resolv.conf' file you will also need to change the "nameserver" line to be a valid externally accessible DNS. Also you will want to add a rule to your local firewall:
```
sudo iptables -I OUTPUT -o enp3s0 -d 1.0.0.0/8 -j DROP
```

This is to stop any rogue HIP traffic from going out to the world (and keep it confined in the tunnel). We found this can happen if HIP breaks and you are attempting to ping.

### HIP Level Configuration

#### General Configuration

For HIP there are a few settings we normally set to get HIP up and running in '/usr/local/etc/hip/hip.conf':

- Change disable_dns_threads to "no"
- Change save_known_identities to "yes"
- Add dns_server tags with the desired DNS server (IP address) that will respond to HIP based queries

#### Host to Host (No HIP Enabled DNS)

If you have other '.pub.xml' files from other HIP hosts move them into '/usr/local/etc/hip/'. We now will create a known hosts file using a different host identity file other than yours:
```
cd /usr/local/etc/hip/
sudo cp <other-hostname>_host_identities.pub.xml known_host_identities.xml
```

From every '.pub.xml' that isn't yours add in the host information to your 'known_host_identities.xml' file. If you do not have HIP supported DNS then you must add the following to each entry in the file located directly below the LSI field:
```
<addr>ACTUAL_IP_ADDRESS_OF_HOST</addr>
```

#### HIP with DNS Support

Please see the section titled "Using HIP DNS Utilities" below for details on how to create your DNS entries.

For the current version of this package HIP only works with DNS and not including the RVS extension to the RR. To avoid issues run [the following section](#hip-rr-entry) only and place the output (in the file '/usr/local/sbin/my_hi2dns') into your TinyDNS instance file (/etc/tinydns/root/data) and then rebuild for TinyDNS (sudo make). Reboot the DNS server for changes to take effect. 

If you wish to play with the RVS side of things [run this section](#hip-rr-rvs-entry) and instead use '/usr/local/sbin/my_hi2dns_rvs' file. Note that all hosts except the RVS server itself must do this. The RVS server itself will use the method above instead.

If you run HIP using the '-a' flag then no known host file is needed and HIP will dyanamically learn of other hosts using DNS.

#### HIP with RVS Support 

NOTE: If you run an HIP RVS all clients must add the following line to their 'known_host_identities.xml':
```
<RVS>IP_ADDR_OF_RVS_SERVER</RVS>
```

At this current time the included binaries do not work with RVS (as far as we can tell). This may have to do with statically linking the HIP binary together on an older system and moving it to a newer one.

Note that RVS does seem to function and host may register with it. However if a host attempts communication via the RVS to another HIP enabled host the HIP client will crash.

## Using OpenHIP

If 'save_known_identities' is enabled in conf then when you shutdown HIP cleanly it will save the name, HIT, LSI and IP address of the hosts it talked to.

Once started trying pinging another HIP enabled host using their FQDN with '.hip' appended to it (if DNS enabled to talk HIP):
```
ping *.hip
```

If DNS is not being used just ping using the LSI of a HIP enabled host. Be sure that there is an entry for this host in 'known_host_identities.xml'.

### User Mode

To start OpenHIP usermode utility in the foreground with verbose output run the following:
```
cd /usr/local/sbin/
sudo ./hip -v -a
```

To kill HIP hit 'Ctrl+C' and it will shut itself down. If HIP goes rouge (and 'Ctrl+C' does not respond) resort to killing the process manually or using the included script `stopHIP`.

### Kernel Mode
To run HIP in the background with a log file do the following:
```
sudo /usr/local/sbin/hip -d -v -a
```

To kill HIP you can use the included script (below) or manually killing it:
```
stopHIP
```

### Rendevous Server Mode

To run HIP as a Redevous Server (RVS):
```
/usr/local/sbin/hip -v -rvs
```

A client registers with the RVS server by initating a HIP exchange with them. This can be done simply with a "ping" command to the RVS server you wish to connect with.

## Using HIP DNS Utilities

The CTI HIP DNS utilites will create a HIP RR + RVS entry for TinyDNS.

### HIP RR + RVS Entry
```
sudo ./hip-dns.sh -a /path/to/my/host/identities/file.xml rvs.server.fqdn
```

Do this if you have an RVS Server running and you with to use DNS.

### HIP RR Entry
```
sudo ./hip-dns.sh -d /path/to/my/host/identities/file.xml
```

Do this if you wish to use DNS and don't have an RVS Server. This method is preferred as adding in RVS produces undesirable behavior at this time.

### RVS Entry
```
./hip-dns.sh -r rvs.server.fqdn
```