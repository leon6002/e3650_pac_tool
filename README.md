# e3650_pac_tool

`e3650_pac_tool` is a packaging workspace for generating E3650 PAC images.

It is intended to package a Bao hypervisor image together with a guest image, sign the combined boot image, convert it to hex, and finally generate an E3650-compatible `.pac` file for flashing.

## What This Repository Does

The main entry point is `bao_pac.sh`, which performs the following workflow:

1. Takes a Bao binary and a guest binary as inputs.
2. Calculates the guest image load position automatically.
3. Signs both images into a single boot package with `atb_signer`.
4. Converts the signed image into hex format with `bin2hex`.
5. Packs the signed image into an E3650 PAC file with `pactool` and `flashloader.out`.

The generated output is suitable for E3650 flashing workflows that expect a PAC package.

## Repository Layout

- `bao_pac.sh`: Main packaging script.
- `bootloader/`: Bootloader-related artifacts. The repository currently includes `simple_bootloader.pac` as a reference artifact.
- `builtin_tools/`: External tool binaries required by the packaging flow, including `atb_signer`, `bin2hex`, and `pactool`.
- `flashloader/E3650/`: E3650-specific flashloader binaries used during PAC generation.
- `keys/`: Signing key material used by `atb_signer`.

## Prerequisites

Before running the packaging script, make sure you have:

- A Linux environment with standard shell utilities.
- A Bao hypervisor binary, for example `bao.bin`.
- A guest image binary, for example `baremetal.bin`.
- The proprietary Semidrive tools and files listed below restored into this repository.

## Required Proprietary Files

Please contact Semidrive to obtain the `E3_SSDK_PTG5.2_Source_Code.tar.gz` package.

Copy the following files into this repository at the listed destinations:

- `tools/common/image_gen/builtin_tools/sdtools/linux/atb_signer` -> `builtin_tools/atb_signer`
- `tools/common/image_gen/builtin_tools/sdtools/linux/bin2hex` -> `builtin_tools/bin2hex`
- `tools/common/image_gen/builtin_tools/sdtools/linux/pactool` -> `builtin_tools/pactool`
- `tools/common/flashloader/E3650/flashloader.out` -> `flashloader/E3650/flashloader.out`
- `tools/common/image_gen/res_default/keys/TestRSA2048_ossl.pem` -> `keys/TestRSA2048_ossl.pem`

If any of these files are missing, the packaging flow will fail during signing or PAC generation.

## Usage

Run the script with the Bao image and the guest image:

```bash
./bao_pac.sh <bao.bin> <guest.bin>
```

Example:

```bash
./bao_pac.sh bao.bin baremetal.bin
```

The script creates an output directory next to the input Bao binary:

```text
<input-directory>/bao_pack_output/
```

Generated artifacts include:

- `<name>.signed.bin`: Signed boot package containing the Bao and guest images.
- `<name>.hex`: Hex-converted image.
- `<name>.pac`: Final E3650 PAC file.

## Optional Environment Variables

The script supports overriding the default load addresses:

- `BAO_ADDR`: Bao image load address. Default: `0x00A40000`
- `GUEST_ADDR`: Guest image load address. Default: `0x00AC0000`

Example:

```bash
BAO_ADDR=0x00A40000 GUEST_ADDR=0x00AC0000 ./bao_pac.sh bao.bin baremetal.bin
```

## Related Artifact

Files in `bootloader/` such as `simple_bootloader.pac` are built from the following repository:

https://github.com/leon6002/e3650_bootloader
