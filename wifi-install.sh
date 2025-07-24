sudo apt update && sudo apt install firmware-iwlwifi network-manager-gnome 

#sudo modprobe -r iwlwifi

sudo modprobe iwlwifi

sudo ip link set wlo1 up
