# grub-build

## Overview

This is our build repository for grub2.
We are currently leveraging the Fedora grub package as the base for our build.
The reason for this is simple:
it has the most up-to-date patchset for grub which particularly covers well all necessary Secure Boot changes.
It is also well maintained.

We are targeting to use this build of grub in both ONIE as well as SONiC.

The patches that we are currently adding are the following:

- `is_sb_enabled_command.patch` which has been taken and adopted from the ONIE repository. It provides a grub command for checking if secure boot is enabled.
- `no-devicetree-if-secure-boot.patch` disallows loading device tree data on arm platforms if secure boot is enabled.

We are stil planning to add two patches before we sign a production build:

- adding our patchset version to the version information
- reading and using an administrator password from an EFI variable

## Builds

All builds are done in Github action workflows.
They are leveraging the build runners in our lab.
All builds are using the `test` environment for signing.
This means that by default all builds are using our "TEST" certificate for signing the images.
The key and certificate are located on the HSMs in our lab.

If you want to produce a production build, you need to tag the commit.
And then you need to trigger a manual build and select the `prod` environment for signing.
There is no other way to create a production build.
This is done like this by design.
This will use the key and certificate which is embedded in our production shim which is signed by Microsoft.
