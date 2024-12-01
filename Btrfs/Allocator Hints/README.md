# Allocator Hints for Btrfs
This repository contains patches for adding allocator hints to Btrfs. These patches allow users to configure the Btrfs chunk allocator to prioritise specific devices for metadata or data allocation. This is particularly useful for mixed-device setups, such as combining SSDs with HDDs or NVMe devices with SSDs, to optimise performance and storage utilisation.

## About the Patches
The allocator hints patches were initially proposed in a series of early submissions to the Linux Btrfs mailing list in 2022 by Goffredo Baroncelli. Since then, the patches have been maintained and updated by Kakra to ensure compatibility with newer kernels and to add fixes and enhancements.

### Available Versions
The patches in this repository are named according to the kernel version they are designed for. For example:

- **btrfs_allocator_hints-6.1.patch**: For kernel version 6.1
- **btrfs_allocator_hints-6.6.patch**: For kernel version 6.6 (initial version)
- **btrfs_allocator_hints-6.6_v2.patch**: Kernel version 6.6 with additional fixes
- **btrfs_allocator_hints-6.6_v3.patch**: Kernel version 6.6 with further tweaks
- **btrfs_allocator_hints-6.6_v4.patch**: Latest patch for kernel version 6.6
- **btrfs_allocator_hints-6.12_v1.patch**: For kernel version 6.12

Each patch is tailored to work with its respective kernel version. Ensure you match the patch version to your Linux kernel version to avoid compatibility issues.

### Original Discussion
You can find the original discussion about these patches on the Linux Btrfs mailing list: [Allocator Hints Patch Series on lore.kernel.org](https://lore.kernel.org/all/Yhk5kyZL1J8hoQvX%40zen/T/)

### Author of this patch set
This repository is a mirror of the patches that have been graciously compiled and maintained by Kakra. They are available on his GitHub page:
[Kakra's GitHub Repository](https://github.com/kakra/linux/pull/36)

### More Information
For an in-depth explanation of the patches, how they work, and real-world examples, visit the wiki page: [Allocator Hints on TNOnline Wiki](https://wiki.tnonline.net/w/Btrfs/Allocator_Hints)

## Disclaimer
These patches are experimental and not officially included in the Linux kernel. Use them at your own risk. Always ensure you have backups of your data before testing these patches in production environments.

For questions or feedback, feel free to visit the wiki or reach out via [irc](https://wiki.tnonline.net/w/Btrfs/IRC).

## License
The licensing of these patches has not been explicitly stated in this repository. However, given their origin and intended use with the Linux kernel, they are likely under the terms of the **GNU General Public License, version 2 (GPLv2)**, which is the license of the [Linux kernel](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/COPYING) itself.

If you have any doubts or require confirmation, it is recommended to contact the original authors of the patches (e.g., Goffredo Baroncelli or Kakra) for clarification.

For more details about the GPLv2 license, see [https://www.gnu.org/licenses/old-licenses/gpl-2.0.html](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).