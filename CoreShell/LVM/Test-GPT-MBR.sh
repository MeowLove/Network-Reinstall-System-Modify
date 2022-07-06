#!/bin/bash

# 获取磁盘，为保证数据安全，以下仅对第一个磁盘，通常为数据盘。进行操作。
# (如需修改其他磁盘，请手动修改本分区程序)
DISK=`ls /dev/*da | head -1`
DISK2=`ls /dev/*db | head -1`
DISK3=`ls /dev/*dc | head -1`

echo " DISK= "+$DISK
echo " DISK2= "+$DISK2
echo " DISK3= "+$DISK3

# 设置新的自动拓展分区ID（默认值）
PART=$DISK"0"
echo " PART= "+$PART

# 获取VG
VGNAME=`lvdisplay | grep "VG Name" | awk ' ''{print $3}'`
echo " VGNAME= "+$VGNAME
# 获取LV
LVNAME=`lvdisplay | grep "LV Name" | awk ' ''{print $3}'`
echo " LVNAME= "+$LVNAME

# 判断MBR还是GPT
CXTDTYPE=`fdisk -l | grep -o gpt | head -1`
if [ $CXTDTYPE == "gpt" ] || [ $CXTDTYPE == "GPT" ];then
# 创新新的GPT分区为LVM
echo "(GPT) Creating new partition..."
PART=$DISK"4"
echo " PART(GPT)= "+$PART
# 新的GPT分区为LVM创建完毕
else
# 创新新的MBR分区为LVM
echo "(MBR) Creating new partition..."
PART=$DISK"3"
echo " PART(MBR)= "+$PART
# 新的MBR分区为LVM创建完毕
fi


# 创建PV
echo "Creating PV..."
echo " PART= "+$PART

