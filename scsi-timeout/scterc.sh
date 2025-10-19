#!/bin/sh

###
# Set SCSI and SATA SCT error timeout.
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
# It is not uncommon to see I/O on normal HDDs taking more than
# 30 seconds, the Linux default. To accommodate this, the script sets
# the default "timeout" to 60 seconds for devices with SCTERC support.
# For devices without SCTERC, the fallback timeout is set to 300 seconds.
#
# Some SMR (Shingled Magnetic Recording) type HDDs are especially
# prone to trigger Linux I/O timeouts, as their internal garbage
# collection can take several minutes to complete. You may need to
# increase the "sct_device_timeout" and "fallback_device_timeout" for
# such devices.
#
# See the Linux documentation for SCSI error handling at:
# https://www.kernel.org/doc/Documentation/scsi/scsi_eh.rst
###

set -eu

scterc_value=70                 # SCTERC value in deciseconds (7 seconds)
sct_device_timeout=60           # 60s for devices with SCTERC support
sct_eh_recovery_timeout=10      # 10s for EH recovery with SCTERC
fallback_device_timeout=300     # 300s for devices without SCTERC
fallback_eh_recovery_timeout=30 # 30s for EH recovery without SCTERC

# Print header
printf "%-10s  %-40s  %-30s\n" "Device" "Model" "Status"
echo "------------------------------------------------------------------"

# Iterate over block devices under /sys/block/sd*
for sysblk in /sys/block/sd*; do
	[ -d "$sysblk" ] || continue
	device=$(basename "$sysblk")
	devpath="/dev/$device"
	[ -b "$devpath" ] || continue

	# Attempt to set the SCTERC timeout
	output=$(smartctl -l scterc,$scterc_value,$scterc_value "$devpath" 2>&1 || true)

	# Get the device model
	model=$(smartctl -i "$devpath" | grep -E "Device Model|Product:" | awk -F: '{print $2}' | xargs || echo "unknown")

	# Check the output for "SCT Commands not supported"
	if echo "$output" | grep -q "SCT Commands not supported" ; then
		status="No SCTERC support, using fallback"
		echo "$fallback_device_timeout" > "/sys/block/${device}/device/timeout"
		echo "$fallback_eh_recovery_timeout" > "/sys/block/${device}/device/eh_timeout"
	else
		status="SCTERC set ok"
		echo "$sct_device_timeout" > "/sys/block/${device}/device/timeout"
		echo "$sct_eh_recovery_timeout" > "/sys/block/${device}/device/eh_timeout"
	fi

	# Print the results
	printf "%-10s  %-40s  %-30s\n" "$devpath" "$model" "$status"
done
