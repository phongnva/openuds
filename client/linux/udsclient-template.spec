%define name fsoft-client
%define version 0.0.0
%define release 1
%define buildroot %{_topdir}/%{name}-%{version}-%{release}-root

BuildRoot: %{buildroot} 
Name: %{name}
Version: %{version}
Release: %{release}
Summary: Client for FSOFT Virtual Desktop
License: BSD3
Group: Applications/Productivity
Requires: (python3-qt6 or python3-qt5) python3-cryptography python3-certifi python3-psutil
Vendor: FSOFT
URL: https://fpt-software.com
Provides: udsclient

%define _rpmdir ../
%define _rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm


%install
curdir=`pwd`
cd ../..
make DESTDIR=$RPM_BUILD_ROOT DISTRO=rh install
cd $curdir

%post
/usr/bin/update-desktop-database
if [ ! -d /media ]; then mkdir /media; echo "/media created for compatibility"; fi

%clean
rm -rf $RPM_BUILD_ROOT
curdir=`pwd`
cd ../..
make DESTDIR=$RPM_BUILD_ROOT DISTRO=rh clean
cd $curdir


%postun
# And, posibly, the .pyc leaved behind on /usr/share/UDSActor
rm -rf /usr/share/UDClient > /dev/null 2>&1
/usr/bin/update-desktop-database

%description
This package provides the required components to allow connection to services offered by UDS Broker.

%files
%defattr(-,root,root)
/usr/lib/UDSClient/*
/usr/share/applications/UDSClient.desktop
