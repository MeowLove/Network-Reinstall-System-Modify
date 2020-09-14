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

wget -N --no-check-certificate https://www.cxthhhhh.com/CXT-Library/Network-Reinstall-System-Modify/Network-Reinstall-System-Modify.sh && chmod a+x Network-Reinstall-System-Modify.sh

echo -e "\n\n\n"
clear
echo -e "\n"
echo "                                                           "
echo "================================================================"
echo "=                                                              ="
echo "=           一键网络重装系统 - 魔改版（图形化安装）            ="
echo "=        Network-Reinstall-System-Modify (Graphical Install)   ="
echo "=                                                              ="
echo "=                                https://www.cxthhhhh.com      ="
echo "=                                                              ="
echo "================================================================"
echo "                                                                "
ech="Which System do you want to Install:"
echo "                                                                "
echo "  0) Latest 【Bare-metal System Deployment Platform】(Recommend)"
echo "                                                                "
echo "  1) Latest 【CentOS 8】(Recommend)"
echo "  2) Latest 【CentOS 7】"
echo "                                                                "
echo "  3) Latest 【Debian 10】(Recommend)"
echo "  4) Latest 【Debian 9】"
echo "                                                                "
echo "  5) Latest 【Ubuntu 20.04】(Recommend)"
echo "  6) Latest 【Ubuntu 18.04】"
echo "  7) Latest 【Ubuntu 16.04】"
echo "                                                                "
echo "  8) Microsoft 【Windows Server 2019】(Recommend)"
echo "  9) Microsoft 【Windows Server 2016】"
echo "  10) Microsoft 【Windows Server 2012】"
echo "                                                                "
echo "  ======以下系统已经过时，失去官方技术支持，不推荐使用。======  "
echo "  ====== The system is outdated and is not recommended. ======  "
echo "                                                                "
echo "  31) Latest 【CentOS 6】"
echo "  32) Latest 【Debian 8】"
echo "  33) Latest 【Debian 7】"
echo "  34) Latest 【Ubuntu 14.04】"
echo "  35) Microsoft 【Windows 10 Lite】"
echo "  36) Microsoft 【Windows Server 2008R2】"
echo "  37) Microsoft 【Windows 7 Vienna】"
echo "  38) Microsoft 【Windows_Server_2003】"
echo "                                                                "
echo '  Custom DD System：bash Network-Reinstall-System-Modify.sh -DD "%URL%" '
echo "                                                                "
echo "================================================================"
echo "                                                                "
echo -n "Enter the System Identification Nnumber (for example: 0)"
read Num
case $Num in
  0) bash Network-Reinstall-System-Modify.sh -CXT_Bare-metal_System_Deployment_Platform ;;
  1) bash Network-Reinstall-System-Modify.sh -CentOS_8 ;;
  2) bash Network-Reinstall-System-Modify.sh -CentOS_7 ;;
  3) bash Network-Reinstall-System-Modify.sh -Debian_10 ;;
  4) bash Network-Reinstall-System-Modify.sh -Debian_9 ;;
  5) bash Network-Reinstall-System-Modify.sh -Ubuntu_20.04 ;;
  6) bash Network-Reinstall-System-Modify.sh -Ubuntu_18.04 ;;
  7) bash Network-Reinstall-System-Modify.sh -Ubuntu_16.04;;
  8) bash Network-Reinstall-System-Modify.sh -Windows_Server_2019;;
  9) bash Network-Reinstall-System-Modify.sh -Windows_Server_2016 ;;
  10) bash Network-Reinstall-System-Modify.sh -Windows_Server_2012R2 ;;
  
  31) bash Network-Reinstall-System-Modify.sh -CentOS_6 ;;
  32) bash Network-Reinstall-System-Modify.sh -Debian_8 ;;
  33) bash Network-Reinstall-System-Modify.sh -Debian_7 ;;
  34) bash Network-Reinstall-System-Modify.sh -Ubuntu_14.04 ;;
  35) bash Network-Reinstall-System-Modify.sh -Windows_10_Lite ;;
  36) bash Network-Reinstall-System-Modify.sh -Windows_Server_2008R2 ;;
  37) bash Network-Reinstall-System-Modify.sh -Windows_7_Vienna ;;
  38) bash Network-Reinstall-System-Modify.sh -Windows_Server_2003 ;;
  *) echo "Wrong input, please enter again!" ;;
esac