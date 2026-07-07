#!/bin/sh

set -e

# Architecture of the artifacts to produce, using the FreeBSD build system's
# TARGET/TARGET_ARCH conventions. amd64 (the default) builds natively inside
# the amd64 build VM. arm64 can be built either natively (e.g. in an aarch64
# build VM on Apple Silicon) or cross-built from the amd64 build VM in CI --
# the base system's clang is a cross-compiler, so no extra toolchain is needed.
TARGET="${TARGET:-amd64}"
if [ "$TARGET" = "arm64" ]; then
	TARGET_ARCH="${TARGET_ARCH:-aarch64}"
else
	TARGET_ARCH="${TARGET_ARCH:-$TARGET}"
fi

# Firecracker's aarch64 loader only accepts Linux arm64 "Image"-format kernels
# (PVH/ELF boot is x86-only), so the arm64 build also produces kernel.bin.
if [ "$TARGET" = "arm64" ]; then
	KERNEL_BIN_FLAGS="WITH_KERNEL_BIN=yes"
else
	KERNEL_BIN_FLAGS=""
fi

cd /work

cat <<END > /etc/src.conf
WITHOUT_ACCT=YES
WITHOUT_ASAN=YES
WITHOUT_AT=YES
WITHOUT_AUTHPF=YES
WITHOUT_BHYVE=YES
WITHOUT_BOOT=YES
WITHOUT_BSNMP=YES
WITHOUT_CALENDAR=YES
WITHOUT_CDDL=YES
WITHOUT_LLVM_TARGET_ALL=YES
WITHOUT_CLANG=YES
WITHOUT_CLANG_EXTRAS=YES
WITHOUT_CPP=YES
WITHOUT_CROSS_COMPILER=YES
WITHOUT_DEBUG_FILES=YES
WITHOUT_DIALOG=YES
WITHOUT_DICT=YES
WITHOUT_DMAGENT=YES
WITHOUT_DTRACE=YES
WITHOUT_EE=YES
WITHOUT_EXAMPLES=YES
WITHOUT_FINGER=YES
WITHOUT_FLOPPY=YES
WITHOUT_FORTH=YES
WITHOUT_FREEBSD_UPDATE=YES
WITHOUT_FTP=YES
WITHOUT_GAMES=YES
WITHOUT_GOOGLETEST=YES
WITHOUT_HAST=YES
WITHOUT_HTML=YES
WITHOUT_HYPERV=YES
WITHOUT_ICONV=YES
WITHOUT_INCLUDES=YES
WITHOUT_IPFILTER=YES
WITHOUT_IPFW=YES
WITHOUT_IPSEC_SUPPORT=YES
WITHOUT_ISCI=YES
WITHOUT_KERBEROS=YES
WITHOUT_KERNEL_SYMBOLS=YES
WITHOUT_LDNS=YES
WITHOUT_LIB32=YES
WITHOUT_LLDB=YES
WITHOUT_LOCALES=YES
WITHOUT_LOCATE=YES
WITHOUT_LRP=YES
WITHOUT_LS_COLORS=YES
WITHOUT_MAIL=YES
WITHOUT_MAILWRAPPER=YES
WITHOUT_MAKE=YES
WITHOUT_MAN=YES
WITHOUT_MANCOMPRESS=YES
WITHOUT_MAN_UTILS=YES
WITHOUT_MLX5TOOL=YES
WITHOUT_NETGRAPH=YES
WITHOUT_NETLINK=YES
WITHOUT_NLS=YES
WITHOUT_NTP=YES
WITHOUT_OFED=YES
WITHOUT_OPENMP=YES
WITHOUT_PF=YES
WITHOUT_PMC=YES
WITHOUT_PPP=YES
WITHOUT_QUOTAS=YES
WITHOUT_RADIUS_SUPPORT=YES
WITHOUT_RESCUE=YES
WITHOUT_RBOOTD=YES
WITHOUT_ROUTED=YES
WITHOUT_SENDMAIL=YES
WITHOUT_SERVICESDB=YES
WITHOUT_SHAREDOCS=YES
WITHOUT_STATS=YES
WITHOUT_TALK=YES
WITHOUT_TESTS=YES
WITHOUT_TOOLCHAIN=YES
WITHOUT_TFTP=YES
WITHOUT_WIRELESS=YES
WITHOUT_WPA_SUPPLICANT_EAPOL=YES
WITHOUT_ZFS=YES
END

cat <<'END' > /work/src/release/Makefile.firecracker
#
# Makefile for creating FreeBSD/Firecracker artifacts
#

CLEANDIRS+=	${TARGET}/firecracker-kern ${TARGET}/firecracker-world

