#!/bin/bash

#####Boot to Windows by default on a dual boot system
    #Run command: grep menuentry /boot/grub/grub.cfg
    #Copy the menu item that boots to Windows
    #Run command: nano -B /etc/default/grub
    #Change the GRUB_DEFAULT entry to point to the Windows menu entry. For example:
    #GRUB_DEFAULT=”Windows Boot Manager (on /dev/sda1)”
    #Run command: update-grub
    #Shutdown -r now

#####Linux Check Disk and Mem Usage
    #free -m
    #df -h