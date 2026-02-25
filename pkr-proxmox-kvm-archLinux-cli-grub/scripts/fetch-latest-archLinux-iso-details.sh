#!/bin/bash
# Script to fetch the latest ArchLinux ISO details (URL and checksum)
set -e

#ARCHLINUX_MIRROR_BASE="https://mirror.csclub.uwaterloo.ca/archlinux/iso/"
ARCHLINUX_MIRROR_BASE="https://mirrors.mit.edu/archlinux/iso/"
DYNAMIC_VARS_FILE="./vars/generated-archlinux-vars.pkrvars.hcl"

ARCHLINUX_MIRROR=$(curl -s ${ARCHLINUX_MIRROR_BASE} | grep -oP "2026\.\d+\.\d+/" | tail -n1)
#echo "Detected latest ArchLinux ISO mirror: $ARCHLINUX_MIRROR"
#exit 0;
if [ -z "$ARCHLINUX_MIRROR" ]; then
    echo 'ERROR: Could not detect latest ArchLinux ISO on remote ArchLinux repository.';
    exit 1;
fi  

#echo "Fetching latest ArchLinux ISO details from mirror: ${ARCHLINUX_MIRROR_BASE}${ARCHLINUX_MIRROR}"
ISO_FILE=$(curl -s "${ARCHLINUX_MIRROR_BASE}${ARCHLINUX_MIRROR}" | grep -oP 'archlinux-2026\.\d+\.\d+-x86_64\.iso' | head -n1)
#echo "Detected latest ArchLinux ISO file: $ISO_FILE"
#exit 0;
if [ -z "$ISO_FILE" ]; then
    echo 'ERROR: Could not detect ARCHLINUX ISO on remote ArchLinux repository.';
    exit 1;
fi

ISO_URL="${ARCHLINUX_MIRROR_BASE}${ARCHLINUX_MIRROR}${ISO_FILE}"

#echo "Latest ArchLinux ISO URL: $ISO_URL"
# Fetch matching SHA512 checksum
SHA256=$(curl -s ${ARCHLINUX_MIRROR_BASE}${ARCHLINUX_MIRROR}sha256sums.txt | grep "$ISO_FILE" | awk '{print $1}')
#echo "Latest ArchLinux ISO SHA256: $SHA256"

if [ -z "$SHA256" ]; then
    echo 'ERROR: Could not pick up SHA256 checksum on remote ArchLinux repository.';
    exit 1;
fi
#exit 0;

echo "dynamic_iso_url = \"$ISO_URL\"" >  ${DYNAMIC_VARS_FILE}
echo "dynamic_iso_checksum = \"sha256:${SHA256}\"" >> ${DYNAMIC_VARS_FILE}
#echo "locals { dynamic_file_name = \"$ISO_FILE\" }" >> ${DYNAMIC_VARS_FILE}

echo "Fetched latest ArchLinux ISO details:"
echo "ISO URL: $ISO_URL"
echo "SHA256: $SHA256"
echo "Details written to ${DYNAMIC_VARS_FILE}"
exit 0
