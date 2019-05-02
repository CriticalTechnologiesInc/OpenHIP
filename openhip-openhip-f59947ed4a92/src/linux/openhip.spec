%define version 0.9
Name: 		openhip
License:	MIT
Group: 		System Environment/Daemons
Summary: 	OpenHIP Host Identity Protocol usermode for Linux
Prefix: 	/usr
Provides: 	openhip
Release: 	1
Requires:	libxml2 openssl
BuildRequires:	make automake autoconf pkgconfig libxml2-devel openssl-devel
Source: 	openhip-%{version}.tar.gz
URL:		http://www.openhip.org
Version:	%{version}
Buildroot:	/tmp/openhiprpm
%description
OpenHIP is a free, open-source implementation of the Host Identity Protocol (HIP). HIP is being developed within the Internet Engineering Task Force (IETF) and the Internet Research Task Force (IRTF) to study and experiment with HIP and related protocols.

HIP is a specific proposal to decouple network identity from network location in the Internet protocol stack. Historically, IP addresses have served both functions. This dual use of IP addresses is becoming problematic, and there have been many research efforts aimed at studying the decoupling of identifier and locator in the network stack. HIP is a specific proposal that uses public/private key pairs as the host identifiers. 

%prep
%setup -q

%build
./bootstrap.sh
%configure
make

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%{_sbindir}/hip
%{_sbindir}/hitgen
%{_sbindir}/hipstatus
%config /etc/hip/known_host_identities.xml
%doc README
%doc AUTHORS
%doc LICENSE

%post

%changelog
* Wed Mar 21 2012 Jeff Ahrenholz <siliconja@sourceforge.net> - 0.9
- updated for 0.9 release, use mock, don't use /usr/local dirs
* Mon May 18 2009 Jeff Ahrenholz <siliconja@sourceforge.net> - 0.6
- updated for 0.6 release, fix install using DESTDIR instead of changing prefix
* Wed Jan 10 2007 Jeff Ahrenholz <siliconja@sourceforge.net> - 0.4
- created spec file for OpenHIP 0.4 release
- uses /usr/local/sbin for binaries
