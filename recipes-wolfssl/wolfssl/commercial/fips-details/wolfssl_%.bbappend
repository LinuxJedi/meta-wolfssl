#Adjust these as needed
WOLFSSL_VERSION ?= ""

WOLF_LICENSE ?= "WolfSSL_LicenseAgmt_JAN-2022.pdf"
WOLF_LICENSE_MD5 ?= "be28609dc681e98236c52428fadf04dd"
WOLFSSL_SRC ?= ""
WOLFSSL_SRC_SHA ?= ""
WOLFSSL_SRC_PASS ?= ""

FIPS_HASH ?= "FFBB0434EB0EF2860CBAF6CB29F8F39B4432439EFD2A24C7D6442CBA8E06A4CC"

WOLFSSL_FIPS_HASH_MODE ?= "auto"
WOLFSSL_FIPS_HASH_MODE_class-native = "manual"
WOLFSSL_FIPS_HASH_MODE_class-nativesdk = "manual"
WOLFSSL_FIPS_PLACEHOLDER ?= "0000000000000000000000000000000000000000000000000000000000000000"
WOLFSSL_FIPS_HASH_FILE ?= "${WORKDIR}/wolfssl-fips.hash"
WOLFSSL_FIPS_HASH_LOG ?= "${T}/wolfssl-fips-hash.log"
WOLFSSL_FIPS_TEST_BINARY ?= "${B}/wolfcrypt/test/.libs/testwolfcrypt"
WOLFSSL_FIPS_TEST_ARGS ?= ""
WOLFSSL_FIPS_QEMU_EXTRA ?= ""
WOLFSSL_FIPS_FORCE_NATIVE ?= "0"
WOLFSSL_FIPS_FORCE_QEMU ?= "0"
WOLFSSL_FIPS_LIBRARY_PATH ?= "${B}/src/.libs:${B}/wolfcrypt/src/.libs:${STAGING_DIR_TARGET}/lib:${STAGING_DIR_TARGET}/usr/lib:${STAGING_DIR_TARGET}/lib64:${STAGING_DIR_TARGET}/usr/lib64"

#Do not adjust these variables
PR = "commercial.fips"
PV = "${WOLFSSL_VERSION}"

BBFILE_PRIORITY='1'

TARGET_CFLAGS += "-DFP_MAX_BITS=16384"
EXTRA_OECONF += "--enable-fips=v5 "

python __anonymous () {
    import bb
    import glob
    import os

    mode = d.getVar('WOLFSSL_FIPS_HASH_MODE')
    if mode != 'auto':
        d.appendVar('TARGET_CFLAGS', ' -DWOLFCRYPT_FIPS_CORE_HASH_VALUE=%s' % d.getVar('FIPS_HASH'))

    arch = d.getVar('TARGET_ARCH')
    suffix_map = {
        "aarch64": "aarch64",
        "arm": "arm",
        "armeb": "armeb",
        "x86_64": "x86_64",
        "i586": "i386",
        "i686": "i386",
        "powerpc": "ppc",
        "powerpc64": "ppc64",
        "mips": "mips",
        "mipsel": "mipsel",
        "riscv64": "riscv64",
        "riscv32": "riscv32"
    }
    suffix = suffix_map.get(arch, "")
    if suffix:
        d.setVar('WOLFSSL_QEMU_SUFFIX', suffix)
    else:
        d.setVar('WOLFSSL_QEMU_SUFFIX', '')

    if mode == 'auto':
        d.appendVar('DEPENDS', ' qemu-native')

    staging_dir = d.getVar('STAGING_DIR_TARGET')
    interpreter = ""
    if staging_dir:
        search_paths = [
            os.path.join(staging_dir, 'lib', 'ld-linux*so*'),
            os.path.join(staging_dir, 'lib64', 'ld-linux*so*'),
            os.path.join(staging_dir, 'usr', 'lib', 'ld-linux*so*'),
            os.path.join(staging_dir, 'usr', 'lib64', 'ld-linux*so*'),
        ]
        for pattern in search_paths:
            matches = glob.glob(pattern)
            if matches:
                interpreter = matches[0]
                break
    d.setVar('WOLFSSL_FIPS_INTERPRETER_AUTO', interpreter)
}

