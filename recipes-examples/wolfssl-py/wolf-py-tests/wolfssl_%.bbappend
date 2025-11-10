# Conditionally configure wolfssl with wolf-py-tests support
# This bbappend checks the WOLFSSL_FEATURES and IMAGE_INSTALL variables

inherit wolfssl-helper

python __anonymous() {
    wolfssl_conditional_require(d, 'wolf-py-tests', 'inc/wolf-py-tests/wolfssl-enable-wolf-py-tests.inc')
}