firecracker:	firecracker-freebsd-kern.bin firecracker-freebsd-rootfs.bin

FCKDIR=	${.OBJDIR}/${TARGET}/firecracker-kern
.if ${TARGET} == "arm64"
# Firecracker on aarch64 loads Linux arm64 "Image"-format kernels, not ELF.
# WITH_KERNEL_BIN makes the kernel build emit kernel.bin: the ELF kernel
# converted with objcopy and prepended with a booti-compatible Image header.
FCKERNBIN=	kernel.bin
FCKERNFLAGS=	WITH_KERNEL_BIN=yes
.else
FCKERNBIN=	kernel
FCKERNFLAGS=
.endif
firecracker-freebsd-kern.bin:
.if !defined(DESTDIR) || !exists(${DESTDIR})
	@echo "--------------------------------------------------------------"
	@echo ">>> DESTDIR must point to destination for Firecracker binaries"
	@echo "--------------------------------------------------------------"
	@false
.endif
	mkdir -p ${FCKDIR}
	${MAKE} -C ${WORLDDIR} DESTDIR=${FCKDIR} \
	    KERNCONF=FIRECRACKER TARGET=${TARGET} TARGET_ARCH=${TARGET_ARCH:U${TARGET}} \
	    ${FCKERNFLAGS} installkernel
	cp ${FCKDIR}/boot/kernel/${FCKERNBIN} ${DESTDIR}/freebsd-kern.bin

