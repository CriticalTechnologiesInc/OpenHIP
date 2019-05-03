# OpenHIP

OpenHIP CTI Patches &amp; Notes

## CHANGELOG

- 2019-05-02 - v1.0 released -- GitHub project seeded from various sources internally at CTI and v1.0 of CTI OpenHIP Package tagged

## About this Repository

Critical Technologies Inc. (CTI) has long been interested in HIP. This project serves as CTI's playground to experiment with OpenHIP and making it work for CTI while giving back to the community on our findings and other items of interest. What you find here may be useless to you, spark interest in HIP, or bring knowledge and help to you.

What is in this directory is what CTI uses internally to configure boxes with HIP. For anyone who wishes to quickly get up and running with HIP on Ubuntu Server 18.04.2 LTS quickly (without needing to build from source) - this is a good place to start.

### Directory Listing

#### dns 
Contains a version of DNS utilities for OpenHIP using BIND. This package is altered by CTI for exporting HIP RR's to be placed in a TinyDNS configuration. It is also configured to be built statically. This was alterted and built on a Ubuntu 14.04.3 LTS system and the binaries produced are part of the installer package when created. The exact binaries are in `usr-local-sbin`.

#### docs 
Contains various documentation files for this project. Some items may be well kept and clean while others are scratch notes that need to find a home in the current documentation.

#### legacy 
This directory is our first foray into HIP with OpenHIP that started around April 2019. We found that OpenHIP's v2 branch would not compile on Ubuntu Server 18.04 LTS due to deprecated OpenSSL declarations and usage. CTI (specifically Jim Henrickson and Adam Wiethuechter), undetered, brute forced their way through the the numerous build errors attempting to get OpenHIP to build. 

While the efforts presented in the folder still do not function (it seg-faults on the hip binary), this brute force method to update OpenHIP for OpenSSL 1.1.X gave us a view at many of the locations that OpenHIP needs to be fixed. This folder is here as a reference or starting point for someone to get the OpenHIP to support OpenSSL 1.1.X properly.

#### usr-local-sbin 
This contains the core of the CTI OpenHIP package created by running the `package.sh` utility in this project. These are the statically linked binary files for OpenHIP using a base of release-0.9 from [here](https://bitbucket.org/openhip/openhip). The binaries are all built on Ubuntu Server 18.04.2 LTS (apart from the DNS utility binaries) and are all statically linked.

## Creating an Install Package

To create an install package of what is in this project just run `./package.sh`. This will create a zip file of the required directories and files to be moved onto a target host you wish to install OpenHIP onto.

## Installing & Configuration

Please see [INSTALL](INSTALL) for details on how to install and configure what the `package.sh` script creates on a target host.

## Credits & Acknowledgments

None of this would be possible without the hard work and dedication of various other members in the OpenHIP and HIP community in general. CTI hopes to continue to use and help foster use of HIP in the network community at large.

----

[Critical Technologies Inc. (CTI)](https://www.critical.com/)

- **Adam Wiethuechter** - Development and documentation - adam.wiethuechter@critical.com
- **Jim Henrickson** - Development - jim.henrickson@critical.com

Distributed under the BSD-license. See [LICENSE](LICENSE) for more information.