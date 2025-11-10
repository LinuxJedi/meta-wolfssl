# Yocto wolfssl FIPS and Commerical Setup Instructions

## Prerequisites

- Yocto environment is set up and ready.

## Steps

1. **Clone the meta-wolfssl Repository**

   ```bash
   git clone https://github.com/wolfSSL/meta-wolfssl.git
   ```

2. **Add meta-wolfssl to Yocto's bblayers.conf**

   Add the path to meta-wolfssl in the `bblayers.conf` file, typically found under `poky/build/conf/`:
   ```bash
   BBLAYERS ?= " \
         ...
         /path/to/yocto/poky/meta-wolfssl \
         ...
      "
   ```

3. **Update the IMAGE_INSTALL and WOLFSSL_TYPE Variable**

   Add `wolfssl` and `wolfcrypttest` to the `IMAGE_INSTALL` then add `fips` or `commerical` to the `WOLFSSL_TYPE` variables in your recipe or `poky/build/conf/local.conf`. If using `poky/build/conf/local.conf`, append as follows:
   ```
   IMAGE_INSTALL:append = " wolfssl wolfcrypttest "
   WOLFSSL_TYPE = "fips"
   ```

   If using other products with their commercial varient, make sure to set those variables to the `commerical` type:
    ```
    WOLFTPM_TYPE = "commercial"
    WOLFSSH_TYPE = "commercial"
    WOLFMQTT_TYPE = "commercial"
    WOLFCLU_TYPE = "commercial"
    ```

4. **Move the Downloaded FIPS/Commerical Bundle**

   Move or copy the downloaded `wolfssl-x.x.x-*.7z` file to the appropriate directory within the meta-wolfssl repository:
   ```
   cp /path/to/wolfssl-x.x.x-*.7z /path/to/meta-wolfssl/recipes-wolfssl/wolfssl/commerical/files
   ```

    Each product that has commerical support has their own respective directory structures to place their bundles.

5. **Edit poky/build/conf/local.conf**

    Update/Add the variables in your project's `poky/build/conf/local.conf`:
    `WOLFSSL_VERSION = "x.x.x"`: x.x.x should be the version of the fips/commercial bundle you downloaded. 
    `WOLFSSL_SRC_SHA = "<SHA_HASH>"`: `<SHA_HASH>` This is the sha hash given when you received the bundle.
    `WOLFSSL_SRC_PASS = "<PASSWORD>"`: `<PASSWORD>` This is the password given to unarchive the bundle.
    `WOLFSSL_SRC = "<BUNDLE_NAME>"`: `<BUNDLE_NAME>` This is the name of the bundle you wish to use without the .7z extension.  
    `WOLFSSL_FIPS_HASH_MODE = "auto"` (default) controls whether BitBake performs the additional hash pass automatically. Set it to `"manual"` if you plan to capture the hash yourself.
    Optional: set `WOLFSSL_FIPS_QEMU_EXTRA` if your QEMU invocation needs extra flags (for example, `-cpu cortex-a53`). When the build and target architectures match, the recipe will automatically invoke the target dynamic loader from `${STAGING_DIR_TARGET}` so you get the right glibc. You can still force native execution by exporting `WOLFSSL_FIPS_FORCE_NATIVE = "1"` or force QEMU with `WOLFSSL_FIPS_FORCE_QEMU = "1"`.

6. **Clean and Build wolfssl and wolfcrypttest**

   Ensure any artifacts from old builds are cleaned up, and then build `wolfssl` and `wolfcrypttest` with no errors:
   ```bash
   bitbake -c cleanall wolfssl
   bitbake -c cleanall wolfcrypttest
   bitbake wolfssl
   bitbake wolfcrypttest
   ```

7. **Compile Your Image**

   Perform a bitbake on your image recipe, for example: `bitbake core-image-minimal`.

8. **Automatic FIPS Hash Capture (Default)**

    With `WOLFSSL_FIPS_HASH_MODE` left at its default value `auto`, `bitbake wolfssl` now performs the extra hash pass internally:

    - The recipe first builds wolfSSL with a placeholder hash.
    - It then launches the bundled `wolfcrypt/test/.libs/testwolfcrypt` binary (directly or under QEMU user-mode when `BUILD_ARCH != TARGET_ARCH`) to capture the reported core hash.
    - The hash is written to `${WORKDIR}/wolfssl-fips.hash` (see `${T}/wolfssl-fips-hash.log` for the raw output) and the library is rebuilt automatically with the captured value embedded.
    - When `BUILD_ARCH != TARGET_ARCH`, the task uses `qemu-<arch>` from `qemu-native` (add extra args via `WOLFSSL_FIPS_QEMU_EXTRA`). When `BUILD_ARCH == TARGET_ARCH`, it runs the binary via the target dynamic loader in `${STAGING_DIR_TARGET}` so the correct glibc is used; fallbacks include setting `WOLFSSL_FIPS_FORCE_QEMU = "1"` to always use QEMU or `WOLFSSL_FIPS_FORCE_NATIVE = "1"` to run directly when you know the host glibc is compatible.

    No manual QEMU session is required anymore as long as a matching `qemu-<arch>` binary is available from `qemu-native`. You can pass additional flags through `WOLFSSL_FIPS_QEMU_EXTRA` or override the test arguments with `WOLFSSL_FIPS_TEST_ARGS` if your environment needs them.

9. **Manual Hash Capture (Fallback)**

    If user-mode QEMU for your target architecture is unavailable, set `WOLFSSL_FIPS_HASH_MODE = "manual"` inside `build/conf/local.conf`. Rebuild the image once, boot it (or run under `runqemu`), execute `wolfcrypttest`, copy the printed `hash = <HASH_VALUE>`, and then add `FIPS_HASH = "<HASH_VALUE>"` to `local.conf`.

10. **Rebuild and Test**

    Perform `bitbake wolfssl` (and `wolfcrypttest` if desired) again. When running in auto mode, the command `wolfcrypttest` inside your final image should complete with no errors after the second pass.
