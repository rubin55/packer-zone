#!/usr/bin/env bash

echo "Do something with arguments, amongst which --baseurl: $*"

echo "Do post install update and upgrade"
#apt-get update
#apt-get -y dist-upgrade
#apt-get -y install linux-headers-$(uname -r)

echo "Do sudo configuration"
#sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=sudo' /etc/sudoers
#sed -i -e 's/%sudo  ALL=(ALL:ALL) ALL/%sudo  ALL=NOPASSWD:ALL/g' /etc/sudoers

echo "Do ssh daemon configuration"
#only allow ssh key based login
#echo "UseDNS no" >> /etc/ssh/sshd_config

echo "Do ssh client configuration"
#do something with generated private.pem here

echo "Do vmware configuration"
#apt-get -y install open-vm-tools
#mkdir -p /mnt/hgfs
#echo -n ".host:/ /mnt/hgfs vmhgfs rw,ttl=1,uid=my_uid,gid=my_gid,nobootwait 0 0" >> /etc/fstab

echo "Do password configuration"
# remove all passwords from all accounts

echo "Do final cleanup"
#apt-get -y autoremove
#apt-get -y clean
#rm /var/lib/dhcp/*
#rm /etc/udev/rules.d/70-persistent-net.rules
#rm -rf /dev/.udev/
#rm /lib/udev/rules.d/75-persistent-net-generator.rules

sleep 60
