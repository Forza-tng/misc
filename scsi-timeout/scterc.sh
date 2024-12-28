#!/bin/sh

###
# Set SAS and SATA SCT error timeout.
#
# SPDX-License-Identifier: CC0-1.0
###

###
# Description
#
# Configures SCTERC timeout for all disks, setting it to 7 seconds (70
# deciseconds) for improved error handling. If SCTERC is unsupported,
# then Linux I/O timeout and the SCSI error handler (EH) timeouts are
# increased.
#
# SCTERC (SCT Error Recovery Control) allows the disk to limit its
# internal recovery time, ensuring that it returns an error promptly if
# the operation cannot be completed, for example due to a bad sector.
# This prevents the SCSI layer from triggering high-level resets (e.g.,
# LUN, bus, or host resets) that could lead to data loss or filesystem
# corruption. If SCTERC is not supported, setting a long "timeout"
# helps prevent premature EH invocation.
# 
# In Linux, the "timeout" value is how long the kernel waits for an
# individual I/O command to complete before declaring it as failed and
# invoking the SCSI Error Handler (EH). Once EH takes over, its
# behaviour is governed by the driver implementation. The "eh_timeout"
# parameter defines how long the EH is allowed to try recovery
# operations before escalating further or offlining the device.
#
# Some SMR (Shingeled Magnetic Recording) type harddisks are especially 
# prone to trigger Linux I/O timeouts, as their internal garbage
# collection can take several minutes to complete. You may need to
# increase the fb_timeout on such devices.
#
# See the Linux documentation for SCSI error handling at:
# https://www.kernel.org/doc/Documentation/scsi/scsi_eh.rst
###

sct=70           	# 70=7 seconds
sct_timeout=20   	# 20 seconds
sct_eh_timeout=10	# 10 seconds
fb_timeout=180   	# 180 seconds
fb_eh_timeout=30	# 30 seconds


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
