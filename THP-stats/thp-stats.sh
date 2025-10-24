#!/usr/bin/env bash
# thp-stats.sh — Transparent Hugepage statistics
#
# SPDX-License-Identifier: CC0-1.0
#
# CC0 1.0 Universal (Public Domain Dedication)
# To the extent possible under law, the author(s) have waived all copyright and
# related or neighboring rights to this work. You can copy, modify, distribute,
# and perform the work, even for commercial purposes, all without asking
# permission. See https://creativecommons.org/publicdomain/zero/1.0/

# Usage:
#   thp-stats.sh              # Default output
#   thp-stats.sh -v|--verbose # Verbose explanations

set -euo pipefail

THP_DIR=/sys/kernel/mm/transparent_hugepage
VERBOSE=0

while (( $# > 0 )); do
	case "$1" in
		-v|--verbose) VERBOSE=1 ;;
		-h|--help)
			echo "Usage: $0 [-v|--verbose]"
			exit 0 ;;
		*) echo "Usage: $0 [-v|--verbose]" >&2; exit 1 ;;
	esac
	shift
done

if [[ ! -d "$THP_DIR" ]]; then
	printf "Error: THP directory not found (%s)\n" "$THP_DIR" >&2
	exit 1
fi

###
# helpers
###
meminfo_val() {
	# Read a numeric value from /proc/meminfo for the given key
	local key="$1" val
	while IFS=":" read -r a b; do
		# strip leading/trailing whitespace
		a="${a//[[:space:]]/}"
		b="${b//[[:space:]]/}"
		if [[ "$a" == "$key" ]]; then
			val="${b%kB}"
			break
		fi
	done < /proc/meminfo
	echo "${val:-0}"
}

page_size() {
	# System page size in bytes. Fall back to 4096.
	local sz
	sz="$(getconf PAGESIZE 2>/dev/null || getconf PAGE_SIZE 2>/dev/null || true)"
	if [[ "$sz" =~ ^[0-9]+$ ]] && [ "$sz" -gt 0 ]; then
		echo "$sz"; return 0
	fi
	echo 4096
}

read_file() { [[ -r "$1" ]] && tr -d '\n' <"$1" || true; }

hn() {
    # Convert numbers into Si units.
	local n="${1:-0}"
	awk -v n="$n" '
	function fmt(x) {
		return (x>=1e12)?sprintf("%.2fT",x/1e12):
		       (x>=1e9)? sprintf("%.2fG",x/1e9):
		       (x>=1e6)? sprintf("%.2fM",x/1e6):
		       (x>=1e3)? sprintf("%.2fk",x/1e3): sprintf("%d",x)
	}
	BEGIN{ print fmt(n) }'
}

pct() {
    # Calculate a percentage.
	local a="${1:-0}" b="${2:-0}"
	if [[ "$b" -eq 0 ]]; then echo "0.0%"; else
		awk -v a="$a" -v b="$b" 'BEGIN{ printf("%.1f%%", (a*100.0)/b) }'
	fi
}

bytes_h() {
    # Convert numbers into IEC units.
	local b="${1:-0}"
	awk -v b="$b" '
	function out(x,u){ printf("%.2f %sB",x,u); exit }
	BEGIN{
		if (b>=1099511627776) out(b/1099511627776,"Ti");
		if (b>=1073741824)    out(b/1073741824,"Gi");
		if (b>=1048576)       out(b/1048576,"Mi");
		if (b>=1024)          out(b/1024,"Ki");
		printf("%d B", b);
	}'
}
kb_h() {
    # Convert KiB into IEC units.
    bytes_h "$(( ${1:-0} * 1024 ))"
}

PAGE_SIZE="$(page_size)"

line(){ printf '%s\n' "-----------------------------------------------------------------------------------"; }

