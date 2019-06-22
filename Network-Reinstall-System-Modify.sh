#!/bin/bash

## License: GPL
## This is the magically modified version of the one-click reload script.
## It can reinstall CentOS, Debian, Ubuntu and other Linux systems (continuously added) over the network in one click.
## It can reinstall Windwos 2003, 7, 2008R2, 2012R2, 2016, 2019 and other Windows systems (continuously added) via the network in one click.
## Support GRUB or GRUB2 for installing a clean minimal system.
## Technical support is provided by the CXT (CXTHHHHH.com). (based on the original version of Vicer)

## Magic Modify version author:
## Default root password: cxthhhhh.com
## Blog: https://cxthhhhh.com
## Written By CXT (CXTHHHHH.com)

## Original version author:
## Blog: https://moeclub.org
## Written By Vicer (MoeClub.org)


echo -e "\n\n\n"
clear
echo -e "\n"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\033[33m Network-Reinstall-System-Modify Tools V2.0.1 2019/01/06 \033[0m"
echo -e "\033[33m [Magic Modify] Reinstall the system (any Windows / Linux) requires only network and one click \033[0m"
echo -e "\033[33m System requirements: Any Linux system with GRUB or GRUB2, recommended CentOS7/Debian9/Ubuntu18.04 \033[0m"
echo -e "\n"
echo -e "\033[33m [Original] One-click Network Reinstall System - Magic Modify version (For Linux/Windows) \033[0m"
echo -e "\033[33m https://cxthhhhh.com/linux/2018/11/27/original-one-click-network-reinstall-system-magic-modify-version-for-linux-windows-en.html \033[0m"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"
sleep 5s


if [ $1 = '-CentOS_7' ]
then
	echo -e "\033[33m You have chosen to install the latest CentOS_7 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/CentOS/CentOS_7.X_NetInstallation.vhd.gz'
fi

if [ $1 = '-CentOS_6' ]
then
	echo -e "\033[33m You have chosen to install the latest CentOS_6 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -c 6.9 -v 64 -a
fi

if [ $1 = '-Debian_9' ]
then
	echo -e "\033[33m You have chosen to install the latest Debian_9 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -d 9 -v 64 -a
fi

if [ $1 = '-Debian_8' ]
then
	echo -e "\033[33m You have chosen to install the latest Debian_8 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -d 8 -v 64 -a
fi

if [ $1 = '-Debian_7' ]
then
	echo -e "\033[33m You have chosen to install the latest Debian_7 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -d 7 -v 64 -a
fi

if [ $1 = '-Ubuntu_18.04' ]
then
	echo -e "\033[33m You have chosen to install the latest Ubuntu_18.04 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -u 18.04 -v 64 -a
fi

if [ $1 = '-Ubuntu_16.04' ]
then
	echo -e "\033[33m You have chosen to install the latest Ubuntu_16.04 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -u 16.04 -v 64 -a
fi

if [ $1 = '-Ubuntu_14.04' ]
then
	echo -e "\033[33m You have chosen to install the latest Ubuntu_14.04 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -u 14.04 -v 64 -a
fi

if [ $1 = '-Windows_Server_2019' ]
then
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2019 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/Windows/Disk_Windows_DD/Disk_Windows_Server_2019_DataCenter_CN.vhd.gz'
fi

if [ $1 = '-Windows_Server_2016' ]
then
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2016 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/Windows/Disk_Windows_DD/Disk_Windows_Server_2016_DataCenter_CN.vhd.gz'
fi

if [ $1 = '-Windows_Server_2012R2' ]
then
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2012R2 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/Windows/Disk_Windows_DD/Disk_Windows_Server_2012R2_DataCenter_CN.vhd.gz'
fi

if [ $1 = '-Windows_Server_2008R2' ]
then
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2008R2 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/Windows/Disk_Windows_DD/Disk_Windows_Server_2008R2_DataCenter_CN.vhd.gz'
fi

if [ $1 = '-Windows_7_Vienna' ]
then
	echo -e "\033[33m You have chosen to install the latest Windows_7_Vienna \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/Windows/Disk_Windows_DD/Disk_Windows_7_Vienna_Ultimate_CN.vhd.gz'
fi

if [ $1 = '-Windows_Server_2003' ]
then
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2003 \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/Windows/Disk_Windows_DD/Disk_Windows_Server_2003_DataCenter_CN.vhd.gz'
fi

if [ $1 = '-CXT_Bare-metal_System_Deployment_Platform' ]
then
	echo -e "\033[33m You have chosen to install the latest CXT_Bare-metal_System_Deployment_Platform \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd 'https://opendisk.cxthhhhh.com/OperatingSystem/CXT-System/CXT_Bare-metal_System_Deployment_Platform.vhd.gz'
fi

if [ $1 = '-DD' ]
then
	echo -e "\033[33m You have chosen to install the DD package provided by you \033[0m"
	echo -e "\n"
	sleep 2s
	wget --no-check-certificate -qO koiok.sh 'https://cxthhhhh.com/tech-tools/Network-Reinstall-System-Modify/CoreShell/Core_Install.sh' && bash koiok.sh -dd $2
fi


echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\033[31m Start Installation \033[0m"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"
exit