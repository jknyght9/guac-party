#cloud-config
hostname: ${hostname}

package_update: false
package_upgrade: false

users:
  - name: ${username}    
    lock_passwd: false
    plain_text_passwd: ${username}
    gecos: Kali Linux
    groups: [adm, audio, cdrom, dialout, dip, floppy, lxd, netdev, plugdev, sudo, video]
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    shell: /bin/zsh

network:
  version: 2
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - [${kali_ip}]
      gateway4: ${gateway}
      nameservers:
        addresses: [${gateway}]