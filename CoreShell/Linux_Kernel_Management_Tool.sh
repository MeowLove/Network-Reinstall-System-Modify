#!/bin/bash

# Check root Permissions
clear
if [ "$(id -u)" -ne 0 ]; then
  echo "You must run this script as root."
  exit 1
fi

# Program: Display Current Boot Linux Kernel version
function display_current_kernel() {
  echo ""
  echo "Current Boot Linux Kernel:"
  uname -r
  sleep 3s
}

# Program: Display Next Boot Default Kernel version
function display_default_kernel() {
  default_kernel=$(grubby --default-kernel)
  echo ""
  echo "Next Boot Default Kernel:"
  echo "$default_kernel"
  sleep 3s
}

# Program: Identify Linux (RHEL) version
CURRENT_LINUX_MAIN_VERSION=$(cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/')
echo "Current Linux Main Version is: " $CURRENT_LINUX_MAIN_VERSION
ELREPO_KEY_URL="https://www.elrepo.org/RPM-GPG-KEY-elrepo.org"
ELREPO_RPM_URL="https://www.elrepo.org/elrepo-release-$CURRENT_LINUX_MAIN_VERSION.el$CURRENT_LINUX_MAIN_VERSION.elrepo.noarch.rpm"
RPM_PACKAGE="elrepo-release"

# Program: Upgrade Kernel (LongTerm or MainLine Kernel Canbe Select)
function upgrade_kernel() {

# Program: Check ELRepo public key
echo "Check and Import ELRepo public key...."
curl -s -o /tmp/elrepo-public-key.temp $ELREPO_KEY_URL
rpm --import /tmp/elrepo-public-key.temp 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Finished"
else
    echo "Error"
    rm -f /tmp/elrepo-public-key.temp
    exit 1
fi
rm -f /tmp/elrepo-public-key.temp

# Program: Install ELRepo
if ! dnf list installed | grep -q $RPM_PACKAGE
then
    echo "Install ELRepo..."
    dnf install -y $ELREPO_RPM_URL &>/dev/null
    sed -i 's/mirrorlist=/#mirrorlist=/g' /etc/yum.repos.d/elrepo.repo
    sed -i 's#elrepo.org/linux#mirrors.tuna.tsinghua.edu.cn/elrepo#g' /etc/yum.repos.d/elrepo.repo
    dnf makecache &>/dev/null
    dnf --disablerepo=\* --enablerepo=elrepo-kernel repolist
    echo "ELRepo Install Done."
else
    echo "ELRepo has been Installed."
fi

# Program: Check ELRepo Installation status
if dnf list installed | grep -q $RPM_PACKAGE
then
    echo "ELRepo Successfully Installed and Available."
else
    echo "ELRepo Installation Failed or NotFound."
    exit 1
fi

    # Display available Kernel packages
    echo "available Kernel packages:"
    dnf --disablerepo=\* --enablerepo=elrepo-kernel list 'kernel*'
    echo "Select Kernel version to Upgrade:"
    echo "1. LongTerm（lt）"
    echo "2. MainLine（ml）"
    echo -n "Please Select (1-2): "
    read -r kernel_type

    case $kernel_type in
    1)
    # Upgrade to LongTerm（lt） Kernel
    echo "Upgrade to LongTerm（lt） Kernel..."
    dnf --disablerepo=\* --enablerepo=elrepo-kernel install -y kernel-lt.x86_64 &>/dev/null1
    dnf remove kernel-tools-libs.x86_64 kernel-tools.x86_64 -y &>/dev/null
    dnf --disablerepo=\* --enablerepo=elrepo-kernel install -y kernel-lt-tools.x86_64 &>/dev/null

    if [ $? -eq 0 ]; then   
        echo "LongTerm（lt） Kernel Upgrade Completed."
      else
        echo "Failed to Upgrade Linux Kernel."
      fi
      sleep 3s
      ;;
    2)
    # Upgrade to MainLine（ml） Kernel
    echo "Upgrade to MainLine（ml） Kernel..."
    dnf --disablerepo=\* --enablerepo=elrepo-kernel install -y kernel-ml.x86_64 &>/dev/null
    dnf remove kernel-tools-libs.x86_64 kernel-tools.x86_64 -y &>/dev/null
    dnf --disablerepo=\* --enablerepo=elrepo-kernel install -y kernel-ml-tools.x86_64 &>/dev/null

      if [ $? -eq 0 ]; then 
        echo "MainLine（ml） Kernel Upgrade Completed."
      else
        echo "Failed to Upgrade Linux Kernel."
      fi
      sleep 3s
      ;;
    *)
      echo "Invalid Input, Check keyboard input."
      sleep 3s
      ;;
  esac
}

