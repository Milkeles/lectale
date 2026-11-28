#!/bin/sh
# ADR-0013: sign or verify a checksum manifest for an explicit list of assets.
# Run from the asset directory. Keys are PEM files, and asset arguments are basenames.
set -eu
export LC_ALL=C

if [ "$#" -lt 3 ]; then
    printf '%s\n' 'Usage: sign-and-verify.sh sign|verify KEY.pem ASSET...' >&2
    exit 2
fi
mode=$1
key=$2
shift 2

for asset do
    case "$asset" in
        ''|[-.]*|*[!A-Za-z0-9._-]*|SHA256SUMS|SHA256SUMS.sig)
            printf 'Invalid asset name: %s\n' "$asset" >&2
            exit 2
            ;;
    esac
    [ -f "$asset" ] || exit 1
done

umask 077
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' 0
trap 'exit 1' HUP INT TERM

case "$mode" in
    sign)
        openssl pkey -in "$key" -pubout -out "$scratch/public.pem"
        public_key=$scratch/public.pem
        ;;
    verify)
        public_key=$key
        ;;
    *)
        printf 'Unknown mode: %s\n' "$mode" >&2
        exit 2
        ;;
esac

key_info=$(openssl pkey -pubin -in "$public_key" -text_pub -noout)
case "$key_info" in
    'ED25519 Public-Key:'*) ;;
    *) printf '%s\n' 'Expected an Ed25519 key.' >&2; exit 1 ;;
esac

# Build the expected manifest from the requested files so verification also
# rejects a signed manifest with missing, extra or reordered entries.
for asset do
    digest=$(openssl dgst -sha256 -r "$asset")
    printf '%s  %s\n' "${digest%% *}" "$asset"
done > "$scratch/SHA256SUMS"

if [ "$mode" = sign ]; then
    openssl pkeyutl -sign -rawin -inkey "$key" \
        -in "$scratch/SHA256SUMS" -out "$scratch/signature"
    openssl base64 -A -in "$scratch/signature" -out "$scratch/SHA256SUMS.sig"
    mv "$scratch/SHA256SUMS" "$scratch/SHA256SUMS.sig" .
else
    openssl base64 -d -A -in SHA256SUMS.sig -out "$scratch/signature"
    openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
        -in SHA256SUMS -sigfile "$scratch/signature"
    cmp "$scratch/SHA256SUMS" SHA256SUMS
fi
