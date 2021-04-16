#!/bin/bash

## License: GPL
## This is the magically modified version of the one-click reload script.
## It can reinstall CentOS, Debian, Ubuntu and other Linux systems (continuously added) over the network in one click.
## It can reinstall Windwos 2003, 7, 2008R2, 2012R2, 2016, 2019 and other Windows systems (continuously added) via the network in one click.
## Support GRUB or GRUB2 for installing a clean minimal system.
## Technical support is provided by the CXT (CXTHHHHH.com). (based on the original version of Vicer)

## Magic Modify version author:
## Default root password: cxthhhhh.com
## WebSite: https://www.cxthhhhh.com
## Written By CXT (CXTHHHHH.com)

## Original version author:
## Blog: https://moeclub.org
## Written By Vicer (MoeClub.org)


echo -e "\n\n\n"
clear
echo -e "\n"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\033[33m 一键网络重装系统 - 魔改版 版本：V4.0.10 更新：2021年04月16日 \033[0m"
echo -e "\033[33m Network-Reinstall-System-Modify Tools V4.0.10 2021/04/16 \033[0m"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\033[33m 一键网络重装系统 - 魔改版（适用于Linux / Windows） \033[0m"
echo -e "\033[33m 系统需求: 任何带有GRUB或GRUB2的Linux操作系统即可运行, 当前推荐安装的系统为： CentOS8/Debian10/Ubuntu20 \033[0m"
echo -e "\n"
echo -e "\033[33m [Magic Modify] Reinstall the system (any Windows / Linux) requires only network and one click \033[0m"
echo -e "\033[33m System requirements: Any Linux system with GRUB or GRUB2, recommended CentOS8/Debian10/Ubuntu20 \033[0m"
echo -e "\n"
echo -e "\033[33m 官方更新地址（Official update address）：CXT - Enjoy Life | 生活、技术、交友、分享 \033[0m"
echo -e "\033[33m https://www.cxthhhhh.com/Network-Reinstall-System-Modify \033[0m"
echo "---------------------------------------------------------------------------------------------------------------------"
echo " 默认密码: cxthhhhh.com"
echo " Default password: cxthhhhh.com"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"
sleep 6s

echo "---------------------------------------------------------------------------------------------------------------------"
echo " 对当前系统环境进行处理. . ."
echo " Pre-environment preparation. . ."
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"
sleep 2s

if [ -f "/usr/bin/apt-get" ];then
	isDebian=`cat /etc/issue|grep Debian`
	if [ "$isDebian" != "" ];then
		echo '当前系统 是 Debian'
		echo 'Current system is Debian'
		apt-get install -y xz-utils openssl gawk file wget curl
		apt install -y xz-utils openssl gawk file wget curl
		sleep 3s
	else
		echo '当前系统 是 Ubuntu'
		echo 'Current system is Ubuntu'
		apt-get install -y xz-utils openssl gawk file wget curl
		apt install -y xz-utils openssl gawk file wget curl
		sleep 3s
	fi
else
    echo '当前系统 是 CentOS'
    echo 'Current system is CentOS'
    yum install -y xz openssl gawk file wget curl
    sleep 3s
fi

echo "---------------------------------------------------------------------------------------------------------------------"
echo " 对当前系统环境进行处理. . .  【OK】"
echo " Pre-environment preparation. . .  【OK】"
echo -e "\n"
echo " 启动系统安装. . . "
echo " Start system installation. . . "
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"
sleep 2s


echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\033[35m 启动 安装 \033[0m"
echo -e "\033[32m Start Installation \033[0m"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"


if [ $1 = '-UI_Options' ]
then
	echo -e "\033[33m 你选择启动到 【图形化安装界面】 正在进入图形化安装选择器. . . \033[0m"
	echo -e "\033[33m You have chosen to Start the Graphical Interface Options, Wait a moment. . . \033[0m"
	echo -e "\n"
	sleep 1s
	wget --no-check-certificate -qO UI_Options.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/UI_Options.sh' && bash UI_Options.sh
fi

if [ $1 = '-CXT_Bare-metal_System_Deployment_Platform' ]
then
	echo -e "\033[33m 你选择安装 最新的 【CXT裸机系统部署平台】，支持玩家VNC自定义安装。（建议极客使用，小白勿扰） \033[0m"
	echo -e "\033[33m You have chosen to install the latest CXT_Bare-metal_System_Deployment_Platform \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Bare-metal_System_Deployment_Platform/CXT_Bare-metal_System_Deployment_Platform_v3.6.vhd.gz'
fi

if [ $1 = '-OpenWRT' ]
then
	echo -e "\033[33m 你选择安装 最新的 【CXT-OpenWRT】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest OpenWRT \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/OpenWRT-Virtualization-Servers/Stable/openwrt-x86-64-generic-squashfs-combined.img.gz'
fi

if [ $1 = '-OpenWRT_UEFI' ]
then
	echo -e "\033[33m 你选择安装 最新的 【CXT-OpenWRT】 支持UEFI启动模式 \033[0m"
	echo -e "\033[33m You have chosen to install the latest OpenWRT_UEFI \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/OpenWRT-Virtualization-Servers/Stable/openwrt-x86-64-generic-squashfs-combined-efi.img.gz'
fi

if [ $1 = '-CentOS_8' ]
then
	echo -e "\033[33m 你选择安装 最新的 【CentOS 8】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest CentOS_8 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/CentOS/CentOS_8.X_NetInstallation_Stable_v3.6.vhd.gz'
fi

if [ $1 = '-CentOS_7' ]
then
	echo -e "\033[33m 你选择安装 最新的 【CentOS 7】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest CentOS_7 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/CentOS/CentOS_7.X_NetInstallation_Final_v9.2.vhd.gz'
fi

if [ $1 = '-Debian_10' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Debian 10】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Debian_10 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -d 10 -v 64 -a
fi

if [ $1 = '-Debian_9' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Debian 9】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Debian_9 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -d 9 -v 64 -a
fi

if [ $1 = '-Ubuntu_20.04' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Ubuntu 20.04】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Ubuntu_20.04 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -u 20.04 -v 64 -a
fi

if [ $1 = '-Ubuntu_18.04' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Ubuntu 18.04】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Ubuntu_18.04 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -u 18.04 -v 64 -a
fi

if [ $1 = '-Windows_Server_2019' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows Server 2019】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2019 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2019_DataCenter_CN_v5.1.vhd.gz'
fi

if [ $1 = '-Windows_Server_2019_UEFI' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows Server 2019】 支持UEFI启动模式 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2019_UEFI \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2019_DataCenter_CN_v5.1_UEFI.vhd.gz'
fi

if [ $1 = '-Windows_Server_2016' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows Server 2016】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2016 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2016_DataCenter_CN_v4.12.vhd.gz'
fi

if [ $1 = '-Windows_Server_2012R2' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows Server 2012 R2】 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2012R2 \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2012R2_DataCenter_CN_v4.29.vhd.gz'
fi

if [ $1 = '-Windows_Server_2012R2_UEFI' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows Server 2012 R2】 支持UEFI启动模式 \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2012R2_UEFI \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2012R2_DataCenter_CN_v4.29_UEFI.vhd.gz'
fi

if [ $1 = '-DD' ]
then
	echo -e "\033[33m 你选择安装 【由你指定的自定义镜像】 更多支持信息，你需要向镜像制作者寻求。 \033[0m"
	echo -e "\033[33m You have chosen to install the DD package provided by you \033[0m"
	echo -e "\n"
	sleep 5s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd $2
fi





if [ $1 = '-CentOS_6' ]
then
	echo -e "\033[33m 你选择安装 最新的 【CentOS 6】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest CentOS_6 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -c 6.10 -v 64 -a
fi

if [ $1 = '-Debian_8' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Debian 8】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Debian_8 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -d 8 -v 64 -a
fi

if [ $1 = '-Debian_7' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Debian 7】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Debian_7 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -d 7 -v 64 -a
fi

if [ $1 = '-Ubuntu_16.04' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Ubuntu 16.04】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Ubuntu_16.04 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -u 16.04 -v 64 -a
fi

if [ $1 = '-Ubuntu_14.04' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Ubuntu 14.04】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Ubuntu_14.04 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -u 14.04 -v 64 -a
fi

if [ $1 = '-Windows_10_Lite' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows 10 Lite 精简版】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_10_Lite (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Historical_File_Windows_DD_Disk/Disk_Windows_10_x64_Lite_by_CXT_v1.0.vhd.gz'
fi

if [ $1 = '-Windows_Server_2008R2' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows Server 2008R2】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2008R2 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2008R2_DataCenter_CN_v3.27.vhd.gz'
fi

if [ $1 = '-Windows_Server_2003R2' ]
then
	echo -e "\033[33m 你选择安装 最新的 【Windows_Server_2003R2】（生命周期已结束，无任何支持） \033[0m"
	echo -e "\033[33m You have chosen to install the latest Windows_Server_2003R2 (EOL, No supported) \033[0m"
	echo -e "\n"
	echo -e "\033[41;30m ！！！警告：安装生命周期结束的旧系统会导致安全隐患！！！ \033[0m"
	echo -e "\033[41;30m !!! Warn：Installing the old system will lead to security risks !!! \033[0m"
	echo -e "\n"
	sleep 10s
	wget --no-check-certificate -qO Core_Install.sh 'https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/CoreShell/Core_Install_v3.1.sh' && bash Core_Install.sh -dd 'https://odc.cxthhhhh.com/SyStem/Windows_DD_Disks/Disk_Windows_Server_2003_DataCenter_CN_v7.1.vhd.gz'
fi





echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\033[35m 启动 安装 \033[0m"
echo -e "\033[32m Start Installation \033[0m"
echo "---------------------------------------------------------------------------------------------------------------------"
echo -e "\n"
exit