WOLFSSL_QEMU_SUFFIX ?= ""
WOLFSSL_QEMU_BINARY ?= "${STAGING_BINDIR_NATIVE}/qemu-${WOLFSSL_QEMU_SUFFIX}"
WOLFSSL_FIPS_INTERPRETER ?= "${WOLFSSL_FIPS_INTERPRETER_AUTO}"

do_compile[depends] += "${@bb.utils.contains('WOLFSSL_FIPS_HASH_MODE', 'auto', ' qemu-native:do_populate_sysroot', '', d)}"

wolfssl_fips_compile_pass() {
    local hash="$1"
    export CFLAGS="${WOLFSSL_FIPS_BASE_CFLAGS} -DWOLFCRYPT_FIPS_CORE_HASH_VALUE=${hash}"
    export TARGET_CFLAGS="${WOLFSSL_FIPS_BASE_TARGET_CFLAGS} -DWOLFCRYPT_FIPS_CORE_HASH_VALUE=${hash}"
    autotools_do_compile
    export CFLAGS="${WOLFSSL_FIPS_BASE_CFLAGS}"
    export TARGET_CFLAGS="${WOLFSSL_FIPS_BASE_TARGET_CFLAGS}"
}

wolfssl_fips_configure_pass() {
    local hash="$1"
    export CFLAGS="${WOLFSSL_FIPS_BASE_CFLAGS} -DWOLFCRYPT_FIPS_CORE_HASH_VALUE=${hash}"
    export TARGET_CFLAGS="${WOLFSSL_FIPS_BASE_TARGET_CFLAGS} -DWOLFCRYPT_FIPS_CORE_HASH_VALUE=${hash}"
    autotools_do_configure
    export CFLAGS="${WOLFSSL_FIPS_BASE_CFLAGS}"
    export TARGET_CFLAGS="${WOLFSSL_FIPS_BASE_TARGET_CFLAGS}"
}

wolfssl_fips_build_test_binary() {
    if [ -x "${WOLFSSL_FIPS_TEST_BINARY}" ]; then
        return
    fi

    bbnote "Building wolfCrypt test binary for FIPS hash generation"
    oe_runmake -C ${B}/wolfcrypt/test testwolfcrypt
}

