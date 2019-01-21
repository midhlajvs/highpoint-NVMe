#!/usr/bin/env bash

set -e

kernel_source="https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.20.3.tar.xz"
packages="epel-release gcc elfutils-libelf-devel openssl openssl-devel bc"
kernel_ver=$(echo $kernel_source | rev | cut -d "/" -f1 | cut -d "-" -f1 | cut -d "." -f3- | rev)


#Colors

function red { echo -e "\e[31m$@\e[0m" ; }
function yellow { echo -e "\e[33m$@\e[0m" ; }

function get_distro (){
       if [ -r /etc/os-release ]; then
           distro="$(. /etc/os-release && echo "$ID")"
       fi
}

function install_packages (){
     yellow "Installing Package $1 ...."
     /usr/bin/yum -y install $1
}

function command_exist (){
    command -v "$@" > /dev/null 2>&1
}

get_distro

case $distro in

   centos)
      for pkg in $packages
      do
           install_packages $pkg
      done
      yellow "Installing Development Tools ... "
      /usr/bin/yum -y groupinstall "Development Tools"

      if ! command_exist wget; then
         install_packages wget
         wget $kernel_source
      else
        wget $kernel_source
        yellow "Extracting Kernel Source to /usr/src ... "
        tar -xlvf $(echo $kernel_source | rev | cut -d / -f1 |rev) -C /usr/src
      fi

      if cd "/usr/src/"$(echo $kernel_source| rev| cut -d / -f1 | cut -d "." -f3- | rev); then
          yellow "Copying configuration file ....."
          cp /boot/config-$(uname -r) .config > /dev/null 2>&1 || red "Could not copy the configuration file"
          yellow "Updating configuration file .... "
          sed -i '/CONFIG_NVME_CORE/c\CONFIG_NVME_CORE=m' .config
          sed -i '/CONFIG_BLK_DEV_NVME/c\CONFIG_BLK_DEV_NVME=m' .config
          yes ""| make oldconfig && make -j16 && make modules && make modules_install && make install
          dracut --kver $kernel_ver --add-drivers "mpt3sas" /boot/initramfs-$kernel_ver".img" -f
      fi
   ;;
   *)
      red "Distribution is not supported"
   ;;
esac
