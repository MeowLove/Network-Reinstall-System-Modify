#!/bin/bash
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "\033[33m LVM DISK Auto Partition Tools Version: 1.0.2 (20190622) \033[0m |  Technical support provided by [ https://cxthhhhh.com ] "
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "\033[33m 8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888 \033[0m"
echo -e "\033[33m 8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888   8888888    888888    88      8888888     88888888           88888   8888         888    888    888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888   88888888   888888   888      888888      88888888   88888     888   888    888888888    88   88888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888   888888888   8888   8888   8   8888   8   88888888   8888888   888   888     88888888    8   888888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888   888888888    88   88888   88   88   88   88888888   8888888   888   88888       8888       8888888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888   8888888888   88   88888   888   8  888   88888888   888888    888   888888888     88    8    88888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888   88888888888      888888   888      888   88888888   88888    8888   8888888888    88    88    8888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888888888888888888         888888    8888888   8888    8888   88888888          888888   888          888    8888    88888888888888888888888888 \033[0m"
echo -e "\033[33m 8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888 \033[0m"
echo -e "\033[33m 8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888888   888888888888888888888888888888888888888888888888       88888888888888888888888888888888888    88888888888   88888888888888888888888888888 \033[0m"
echo -e "\033[33m 8888888     888888888888888888888   88888888888888888888888          888888888888888888888888   88888   8888   88888   88888888888888888888888888888 \033[0m"
echo -e "\033[33m 888888   8   88888888888888888888   88888888888888888888888   8888    88888888888888888888888   888888888888   8888888888888888888888888888888888888 \033[0m"
echo -e "\033[33m 88888   88   88888   88888   88       888          88888888   8888    88        8888       8       88   88        88   8888         8888          88 \033[0m"
echo -e "\033[33m 8888   8888   8888   88888   8888   8888   88888    8888888          888888888   888    88888   88888   8888   88888   888   88888   888   8888   88 \033[0m"
echo -e "\033[33m 888            888   88888   8888   8888   88888    8888888   8888888888         888   888888   88888   8888   88888   88    88888   888   8888   88 \033[0m"
echo -e "\033[33m 888   888888    88    888    8888   8888   88888   88888888   888888888   8888   888   888888    8888   8888   88888   888   88888   888   8888   88 \033[0m"
echo -e "\033[33m 88    8888888   888          8888     888         888888888   888888888          888   8888888     88   88888     88   8888         8888   8888   88 \033[0m"
echo -e "\033[33m 8888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888 \033[0m"
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
echo -e "\033[33m LVM DISK Auto Partition Tools Version: 1.0.2 (20190622) \033[0m |  Technical support provided by [ https://cxthhhhh.com ] "
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
echo "Analyze Disk type (Virtual/Physical)......"
sleep 5
if [ -b /dev/vda1 ]; then
echo "Disk type: Virtual Disk"
echo "Recognition completed, waiting for disk response."
echo "Automatic partitioning will take more than 2 minutes to complete."
sleep 3s
echo "n
p
3


t
3
8e
w
" | fdisk /dev/vda
sleep 10s
echo "In the partition (1/5), waiting for the disk response will take more than 30 seconds."
partprobe
sleep 20s
echo "In the partition (2/5), waiting for the disk response will take more than 15 seconds."
pvcreate /dev/vda3
sleep 11s
echo "In the partition (3/5), waiting for the disk response will take more than 15 seconds."
vgextend centos /dev/vda3
sleep 11s
echo "In the partition (4/5), waiting for the disk response will take more than 15 seconds."
lvextend -l +100%FREE /dev/mapper/centos-root
sleep 11s
echo "In the partition (5/5), waiting for the disk response will take more than 10 seconds."
resize2fs -p /dev/mapper/centos-root
sleep 6s
elif [ -b /dev/xvda1 ]; then
echo "Disk type: Virtual Disk"
echo "Recognition completed, waiting for disk response."
echo "Automatic partitioning will take more than 2 minutes to complete."
sleep 3s
echo "n
p
3


t
3
8e
w
" | fdisk /dev/xvda
sleep 10s
echo "In the partition (1/5), waiting for the disk response will take more than 30 seconds."
partprobe
sleep 20s
echo "In the partition (2/5), waiting for the disk response will take more than 15 seconds."
pvcreate /dev/vda3
sleep 11s
echo "In the partition (3/5), waiting for the disk response will take more than 15 seconds."
vgextend centos /dev/vda3
sleep 11s
echo "In the partition (4/5), waiting for the disk response will take more than 15 seconds."
lvextend -l +100%FREE /dev/mapper/centos-root
sleep 11s
echo "In the partition (5/5), waiting for the disk response will take more than 10 seconds."
resize2fs -p /dev/mapper/centos-root
sleep 6s
else
echo "Disk type: Physical Disk"
echo "Recognition completed, waiting for disk response."
echo "Automatic partitioning will take more than 2 minutes to complete."
sleep 3s
echo "n
p
3


t
3
8e
w
" | fdisk /dev/sda
sleep 10s
echo "In the partition (1/5), waiting for the disk response will take more than 30 seconds."
partprobe
sleep 20s
echo "In the partition (2/5), waiting for the disk response will take more than 15 seconds."
pvcreate /dev/sda3
sleep 11s
echo "In the partition (3/5), waiting for the disk response will take more than 15 seconds."
vgextend centos /dev/sda3
sleep 11s
echo "In the partition (4/5), waiting for the disk response will take more than 15 seconds."
lvextend -l +100%FREE /dev/mapper/centos-root
sleep 11s
echo "In the partition (5/5), waiting for the disk response will take more than 10 seconds."
resize2fs -p /dev/mapper/centos-root
sleep 6s
fi
echo "Automatic partition completion, Please restart."
sleep 3s