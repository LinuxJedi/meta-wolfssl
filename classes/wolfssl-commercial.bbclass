# wolfssl-commercial.bbclass
#
# This class provides helper functions for commercial wolfSSL bundles
# including password-protected 7z extraction and autogen disabling
#
# Usage in recipe:
#   inherit wolfssl-commercial
#
# Required variables:
#   COMMERCIAL_BUNDLE_DIR - Directory containing the .7z file
#   COMMERCIAL_BUNDLE_NAME - Bundle filename without .7z extension
#   COMMERCIAL_BUNDLE_PASS - Password for the bundle
#   COMMERCIAL_BUNDLE_TARGET - Target directory for extraction (usually WORKDIR)
#
# Example:
#   COMMERCIAL_BUNDLE_DIR = "${@os.path.dirname(d.getVar('FILE'))}/commercial/files"
#   COMMERCIAL_BUNDLE_NAME = "${WOLFSSL_SRC}"
#   COMMERCIAL_BUNDLE_PASS = "${WOLFSSL_SRC_PASS}"
#   COMMERCIAL_BUNDLE_TARGET = "${WORKDIR}"

# Add p7zip-native dependency
DEPENDS += "p7zip-native"

# Commercial bundles already ship generated configure scripts, so skip autoreconf
AUTOTOOLS_AUTORECONF = "no"

# Generic variables for commercial bundle extraction
COMMERCIAL_BUNDLE_DIR ?= ""
COMMERCIAL_BUNDLE_NAME ?= ""
COMMERCIAL_BUNDLE_PASS ?= ""
COMMERCIAL_BUNDLE_TARGET ?= "${WORKDIR}"

# Task to extract commercial bundle
python do_commercial_extract() {
    import os
    import bb
    
    bundle_dir = d.getVar('COMMERCIAL_BUNDLE_DIR')
    bundle_name = d.getVar('COMMERCIAL_BUNDLE_NAME')
    bundle_pass = d.getVar('COMMERCIAL_BUNDLE_PASS')
    target_dir = d.getVar('COMMERCIAL_BUNDLE_TARGET')
    
    if not bundle_dir:
        bb.fatal("COMMERCIAL_BUNDLE_DIR not set. Please set the directory containing the .7z bundle.")
    
    if not bundle_name:
        bb.fatal("COMMERCIAL_BUNDLE_NAME not set. Please set bundle filename (without .7z extension).")
    
    if not bundle_pass:
        bb.fatal("COMMERCIAL_BUNDLE_PASS not set. Please set bundle password.")
    
    bundle_path = os.path.join(bundle_dir, bundle_name + '.7z')
    
    if not os.path.exists(bundle_path):
        bb.fatal(f"Commercial bundle not found: {bundle_path}\n" +
                 "Please download the commercial bundle and place it in the appropriate directory.\n" +
                 "Contact support@wolfssl.com for access to commercial bundles.")
    
    # Copy bundle to target directory
    bb.plain(f"Extracting commercial bundle: {bundle_name}.7z")
    ret = os.system(f'cp -f "{bundle_path}" "{target_dir}"')
    if ret != 0:
        bb.fatal(f"Failed to copy bundle to {target_dir}")
    
    # Extract with password
    cmd = f'7za x "{target_dir}/{bundle_name}.7z" -p"{bundle_pass}" -o"{target_dir}" -aoa'
    ret = os.system(cmd)
    
    if ret != 0:
        bb.fatal(f"Failed to extract bundle. Check password and bundle integrity.")
    
    bb.plain("Commercial bundle extracted successfully")
}

# Add task after fetch, before patch
addtask commercial_extract after do_fetch before do_patch
do_commercial_extract[depends] += "p7zip-native:do_populate_sysroot"

# Task to create stub autogen.sh for commercial bundles
do_commercial_stub_autogen() {
    # Commercial bundles are pre-configured and don't need autogen.sh
    # Create a no-op autogen.sh to prevent automatic execution
    if [ ! -f ${S}/autogen.sh ]; then
        echo '#!/bin/sh' > ${S}/autogen.sh
        echo '# Commercial bundle - pre-configured, no autogen needed' >> ${S}/autogen.sh
        echo 'exit 0' >> ${S}/autogen.sh
        chmod +x ${S}/autogen.sh
        bbplain "Created stub autogen.sh for commercial bundle"
    else
        bbplain "Replacing existing autogen.sh with stub for commercial bundle"
        echo '#!/bin/sh' > ${S}/autogen.sh
        echo '# Commercial bundle - pre-configured, no autogen needed' >> ${S}/autogen.sh
        echo 'exit 0' >> ${S}/autogen.sh
        chmod +x ${S}/autogen.sh
    fi
}

# Add task after commercial_extract, before configure
addtask commercial_stub_autogen after do_commercial_extract before do_configure