wolfssl_fips_capture_hash() {
    if [ ! -x "${WOLFSSL_FIPS_TEST_BINARY}" ]; then
        bbfatal "wolfCrypt test binary ${WOLFSSL_FIPS_TEST_BINARY} not found; cannot capture FIPS hash"
    fi

    export LD_LIBRARY_PATH="${B}/src/.libs:${B}/wolfcrypt/src/.libs:${LD_LIBRARY_PATH}"
    local runner=""
    local need_qemu=0
    if [ "${BUILD_ARCH}" != "${TARGET_ARCH}" ]; then
        need_qemu=1
        if [ "${WOLFSSL_FIPS_FORCE_NATIVE}" = "1" ]; then
            need_qemu=0
        fi
    elif [ "${WOLFSSL_FIPS_FORCE_QEMU}" = "1" ]; then
        need_qemu=1
    fi

    if [ ${need_qemu} -eq 1 ]; then
        runner="${WOLFSSL_QEMU_BINARY}"
        if [ -z "${runner}" ] || [ ! -x "${runner}" ]; then
            if [ "${BUILD_ARCH}" != "${TARGET_ARCH}" ]; then
                bbfatal "No qemu binary available for ${TARGET_ARCH} (expected ${runner}). Set WOLFSSL_FIPS_HASH_MODE=\"manual\" or install qemu-user."
            else
                bbwarn "QEMU binary ${runner} not found; falling back to native execution for FIPS hash capture."
                runner=""
            fi
        else
            runner="${runner} ${WOLFSSL_FIPS_QEMU_EXTRA}"
            export QEMU_LD_PREFIX="${STAGING_DIR_TARGET}"
        fi
    fi

    local use_interpreter=0
    if [ -z "${runner}" ] && [ "${BUILD_ARCH}" = "${TARGET_ARCH}" ]; then
        if [ -n "${WOLFSSL_FIPS_INTERPRETER}" ] && [ -x "${WOLFSSL_FIPS_INTERPRETER}" ]; then
            use_interpreter=1
        fi
    fi

    if [ ${use_interpreter} -eq 1 ]; then
        bbnote "Capturing wolfSSL FIPS hash using target interpreter ${WOLFSSL_FIPS_INTERPRETER}"
    else
        bbnote "Capturing wolfSSL FIPS hash using ${runner:-native execution}"
    fi

    set +e
    if [ -n "${runner}" ]; then
        ${runner} ${WOLFSSL_FIPS_TEST_BINARY} ${WOLFSSL_FIPS_TEST_ARGS} > ${WOLFSSL_FIPS_HASH_LOG} 2>&1
    elif [ ${use_interpreter} -eq 1 ]; then
        ${WOLFSSL_FIPS_INTERPRETER} --library-path ${WOLFSSL_FIPS_LIBRARY_PATH} ${WOLFSSL_FIPS_TEST_BINARY} ${WOLFSSL_FIPS_TEST_ARGS} > ${WOLFSSL_FIPS_HASH_LOG} 2>&1
    else
        ${WOLFSSL_FIPS_TEST_BINARY} ${WOLFSSL_FIPS_TEST_ARGS} > ${WOLFSSL_FIPS_HASH_LOG} 2>&1
    fi
    local rc=$?
    set -e

    if [ ! -s "${WOLFSSL_FIPS_HASH_LOG}" ]; then
        bbfatal "wolfCrypt test produced no output (rc=${rc}). See ${WOLFSSL_FIPS_HASH_LOG}"
    fi

    local parsed=$(grep -E "hash = " "${WOLFSSL_FIPS_HASH_LOG}" | tail -n1 | awk -F'=' '{print $2}' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
    if [ -z "${parsed}" ]; then
        bbfatal "Unable to parse FIPS hash from ${WOLFSSL_FIPS_HASH_LOG}. Manually inspect the log and set FIPS_HASH if needed."
    fi

    echo "${parsed}" > "${WOLFSSL_FIPS_HASH_FILE}"
    bbnote "wolfSSL FIPS hash captured: ${parsed}"
}

do_compile() {
    if [ "${WOLFSSL_FIPS_HASH_MODE}" != "auto" ]; then
        autotools_do_compile
        return
    fi

    WOLFSSL_FIPS_BASE_CFLAGS="${CFLAGS}"
    WOLFSSL_FIPS_BASE_TARGET_CFLAGS="${TARGET_CFLAGS}"

    bbnote "wolfSSL FIPS auto mode: compiling placeholder image"
    wolfssl_fips_compile_pass "${WOLFSSL_FIPS_PLACEHOLDER}"
    wolfssl_fips_build_test_binary
    wolfssl_fips_capture_hash

    if [ ! -f "${WOLFSSL_FIPS_HASH_FILE}" ]; then
        bbfatal "wolfSSL FIPS hash file ${WOLFSSL_FIPS_HASH_FILE} missing after capture step"
    fi

    FINAL_FIPS_HASH=$(cat "${WOLFSSL_FIPS_HASH_FILE}")
    if [ -z "${FINAL_FIPS_HASH}" ]; then
        bbfatal "wolfSSL FIPS hash capture produced an empty value"
    fi

    bbnote "wolfSSL FIPS auto mode: reconfiguring and rebuilding with hash ${FINAL_FIPS_HASH}"
    rm -f ${B}/config.status ${B}/config.cache
    wolfssl_fips_configure_pass "${FINAL_FIPS_HASH}"
    wolfssl_fips_compile_pass "${FINAL_FIPS_HASH}"
}
