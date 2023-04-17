# only Debian 12 builds the latest versions of their grub
FROM fedora:37

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
# TODO: add the is_sb_enabled patch for ONIE
# TODO: add our password from EFI variable patch here once it is ready

# compile
RUN make compile

# create our make artifacts
WORKDIR /src/grub/grub-2.06/grub-x86_64-efi-2.06
# 2. ONIE
# TODO: the embedded configuration should have embedded what is in the config files, then there would be no need for signatures, and the contents must not change anyways
ADD onie-embedded-grub.cfg ONIE-pubring.kbx /onie/
RUN ./grub-mkimage \
    -O x86_64-efi -o /artifacts/onie-grubx64.efi -d grub-core --sbat ./sbat.csv -m memdisk.squashfs \
    -p /bogus --pubkey /onie/ONIE-pubring.kbx --config=/onie/onie-embedded-grub.cfg \
    archelp bufio crypto efi_gop efi_uga fshelp gcry_dsa gcry_sha1 gcry_sha512 gettext gfxterm_background is_sb_enabled keystatus lsefisystab lssal raid5rec raid6rec terminal terminfo true zfs zfscrypt zfsinfo \
    all_video boot blscfg btrfs cat configfile cryptodisk echo ext2 f2fs fat font gcry_rijndael gcry_rsa gcry_serpent gcry_sha256 gcry_twofish gcry_whirlpool \
    gfxmenu gfxterm gzio halt hfsplus http increment iso9660 jpeg loadenv loopback linux lvm luks luks2 memdisk mdraid09 mdraid1x minicmd net normal \
    part_apple part_msdos part_gpt password_pbkdf2 pgp png reboot regexp search search_fs_uuid search_fs_file search_label serial sleep squash4 syslinuxcfg \
    test tftp version video xfs zstd efi_netfs efifwsetup efinet lsefi lsefimmap connectefi backtrace chain tpm \
    usb usbserial_common usbserial_pl2303 usbserial_ftdi usbserial_usbdebug keylayouts at_keyboard
