# if you adjust the fedora version here, adjust it below during the checkout as well
FROM fedora:37
ARG TARGETARCH
ARG BUILDARCH
# unfortunately TARGETARCH is useless, so we need to set our own as well
ARG EFIARCH=x64
ARG TARGETHOSTARCH=x86_64
ARG MKIMAGEARCH=x86_64
ARG GPG_PUBKEY=test
RUN echo "Building grub for \"${TARGETARCH}\" (\"${TARGETHOSTARCH}\") on \"${BUILDARCH}\" (EFIARCH: \"${EFIARCH}\") using GPG key: \"${GPG_PUBKEY}\""

# basics for building debian packages
# we are adding pedump for checking the resulting EFI images
RUN dnf group install -y "C Development Tools and Libraries" "Development Tools"
RUN dnf install -y fedpkg ruby
RUN gem install pedump

# these are all grub build dependencies
RUN dnf install -y \
    bzip2-devel \
    dejavu-sans-fonts \
    device-mapper-devel \
    freetype-devel \
    fuse-devel \
    gettext-devel \
    help2man \
    ncurses-devel \
    pesign \
    rpm-devel \
    squashfs-tools \
    texinfo

# copy the grub sources
RUN mkdir /artifacts
ADD grub-fedora /src/grub
WORKDIR /src/grub

# we will build from the fedora 37 tree for now
RUN git checkout f37

# add all our adjustments now
# adjusted SBAT file
ADD sbat.csv.in /src/grub/

# as well as our own grub patches
# this one is to forbid loading of different device trees on arm platforms
ADD no-devicetree-if-secure-boot.patch 9998-no-devicetree-if-secure-boot.patch
RUN echo "Patch9998: 9998-no-devicetree-if-secure-boot.patch" >> grub.patches
# this one is an adjusted patch from ONIE which adds the `is_sb_enabled` command
# to test for secure boot availability in grub configs/scripts
ADD is_sb_enabled_command.patch 9999-is_sb_enabled_command.patch
RUN echo "Patch9999: 9999-is_sb_enabled_command.patch" >> grub.patches
# TODO: add our password from EFI variable patch here once it is ready

# compile
RUN make compile

# create our grub artifacts from build
WORKDIR /src/grub/grub-2.06/grub-${TARGETHOSTARCH}-efi-2.06
# 1. SONiC
# we are adding the following things for the SONiC grub:
# - the is_sb_enabled module which actually comes from ONIE for future scripting
# - its embedded configuration
ADD sonic-embedded-grub.cfg /sonic/
RUN ./grub-mkimage \
    -O ${MKIMAGEARCH}-efi -o /artifacts/sonic-grub${EFIARCH}.efi -d grub-core --sbat ./sbat.csv -m memdisk.squashfs \
    -p /EFI/SONiC-OS --config=/sonic/sonic-embedded-grub.cfg \
    is_sb_enabled version \
    all_video boot blscfg btrfs cat configfile cryptodisk echo ext2 f2fs fat font gcry_rijndael gcry_rsa gcry_serpent gcry_sha256 gcry_twofish gcry_whirlpool \
    gfxmenu gfxterm gzio halt hfsplus http increment iso9660 jpeg loadenv loopback linux lvm luks luks2 memdisk mdraid09 mdraid1x minicmd net normal \
    part_apple part_msdos part_gpt password_pbkdf2 pgp png reboot regexp search search_fs_uuid search_fs_file search_label serial sleep squash4 syslinuxcfg \
    test tftp version video xfs zstd efi_netfs efifwsetup efinet lsefi lsefimmap connectefi backtrace chain tpm \
    usb usbserial_common usbserial_pl2303 usbserial_ftdi usbserial_usbdebug keylayouts at_keyboard

# with this output we can verify that the NX compatibility flag is indeed set
RUN pedump /artifacts/sonic-grub${EFIARCH}.efi

# with this output we can verify our SBAT section
RUN echo "SBAT section of /artifacts/sonic-grub${EFIARCH}.efi:" && pedump --extract section:.sbat /artifacts/sonic-grub${EFIARCH}.efi

