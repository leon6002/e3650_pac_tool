#!/bin/bash
set -e

# Default Paths
BAO_BIN="$1"
GUEST_BIN="$2"

if [ -z "$BAO_BIN" ] || [ -z "$GUEST_BIN" ]; then
    echo "Usage: $0 <bao.bin> <guest.bin>"
    echo "Example: $0 bao.bin baremetal.bin"
    exit 1
fi

SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)

# Output setup
FILE_PATH=$(dirname "$BAO_BIN")
FILE_NAME=$(basename "$BAO_BIN" .bin)
OUTPUT_PATH="${FILE_PATH}/bao_pack_output"
OUTPUT_FILE_NAME="${FILE_NAME}"
mkdir -p "${OUTPUT_PATH}"

# Function to calculate DLP (Data Load Position) in 512-byte sectors
calc_next_dlp() {
    local prev_dlp=$1
    local prev_file=$2
    local size=$(stat -c%s "$prev_file")
    local sectors=$(( (size + 511) / 512 ))
    echo $(( prev_dlp + sectors + 1 ))
}

main() {
    # ---------------------------------------------------------
    # Image 0: Bao Hypervisor
    # ---------------------------------------------------------
    local BAO_DLP=8 # 0x8
    local BAO_ADDR="${BAO_ADDR:-0x00A40000}"
    
    # ---------------------------------------------------------
    # Image 1: Baremetal Guest
    # ---------------------------------------------------------
    local GUEST_DLP=$(calc_next_dlp $BAO_DLP "$BAO_BIN")
    local GUEST_ADDR="${GUEST_ADDR:-0x00AC0000}"
    
    echo "Configured Image 0 (Bao):   DLP=$(printf "0x%x" $BAO_DLP) Addr=$BAO_ADDR Path=$BAO_BIN"
    echo "Configured Image 1 (Guest): DLP=$(printf "0x%x" $GUEST_DLP) Addr=$GUEST_ADDR Path=$GUEST_BIN"

    SIGN_OUTPUT_IMAGE_PATHNAME="${OUTPUT_PATH}/${OUTPUT_FILE_NAME}.signed.bin"
    HEX_OUTPUT_IMAGE_PATHNAME="${OUTPUT_PATH}/${OUTPUT_FILE_NAME}.hex"
    PAC_OUTPUT_IMAGE_PATHNAME="${OUTPUT_PATH}/${OUTPUT_FILE_NAME}.pac"

    # 1. Generate Boot Package
    echo "======================== generate boot package ========================"
    SIGN_TOOL_PATHNAME="${SCRIPT_PATH}/builtin_tools/atb_signer"
    chmod +x "$SIGN_TOOL_PATHNAME"
    
    # Hardcoded values for simplicity
    "$SIGN_TOOL_PATHNAME" sign \
        --v 2 --sec_ver 0x0 --dgst sha256 --rcp rot=0x2 \
        key="${SCRIPT_PATH}/keys/TestRSA2048_ossl.pem" \
        --iib core=0 type=0 image="$BAO_BIN" dlp=$(printf "0x%x" $BAO_DLP) to=$BAO_ADDR entry=$BAO_ADDR \
        --iib core=0 type=0 image="$GUEST_BIN" dlp=$(printf "0x%x" $GUEST_DLP) to=$GUEST_ADDR entry=$GUEST_ADDR \
        --psn 0x0 --of "$SIGN_OUTPUT_IMAGE_PATHNAME"

    if [ ! -f "${SIGN_OUTPUT_IMAGE_PATHNAME}" ]; then
        echo "Error generating boot package."
        exit 1
    fi

    # 2. Generate Hex
    echo "======================== generate hex ========================"
    BIN2HEX_TOOL_PATHNAME="${SCRIPT_PATH}/builtin_tools/bin2hex"
    chmod +x "$BIN2HEX_TOOL_PATHNAME"
    
    "$BIN2HEX_TOOL_PATHNAME" -b 0x080FE000,"$SIGN_OUTPUT_IMAGE_PATHNAME" -o "$HEX_OUTPUT_IMAGE_PATHNAME"

    # 3. Generate PAC
    echo "======================== generate pac ========================"
    PAC_TOOL_PATHNAME="${SCRIPT_PATH}/builtin_tools/pactool"
    chmod +x "$PAC_TOOL_PATHNAME"
    
    "$PAC_TOOL_PATHNAME" make_pac_image_no_gpt --allow_empty_partitions --product E3650 \
        --da FDA:"${SCRIPT_PATH}/flashloader/E3650/flashloader.out" \
        --image 0x80FE000:"$SIGN_OUTPUT_IMAGE_PATHNAME" \
        --output "$PAC_OUTPUT_IMAGE_PATHNAME"
    
    echo "Done. PAC file generated at: $PAC_OUTPUT_IMAGE_PATHNAME"
}

main "$@"
