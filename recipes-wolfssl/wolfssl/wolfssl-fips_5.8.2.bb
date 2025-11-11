SUMMARY = "wolfSSL FIPS 140-3 Validated Cryptography"
DESCRIPTION = "wolfSSL is a lightweight SSL/TLS library with FIPS 140-3 validated cryptography module. This recipe provides the FIPS-validated version of wolfSSL."
HOMEPAGE = "https://www.wolfssl.com/products/wolfssl-fips/"
BUGTRACKER = "https://github.com/wolfssl/wolfssl/issues"
SECTION = "libs"

# Commercial/FIPS license - Update when using commercial bundle
LICENSE = "Proprietary"
LIC_FILES_CHKSUM = "file://${WOLFSSL_LICENSE_FILE};md5=${WOLFSSL_LICENSE_MD5}"
WOLFSSL_LICENSE ?= "WolfSSL_LicenseAgmt_JAN-2024.pdf"
WOLFSSL_LICENSE_MD5 ?= "9b56a02d020e92a4bd49d0914e7d7db8"


DEPENDS += "util-linux-native"

# This recipe provides wolfssl-fips, wolfssl (package name), and virtual/wolfssl (interface)
PROVIDES += "wolfssl-fips wolfssl virtual/wolfssl"
RPROVIDES:${PN} = "wolfssl-fips wolfssl"

# Lower preference so regular wolfssl is default
# Users must explicitly set PREFERRED_PROVIDER_virtual/wolfssl = "wolfssl-fips"
DEFAULT_PREFERENCE = "-1"

# FIPS bundle source - expects commercial bundle in files/ directory
# User must set these in local.conf:
#   WOLFSSL_VERSION = "x.x.x"
#   WOLFSSL_SRC = "wolfssl-x.x.x-commercial-fips-linux"
#   WOLFSSL_SRC_SHA = "sha256sum of bundle"
#   WOLFSSL_SRC_PASS = "password for bundle"
#   WOLFSSL_LICENSE = "${S}/LICENSING"  (or path to license file relative to source code)
#   WOLFSSL_LICENSE_MD5 = "md5sum of license"
#   FIPS_HASH = "hash value after first build" (for FIPS validation)

# Commercial bundle configuration
# Users can set WOLFSSL_SRC_DIR in local.conf to specify bundle location
WOLFSSL_SRC_DIR ?= "${@os.path.dirname(d.getVar('FILE', True))}/commercial/files"

# Map to commercial class variables
COMMERCIAL_BUNDLE_DIR = "${WOLFSSL_SRC_DIR}"
COMMERCIAL_BUNDLE_NAME = "${WOLFSSL_SRC}"
COMMERCIAL_BUNDLE_PASS = "${WOLFSSL_SRC_PASS}"
COMMERCIAL_BUNDLE_TARGET = "${WORKDIR}"

SRC_URI = "file://${COMMERCIAL_BUNDLE_DIR}/${WOLFSSL_SRC}.7z;unpack=false"
SRC_URI[sha256sum] = "${WOLFSSL_SRC_SHA}"

S = "${WORKDIR}/${WOLFSSL_SRC}"

python () {
    import os

    license_path = d.getVar('WOLFSSL_LICENSE')
    if not license_path:
        return

    if not os.path.isabs(license_path):
        license_path = os.path.join(d.getVar('WORKDIR'), license_path)
        if not os.path.exists(license_path):
            license_path = os.path.join(d.getVar('S'), d.getVar('WOLFSSL_LICENSE'))

    d.setVar('WOLFSSL_LICENSE_FILE', license_path)
}

inherit autotools pkgconfig wolfssl-helper wolfssl-commercial wolfssl-fips-helper

# Skip the package check for wolfssl-fips itself (it's the base library)
deltask do_wolfssl_check_package

BBCLASSEXTEND = "native nativesdk"

# FIPS-specific configuration
# Note: FIPS hash is handled by wolfssl-fips-helper.bbclass
TARGET_CFLAGS += "-DFP_MAX_BITS=16384"
EXTRA_OECONF += " \
    --enable-fips=v5 \
    --enable-reproducible-build \
"