if (( VERBOSE )); then
    ###
    # THP policy
    ###
    printf "THP policy\n"
    line
    printf "%-18s %s\n" "enabled"         "$(read_file "$THP_DIR/enabled")"
    printf "%-18s %s\n" "defrag"          "$(read_file "$THP_DIR/defrag")"
    printf "%-18s %s\n" "shmem_enabled"   "$(read_file "$THP_DIR/shmem_enabled")"
    printf "%-18s %s\n" "hpage_pmd_size" "$(bytes_h "$(read_file "$THP_DIR/hpage_pmd_size")")"
    printf "%-18s %s\n" "shrink_underused" "$(read_file "$THP_DIR/shrink_underused")"
    printf "%-18s %s\n" "use_zero_page"   "$(read_file "$THP_DIR/use_zero_page")"
    
    ###
    # khugepaged
    ###
    kp_dir="$THP_DIR/khugepaged"
    if [[ -d "$kp_dir" ]]; then
	printf "\n"
	printf "khugepaged\n"
	line
	for key in full_scans pages_collapsed pages_to_scan scan_sleep_millisecs \
	           alloc_sleep_millisecs defrag max_ptes_none max_ptes_shared max_ptes_swap; do
		if [[ $key = "pages_to_scan" ]]; then
			printf "%-22s %s\n" "$key" "$(read_file "$kp_dir/$key") ($(bytes_h $(( $(read_file "$kp_dir/$key") * PAGE_SIZE )) ))"
		else
			printf "%-22s %s\n" "$key" "$(read_file "$kp_dir/$key")"
		fi
	done
    fi
fi

###
# Per-size table
###
printf "\nAllocated THP pages\n"
line

printf "%-6s %8s %8s %6s %6s %10s %7s %7s %8s %8s\n" \
	"size" "alloc" "fb" "succ" "nr" "nr_bytes" "sh_al" "sh_fb" "splits" "sp_def"
line

# Build sorted list of hugepage directories:
# bytes label path → stored in array SZ
mapfile -t SZ <<< "$(
	for dir in "$THP_DIR"/hugepages-*; do
		[[ -d "$dir" ]] || continue
		# Extract size label (hugepages-2048kB → 2048kB)
		size_label="${dir##*/}"
		size_label="${size_label#hugepages-}"

		# Remove unit (kB) convert to bytes
		size_kb="${size_label%kB}"
		bytes=$(( size_kb * 1024 ))
		
		# Output: bytes<TAB>human_label<TAB>directory
		printf "%d\t%sk\t%s\n" "$bytes" "$size_kb" "$dir"
	done | sort -n -k1,1
)"

for row in "${SZ[@]}"; do
	# Split each tab-separated line into parts:
	read -r -a parts <<< "$row"
	label="${parts[1]}"
	dir="${parts[2]}"
	bytes="${parts[0]}"
	stats="$dir/stats"
	# Initialise associative array S with zero defaults.
	# Each key matches a THP stat file in $stats/
	declare -A S=(
		[anon_fault_alloc]=0 [anon_fault_fallback]=0
		[nr_anon]=0
		[shmem_alloc]=0 [shmem_fallback]=0
		[split]=0 [split_deferred]=0
	)
	# Read available data from files in $stats/
	for k in "${!S[@]}"; do
	    [[ -r "$stats/$k" ]] && S["$k"]="$(<"$stats/$k")"
	done
	total=$(( S[anon_fault_alloc] + S[anon_fault_fallback] ))
	success="$(pct "${S[anon_fault_alloc]}" "$total")"
	nr_bytes=$(( S[nr_anon] * bytes ))

    # Print one line of the per-size THP statistics table.
	printf "%-6s %8s %8s %6s %6s %10s %7s %7s %8s %8s\n" \
		"$label" "$(hn "${S[anon_fault_alloc]}")" "$(hn "${S[anon_fault_fallback]}")" \
		"$success" "${S[nr_anon]}" "$(bytes_h "$nr_bytes")" \
		"$(hn "${S[shmem_alloc]}")" "$(hn "${S[shmem_fallback]}")" \
		"$(hn "${S[split]}")" "$(hn "${S[split_deferred]}")"
done

if (( VERBOSE )); then
    line
    printf "Legend: alloc=anon_fault_alloc  fb=anon_fault_fallback  succ=alloc/(alloc+fb)\n"
    printf "        nr=nr_anon  nr_bytes=nr×page_size\n"
    printf "        sh_al=shmem_alloc  sh_fb=shmem_fallback\n"
    printf "        splits=split  sp_def=split_deferred\n"
fi

###
# THP usage summary
###
printf "\nIn-use THP-backed memory\n"
line

# Fetch /proc/meminfo values
sys_mem_kb="$(meminfo_val MemTotal)"
mem_avail_kb="$(meminfo_val MemAvailable)"
anon_kb="$(meminfo_val AnonHugePages)"
shmem_kb="$(meminfo_val ShmemHugePages)"
file_kb="$(meminfo_val FileHugePages)"