FCWDIR=	${.OBJDIR}/${TARGET}/firecracker-world
FCROOTFSSZ?=	1g
FREEBSD_VERSION?=	15.0-RELEASE
FREEBSD_DIST_URL?=	https://download.freebsd.org/releases/${TARGET}/${TARGET_ARCH:U${TARGET}}/${FREEBSD_VERSION}
firecracker-freebsd-rootfs.bin:
	mkdir -p ${FCWDIR}
	fetch -o - ${FREEBSD_DIST_URL}/base.txz | tar -C ${FCWDIR} -xpf -
	# base.txz is the full userland and is larger than the old trimmed
	# installworld. Drop bits that aren't useful inside a Firecracker CI VM to
	# keep the image small for the action's download/boot/growfs.
	rm -rf ${FCWDIR}/usr/tests ${FCWDIR}/usr/share/doc \
	    ${FCWDIR}/usr/share/examples ${FCWDIR}/usr/share/man \
	    ${FCWDIR}/usr/share/openssl/man ${FCWDIR}/usr/share/locale \
	    ${FCWDIR}/usr/share/nls ${FCWDIR}/usr/share/dict \
	    ${FCWDIR}/usr/lib/debug
	rm -rf ${FCWDIR}/rescue \
	    ${FCWDIR}/usr/include \
	    ${FCWDIR}/usr/lib/clang \
	    ${FCWDIR}/usr/lib/*.a \
	    ${FCWDIR}/usr/bin/cc ${FCWDIR}/usr/bin/c++ ${FCWDIR}/usr/bin/cpp \
	    ${FCWDIR}/usr/bin/clang* ${FCWDIR}/usr/bin/lldb* \
	    ${FCWDIR}/usr/bin/ld ${FCWDIR}/usr/bin/ld.bfd ${FCWDIR}/usr/bin/ld.lld \
	    ${FCWDIR}/usr/bin/lld ${FCWDIR}/usr/bin/llvm-*
	# Drop subsystems the CI guest never uses. None are enabled in the default
	# rc.conf; ZFS and DTrace additionally need kernel support the FIRECRACKER
	# kernel doesn't build (MODULES_OVERRIDE=""), so their userland is inert.
	# ZFS userland
	rm -rf ${FCWDIR}/sbin/zfs ${FCWDIR}/sbin/zpool \
	    ${FCWDIR}/usr/sbin/zdb ${FCWDIR}/usr/sbin/zfsd \
	    ${FCWDIR}/lib/libzpool.so* \
	    ${FCWDIR}/etc/rc.d/zfs ${FCWDIR}/etc/rc.d/zfsd \
	    ${FCWDIR}/etc/rc.d/zvol ${FCWDIR}/etc/rc.d/zpool \
	    ${FCWDIR}/etc/rc.d/zfsbe ${FCWDIR}/etc/rc.d/zfskeys
	# DTrace
	rm -rf ${FCWDIR}/usr/sbin/dtrace ${FCWDIR}/usr/sbin/lockstat \
	    ${FCWDIR}/usr/sbin/plockstat ${FCWDIR}/usr/sbin/dwatch \
	    ${FCWDIR}/usr/lib/dtrace ${FCWDIR}/lib/libdtrace.so* \
	    ${FCWDIR}/etc/rc.d/dtrace
	# sendmail MTA
	rm -rf ${FCWDIR}/usr/libexec/sendmail ${FCWDIR}/usr/share/sendmail \
	    ${FCWDIR}/etc/rc.d/sendmail
	# ntpd, ppp, bsnmpd
	rm -rf ${FCWDIR}/usr/sbin/ntpd ${FCWDIR}/usr/sbin/ntpdc \
	    ${FCWDIR}/usr/sbin/ntp-keygen ${FCWDIR}/usr/bin/ntpq \
	    ${FCWDIR}/usr/bin/ntptime ${FCWDIR}/etc/rc.d/ntpd \
	    ${FCWDIR}/etc/rc.d/ntpdate \
	    ${FCWDIR}/usr/sbin/ppp ${FCWDIR}/usr/sbin/pppctl \
	    ${FCWDIR}/usr/sbin/pppoed ${FCWDIR}/etc/rc.d/ppp \
	    ${FCWDIR}/usr/sbin/bsnmpd ${FCWDIR}/usr/lib/snmp_*.so* \
	    ${FCWDIR}/usr/bin/bsnmpget ${FCWDIR}/usr/bin/bsnmpwalk \
	    ${FCWDIR}/etc/rc.d/bsnmpd
	rm -rf ${FCWDIR}/usr/sbin/bhyve ${FCWDIR}/usr/sbin/bhyvectl \
	    ${FCWDIR}/usr/sbin/bhyveload ${FCWDIR}/usr/lib/libvmmapi.so*
	# Firewalls: pf, ipfw, ipfilter (WITHOUT_PF, WITHOUT_IPFW, WITHOUT_IPFILTER)
	rm -rf ${FCWDIR}/sbin/pfctl ${FCWDIR}/sbin/pflogd ${FCWDIR}/usr/sbin/ftp-proxy \
	    ${FCWDIR}/usr/sbin/authpf* ${FCWDIR}/etc/rc.d/pf ${FCWDIR}/etc/rc.d/pflog \
	    ${FCWDIR}/sbin/ipfw ${FCWDIR}/sbin/natd ${FCWDIR}/etc/rc.d/ipfw \
	    ${FCWDIR}/etc/rc.d/natd \
	    ${FCWDIR}/sbin/ipf ${FCWDIR}/sbin/ipfstat ${FCWDIR}/sbin/ipmon \
	    ${FCWDIR}/sbin/ipnat ${FCWDIR}/sbin/ippool ${FCWDIR}/etc/rc.d/ipfilter \
	    ${FCWDIR}/etc/rc.d/ipnat ${FCWDIR}/etc/rc.d/ipmon
	# netgraph (WITHOUT_NETGRAPH)
	rm -rf ${FCWDIR}/usr/sbin/ngctl ${FCWDIR}/usr/sbin/nghook \
	    ${FCWDIR}/usr/lib/libnetgraph.so* ${FCWDIR}/etc/rc.d/netgraph
	# mail reader, mailwrapper, dma (WITHOUT_MAIL, WITHOUT_MAILWRAPPER, WITHOUT_DMAGENT)
	rm -rf ${FCWDIR}/usr/bin/mail ${FCWDIR}/usr/bin/Mail ${FCWDIR}/usr/bin/mailx \
	    ${FCWDIR}/usr/sbin/mailwrapper ${FCWDIR}/etc/mail/mailer.conf \
	    ${FCWDIR}/usr/libexec/dma ${FCWDIR}/usr/libexec/dma-mbox-create \
	    ${FCWDIR}/etc/dma ${FCWDIR}/etc/rc.d/dma
	# freebsd-update, ftp client, ldns tools (WITHOUT_FREEBSD_UPDATE, WITHOUT_FTP, WITHOUT_LDNS)
	rm -rf ${FCWDIR}/usr/sbin/freebsd-update ${FCWDIR}/etc/freebsd-update.conf \
	    ${FCWDIR}/usr/bin/ftp ${FCWDIR}/usr/bin/drill ${FCWDIR}/usr/bin/host
	# Boot loader: Firecracker loads the kernel directly, so /boot's loader
	# binaries are never used (WITHOUT_BOOT, WITHOUT_FORTH). Keep /boot itself
	# and the saved entropy that rc.d/random consumes.
	rm -rf ${FCWDIR}/boot/loader ${FCWDIR}/boot/loader_* ${FCWDIR}/boot/*.efi \
	    ${FCWDIR}/boot/lua ${FCWDIR}/boot/defaults ${FCWDIR}/boot/forth \
	    ${FCWDIR}/boot/dtb ${FCWDIR}/boot/firmware ${FCWDIR}/boot/zfsloader \
	    ${FCWDIR}/boot/pmbr ${FCWDIR}/boot/*boot ${FCWDIR}/boot/*boot[0-9]* \
	    ${FCWDIR}/boot/userboot*
	echo '/dev/ufs/rootfs / ufs rw 1 1' > ${FCWDIR}/etc/fstab
	echo 'hostname="freebsd"' >> ${FCWDIR}/etc/rc.conf
	echo 'ifconfig_vtnet0="inet 172.16.0.2 netmask 255.255.255.0"' >> ${FCWDIR}/etc/rc.conf
	echo 'defaultrouter="172.16.0.1"' >> ${FCWDIR}/etc/rc.conf
	echo 'sshd_enable="YES"' >> ${FCWDIR}/etc/rc.conf
	echo 'sshd_rsa_enable="NO"' >> ${FCWDIR}/etc/rc.conf
	echo 'growfs_enable="YES"' >> ${FCWDIR}/etc/rc.conf
	echo 'nameserver 8.8.8.8' >> ${FCWDIR}/etc/resolv.conf
	sed -i '' -e '/periodic/s/^/#/' ${FCWDIR}/etc/crontab
	pw -R ${FCWDIR} groupadd freebsd -g 1001
	mkdir -p ${FCWDIR}/home/freebsd
	pw -R ${FCWDIR} useradd freebsd -m -M 0755 -w yes -n freebsd \
	    -u 1001 -g 1001 -G 0 -c "FreeBSD User" -d /home/freebsd -s /bin/sh
	pw -R ${FCWDIR} usermod root -w yes
	touch ${FCWDIR}/firstboot
	makefs -s ${FCROOTFSSZ} -o label=rootfs -o version=2 -o softupdates=1 \
	    ${DESTDIR}/freebsd-rootfs.bin ${FCWDIR}
END

if [ "$TARGET" = "amd64" ]; then
	# Without this, we end up at the mountroot prompt when booting the VM
	cat <<END >> /work/src/sys/amd64/conf/FIRECRACKER
options ROOTDEVNAME=\"ufs:/dev/vtbd0\"
END

	# Skip building kernel modules that we won't use
	cat <<END >> /work/src/sys/amd64/conf/FIRECRACKER
makeoptions MODULES_OVERRIDE=""
END

	# Disable debug options
	cat <<END >> /work/src/sys/amd64/conf/FIRECRACKER
nomakeoptions DEBUG
nomakeoptions WITH_CTF
END
else
	# There is no FIRECRACKER kernel config for arm64 upstream (yet), so we
	# provide one. GENERIC already contains everything Firecracker's aarch64
	# boot protocol needs: LINUX_BOOT_ABI (via std.arm64) accepts the FDT
	# pointer that Firecracker passes in x0, and the virtio-mmio, GICv3,
	# PSCI, and ns16550 UART drivers match the devices in Firecracker's
	# generated device tree.
	cat <<END > /work/src/sys/arm64/conf/FIRECRACKER
include GENERIC
ident	FIRECRACKER

# Firecracker has no boot loader, so tell the kernel where root lives.
# Without this, we end up at the mountroot prompt when booting the VM
options ROOTDEVNAME=\"ufs:/dev/vtbd0\"

# Skip building kernel modules that we won't use
makeoptions MODULES_OVERRIDE=""

# Disable debug options
nomakeoptions DEBUG
nomakeoptions WITH_CTF
END
fi

NCPU=$(($(sysctl -n hw.ncpu) + 2))

# When cross-building (e.g. arm64 artifacts from the amd64 build VM), build
# the bootstrap tools for the target first. The compiler itself comes from
# the base system (WITHOUT_CROSS_COMPILER in src.conf); base clang/lld can
# target all supported architectures.
if [ "$TARGET_ARCH" != "$(uname -p)" ]; then
	make -j$NCPU -C /work/src kernel-toolchain \
	    TARGET="$TARGET" TARGET_ARCH="$TARGET_ARCH"
fi

make -j$NCPU -C /work/src buildkernel KERNCONF=FIRECRACKER \
    TARGET="$TARGET" TARGET_ARCH="$TARGET_ARCH" $KERNEL_BIN_FLAGS

make -C /work/src/release firecracker DESTDIR=$(pwd) \
    FREEBSD_VERSION="${FREEBSD_VERSION}" \
    TARGET="$TARGET" TARGET_ARCH="$TARGET_ARCH"
