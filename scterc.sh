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
#
# set scterc < timeout <= eh_timeout for predictable and efficient error
# handling
###

sct=70           	# 70=7 seconds
sct_timeout=15   	# 20 seconds
sct_eh_timeout=25	# 30 seconds
fb_timeout=180   	# 180 seconds
fb_eh_timeout=200	# 200 seconds

for i in /dev/sd[a-z] ; do
	device=$(basename "$i")

	# Attempt to set the SCTERC timeout to 7 seconds
	output=$(smartctl -l scterc,$sct,$sct "$i" 2>&1)

	# Check the output for "SCT Commands not supported"
	if echo "$output" | grep -q "SCT Commands not supported" ; then
		printf "%s: no SCTERC support, using fallback.  " "$i"
		echo $fb_timeout    > "/sys/block/${device}/device/timeout"
		echo $fb_eh_timeout > "/sys/block/${device}/device/eh_timeout"
	else
		printf "%s: SCTERC set ok. " "$i"
		echo $sct_timeout    > "/sys/block/${device}/device/timeout"
		echo $sct_eh_timeout > "/sys/block/${device}/device/eh_timeout"
	fi

	# Show device identification
	smartctl -i "$i" | grep -E "(Device Model|Product:)"
done