# Program: Set Next Boot Kernel
function set_next_boot_kernel() {
    echo "List the Installed Kernels and index Number."
    grubby --info=ALL | grep -E '^(index=|kernel=)'
    echo -n "Enter the Index Number of the Kernel for Next Boot: "
    read -r modir_type
    grubby --set-default $modir_type
    echo "The Next Default Boot Kernel is set successfully."
    grubby --default-kernel
    # Ask the user for restart server
    read -p "Do you want to restart the server? (y/n): " response

    # Restart System Option
    case "$response" in
        [yY][eE][sS]|[yY])
            echo "Server is Restarting......"
            sleep 3s
            reboot
            ;;
        *)
            echo "User Ignores Restart Server."
            sleep 3s
            ;;
    esac

}

# Program: Clean Kernel
function clean_kernel() {

# List All Installed Kernel packages.
INSTALLED_KERNELS=$(rpm -qa | grep kernel | grep -v "^kernel-devel" | grep -v "^kernel-headers" | grep -v "^kernel-tools" | sort -V)

# Get Currently Boot Kernel version.
CURRENT_KERNEL=$(uname -r)

# Displays All Installed Kernel versions.
echo "Installed Kernel version: "
echo "$INSTALLED_KERNELS"
echo

# Prompt User to Enter the Kernel Version to be Deleted (Multiple versions can be Entered, Separated by Spaces).
read -p "Please enter the kernel version to be deleted (separated by spaces, or enter 'all' to delete all kernels except the current boot): " KERNELS_TO_REMOVE

# If User inputs 'all', All Kernels will be Deleted except the Currently Boot Kernel.
if [ "$KERNELS_TO_REMOVE" == "all" ]; then
  KERNELS_TO_REMOVE=$(echo "$INSTALLED_KERNELS" | grep -v "$CURRENT_KERNEL")
fi

# Traverse the Kernel version Entered by user, check whether it contains the currently boot kernel.
for KERNEL in $KERNELS_TO_REMOVE; do
  if [ "$KERNEL" == "$CURRENT_KERNEL" ]; then
    echo "Error: Cannot Delete Currently Boot Kernel. $CURRENT_KERNEL"
    exit 1
  fi
done

# Ask User If you are Sure you want to Delete these Kernels.
read -p "Are you sure you want to delete the following kernel? $KERNELS_TO_REMOVE (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Wrong Input, Operation Cancelled."
  exit 0
fi

# Delete the User-Specified Kernel package.
for KERNEL in $KERNELS_TO_REMOVE; do
  echo "Deleting Kernel $KERNEL..."
  rpm -e --nodeps "$KERNEL"
  if [ $? -ne 0 ]; then
    echo "Error: Unable Delete Kernel. $KERNEL"
  else
    echo "Kernel $KERNEL Successfully Deleted."
  fi
done

echo "Operation Completed."
sleep 3s
}



# Show Kernel Manger Menu
function show_menu() {
  clear
  echo ""
  echo "================================"
  echo "Linux Kernel Management Tool"
  echo "for RHEL/CentOS/Rocky/Alma/Oracle"
  echo "via: cxthhhhh.com"
  echo "================================"
  echo "Please Select："
  echo "1. Display Currently Boot Linux Kernel"
  echo "2. Display Next Boot Default Kernel"
  echo "3. Upgrade Kernel"
  echo "4. Set Next Boot Kernel"
  echo "5. Clean Kernel"
  echo "0. Quit"
  echo "================================"
  echo ""
}

# Menu
while true; do
  show_menu
  read -p "Please Select (0-5): " choice

  case $choice in
    1)
      display_current_kernel
      ;;
    2)
      display_default_kernel
      ;;
    3)
      upgrade_kernel
      ;;
    4)
      set_next_boot_kernel
      ;;
    5)
    clean_kernel
    ;;
    0)
      echo "Quit Tool..."
      exit 0
      ;;
    *)
      echo "Invalid Input, Check keyboard input."
      sleep 3s
      ;;
  esac
done