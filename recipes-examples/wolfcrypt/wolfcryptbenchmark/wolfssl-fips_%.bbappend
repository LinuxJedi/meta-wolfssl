# Conditionally configure wolfssl-fips with wolfcryptbenchmark support
# Mirrors the non-FIPS wolfssl helper so benchmarks ride along when enabled.

inherit wolfssl-helper

python __anonymous() {
    wolfssl_conditional_require(d, 'wolfcryptbenchmark', 'inc/wolfcryptbenchmark/wolfssl-enable-wolfcryptbenchmark.inc')
}
