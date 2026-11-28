#!/bin/sh
set -eu

script=$(cd "$(dirname "$0")" && pwd)/sign-and-verify.sh
umask 077
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' 0
trap 'exit 1' HUP INT TERM
cd "$scratch"

openssl genpkey -algorithm ED25519 -out key.pem
openssl pkey -in key.pem -pubout -out public.pem
openssl genpkey -algorithm ED25519 -out other.pem

printf 'first\n' > first.zip
printf 'second\n' > second.apk

verify() {
    sh "$script" verify public.pem first.zip second.apk
}

expect_failure() {
    if verify > failure.log 2>&1; then
        printf 'FAIL: accepted %s\n' "$1" >&2
        exit 1
    fi
    printf 'PASS: rejected %s\n' "$1"
}

sh "$script" sign key.pem first.zip second.apk
verify
printf '%s\n' 'PASS: generated and verified both checksum files'

printf 'First\n' > first.zip
expect_failure 'a changed asset byte'
printf 'first\n' > first.zip

cp SHA256SUMS original-sums
sed '1s/first.zip/other.zip/' original-sums > SHA256SUMS
expect_failure 'a changed checksum line'
mv original-sums SHA256SUMS

sh "$script" sign other.pem first.zip second.apk
expect_failure 'a signature from another key'
