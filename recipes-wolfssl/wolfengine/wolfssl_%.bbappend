# Conditionally configure wolfssl with wolfengine support
# This bbappend checks the WOLFSSL_FEATURES and IMAGE_INSTALL variables

inherit wolfssl-helper

python __anonymous() {
    wolfssl_conditional_require(d, 'wolfengine', 'inc/wolfengine/wolfssl-enable-wolfengine.inc')
}
