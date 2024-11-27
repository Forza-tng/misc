#!/bin/sh

###
# For Alpine Linux
#
# A convenience script that combines
# 'apk update', 'apk upgrade -s' and 'apk upgrade'
#
# SPDX-License-Identifier: CC0-1.0
##

# Update the apk cache
printf "Updating apk cache...\n"
apk update || exit

# Check for upgradable packages
printf "\nChecking for upgradable packages..."
UPGRADABLE=$(apk upgrade -s)

if echo "$UPGRADABLE" | grep -q "Upgrading"; then
	echo "The following packages can be upgraded:"
	echo "$UPGRADABLE"
	echo
	echo "Do you want to upgrade the packages? [y/N]: "
	read -r RESPONSE
	case "$RESPONSE" in
		[yY][eE][sS]|[yY])
			echo "Upgrading packages..."
			apk upgrade
			;;
		*)
			echo "Upgrade cancelled."
			;;
	esac
else
	echo "No packages to upgrade."
fi