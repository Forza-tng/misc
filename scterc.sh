#!/bin/sh

###
# Set SAS and SATA SCT error timeout.
#
# SPDX-License-Identifier: CC0-1.0
###

###
# Description
#
# Configure SCTERC timeout for all disks, setting it to 7 seconds for improved
# error handling. If SCTERC is unsupported, it increases the Linux I/O timeout
# to 180 seconds. Adjusting timeouts prevents premature I/O failures during
# extended error recovery, improving reliability.
###

sct=70      	# 70=7 seconds
fallback=180	# 180 seconds

for i in /dev/sd[a-z] ; do
	device=$(basename "$i")

	# Attempt to set the SCTERC timeout to 7 seconds
	output=$(smartctl -l scterc,$sct,$sct "$i" 2>&1)
	
	# Check the output for "SCT Commands not supported"
	if echo "$output" | grep -q "SCT Commands not supported" ; then
		echo $fallback > "/sys/block/${device}/device/timeout"
		printf "%s is bad  " "$i"
	else
		printf "%s is good " "$i"
	fi

	# Show device identification
	smartctl -i "$i" | grep -E "(Device Model|Product:)"
done