thp_bytes=$(( (anon_kb + shmem_kb + file_kb) * 1024 ))
used_mem_bytes=$(( (sys_mem_kb - mem_avail_kb) * 1024 ))

# Print results with binary units
printf "%-14s %10s \n" "AnonHugePages"  "$(kb_h "$anon_kb")"
printf "%-14s %10s \n" "ShmemHugePages" "$(kb_h "$shmem_kb")"
printf "%-14s %10s \n" "FileHugePages"  "$(kb_h "$file_kb")"
# Show THP as percentage of total memory
printf "%-14s %10s / %s (%s)\n" "THP / Used RAM" \
    "$(bytes_h "$thp_bytes")" \
    "$(bytes_h "$used_mem_bytes")" \
    "$(pct "$thp_bytes" "$used_mem_bytes" )"

line

###
# Explanations
###
if (( VERBOSE )); then
	printf "\nExplanation:\n"
	printf "  • alloc/fb — counts of THP allocations that succeeded or fell back to base 4 KiB\n"
	printf "    pages. A high fallback rate usually indicates memory fragmentation or that the\n"
	printf "    current defrag policy ('always', 'madvise', etc.) is too conservative.\n"
	printf "  • succ — success ratio (alloc ÷ (alloc + fb)). Low values suggest fragmentation\n"
	printf "    or that your workload would benefit from 'defer+madvise' or 'always' defrag.\n"
	printf "  • nr — number of hugepages currently mapped for this size.\n"
	printf "    A higher value means more memory is currently backed by THPs.\n"
	printf "  • nr_bytes — current memory in bytes mapped by THPs for this size.\n"
	printf "    Compare the sum of nr_bytes to total system RAM to gauge THP coverage.\n"
	printf "  • sh_al/sh_fb — counts of tmpfs/shmem THP allocations and fallbacks.\n"
	printf "    If these are high, shared-memory workloads (e.g., databases) are benefiting\n"
	printf "    from THP; if fallbacks rise, check the shmem_enabled policy.\n"
	printf "  • splits — number of THPs split back into 4 KiB pages (due to reclaim, migration,\n"
	printf "    or unmapping). Frequent splits may indicate memory pressure or short-lived THPs\n"
	printf "    where THP provides little benefit.\n"
	printf "  • sp_def — deferred splits queued for later. A growing backlog can cause latency\n"
	printf "    spikes; can be tuned via /sys/kernel/mm/transparent_hugepage/defrag.\n"
	printf "  • collapsed — number of 4 KiB page ranges merged into a THP.\n"
	printf "    A steady increase means THP promotion is working effectively.\n"

	printf "\n  khugepaged metrics:\n"
	printf "  • full_scans — total address-space scans completed by khugepaged since boot.\n"
	printf "    Larger numbers mean the background daemon is actively scanning.\n"
	printf "  • pages_collapsed — number of 2 MiB THPs successfully created by khugepaged.\n"
	printf "    Correlates with overall THP promotion efficiency.\n"
	printf "  • pages_to_scan — number of base pages examined per scan pass. Increasing this\n"
	printf "    speeds scanning but raises CPU usage; decreasing reduces overhead.\n"
	printf "  • scan_sleep_millisecs / alloc_sleep_millisecs — delay (ms) khugepaged sleeps\n"
	printf "    between scan or allocation cycles. Lower values increase responsiveness but\n"
	printf "    consume more CPU.\n"
	printf "  • defrag — 1 enables khugepaged to perform memory compaction while collapsing.\n"
	printf "    Disable (0) to reduce CPU overhead at the cost of fewer successful merges.\n"
	printf "  • max_ptes_none/shared/swap — thresholds controlling when a region is eligible\n"
	printf "    for collapse:\n"
	printf "      none   → maximum unmapped PTEs allowed in a candidate range.\n"
	printf "      shared → maximum shared PTEs allowed (avoid merging heavily shared areas).\n"
	printf "      swap   → maximum swapped-out PTEs allowed.\n"
	printf "    PTE stands for 'Page Table Entry' — each memory page has one entry in the\n"
	printf "    process's page table describing its mapping. khugepaged checks these to decide\n"
	printf "    if a region of 4 KiB pages is suitable for merging into a THP.\n"
	printf "    Lowering these limits makes khugepaged more selective; increasing allows more\n"
	printf "    aggressive collapsing at the risk of small CPU stalls.\n"
fi