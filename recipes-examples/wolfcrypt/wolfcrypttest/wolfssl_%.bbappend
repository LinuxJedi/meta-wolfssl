# Conditionally configure wolfssl with wolfcrypttest support
# This bbappend checks the WOLFSSL_FEATURES and IMAGE_INSTALL variables

inherit wolfssl-helper

python __anonymous() {
    wolfssl_conditional_require(d, 'wolfcrypttest', 'inc/wolfcrypttest/wolfssl-enable-wolfcrypttest.inc')
}