# 2. ONIE
# we are adding the following things for the ONIE grub:
# - its embedded configuration
# - the public PGP keyring for verifying signatures
# - custom selection of grub modules: merged between upstream Fedora and upstream ONIE modules
# TODO: the embedded configuration should have embedded what is in the config files, then there would be no need for signatures, and the contents must not change anyways
ADD onie-embedded-grub.cfg onie-recovery-embedded-grub.cfg app-pgp-sb-grub-pgp-${GPG_PUBKEY}-1.key /onie/

# this is for the main ONIE build
RUN ./grub-mkimage \
    -O ${MKIMAGEARCH}-efi -o /artifacts/onie-grub${EFIARCH}.efi -d grub-core --sbat ./sbat.csv -m memdisk.squashfs \
    -p /bogus --pubkey /onie/app-pgp-sb-grub-pgp-${GPG_PUBKEY}-1.key --config=/onie/onie-embedded-grub.cfg \
    version \
    archelp bufio crypto efi_gop efi_uga fshelp gcry_dsa gcry_sha1 gcry_sha512 gettext gfxterm_background is_sb_enabled keystatus lsefisystab lssal raid5rec raid6rec terminal terminfo true zfs zfscrypt zfsinfo \
    all_video boot blscfg btrfs cat configfile cryptodisk echo ext2 f2fs fat font gcry_rijndael gcry_rsa gcry_serpent gcry_sha256 gcry_twofish gcry_whirlpool \
    gfxmenu gfxterm gzio halt hfsplus http increment iso9660 jpeg loadenv loopback linux lvm luks luks2 memdisk mdraid09 mdraid1x minicmd net normal \
    part_apple part_msdos part_gpt password_pbkdf2 pgp png reboot regexp search search_fs_uuid search_fs_file search_label serial sleep squash4 syslinuxcfg \
    test tftp version video xfs zstd efi_netfs efifwsetup efinet lsefi lsefimmap connectefi backtrace chain tpm \
    usb usbserial_common usbserial_pl2303 usbserial_ftdi usbserial_usbdebug keylayouts at_keyboard

# this is for the ONIE recovery/installation ISO image
RUN ./grub-mkimage \
    -O ${MKIMAGEARCH}-efi -o /artifacts/onie-recovery-grub${EFIARCH}.efi -d grub-core --sbat ./sbat.csv -m memdisk.squashfs \
    -p /boot/grub --pubkey /onie/app-pgp-sb-grub-pgp-${GPG_PUBKEY}-1.key --config=/onie/onie-recovery-embedded-grub.cfg \
    version \
    archelp bufio crypto efi_gop efi_uga fshelp gcry_dsa gcry_sha1 gcry_sha512 gettext gfxterm_background is_sb_enabled keystatus lsefisystab lssal raid5rec raid6rec terminal terminfo true zfs zfscrypt zfsinfo \
    all_video boot blscfg btrfs cat configfile cryptodisk echo ext2 f2fs fat font gcry_rijndael gcry_rsa gcry_serpent gcry_sha256 gcry_twofish gcry_whirlpool \
    gfxmenu gfxterm gzio halt hfsplus http increment iso9660 jpeg loadenv loopback linux lvm luks luks2 memdisk mdraid09 mdraid1x minicmd net normal \
    part_apple part_msdos part_gpt password_pbkdf2 pgp png reboot regexp search search_fs_uuid search_fs_file search_label serial sleep squash4 syslinuxcfg \
    test tftp version video xfs zstd efi_netfs efifwsetup efinet lsefi lsefimmap connectefi backtrace chain tpm \
    usb usbserial_common usbserial_pl2303 usbserial_ftdi usbserial_usbdebug keylayouts at_keyboard

# with this output we can verify that the NX compatibility flag is indeed set
RUN pedump /artifacts/onie-grub${EFIARCH}.efi
RUN pedump /artifacts/onie-recovery-grub${EFIARCH}.efi

# with this output we can verify our SBAT section
RUN echo "SBAT section of /artifacts/onie-grub${EFIARCH}.efi:" && pedump --extract section:.sbat /artifacts/onie-grub${EFIARCH}.efi
RUN echo "SBAT section of /artifacts/onie-recovery-grub${EFIARCH}.efi:" && pedump --extract section:.sbat /artifacts/onie-recovery-grub${EFIARCH}.efi
