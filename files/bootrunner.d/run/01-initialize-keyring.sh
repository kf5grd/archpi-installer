#!/bin/bash

# wait until we have an internet connection
while ! ping -c 1 eff.org &>/dev/null; do
    sleep 1
done

pacman-key --init
pacman-key --populate archlinuxarm
yes | pacman -S archlinuxarm-keyring
