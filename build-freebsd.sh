#!/bin/sh

set -e

cd /vagrant

cat <<END > /etc/src.conf
WITHOUT_ACCT=YES
WITHOUT_ASAN=YES
WITHOUT_AT=YES
WITHOUT_AUTHPF=YES
WITHOUT_BHYVE=YES
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
WITHOUT_IPFILTER=YES
WITHOUT_IPFW=YES
WITHOUT_IPSEC_SUPPORT=YES
WITHOUT_ISCI=YES
WITHOUT_KERNEL_SYMBOLS=YES
WITHOUT_LDNS=YES
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
WITHOUT_RBOOTD=YES
WITHOUT_ROUTED=YES
WITHOUT_SENDMAIL=YES
WITHOUT_SERVICESDB=YES
WITHOUT_SHAREDOCS=YES
WITHOUT_STATS=YES
WITHOUT_SYSTEM_COMPILER=YES
WITHOUT_TALK=YES
WITHOUT_TESTS=YES
WITHOUT_TFTP=YES
WITHOUT_WIRELESS=YES
WITHOUT_WPA_SUPPLICANT_EAPOL=YES
WITHOUT_ZFS=YES
END

cat <<'END' > /usr/src/release/Makefile.firecracker
#
# Makefile for creating FreeBSD/Firecracker artifacts
#

CLEANDIRS+=	${TARGET}/firecracker-kern ${TARGET}/firecracker-world

# Bits related to hardware which won't exist in a VM.
WITHOUT_VM_ENOENT=WITHOUT_APM=YES WITHOUT_BLUETOOTH=YES WITHOUT_CXGBETOOL=YES \
    WITHOUT_FLOPPY=YES WITHOUT_GPIO=YES WITHOUT_MLX5TOOL=YES WITHOUT_USB=YES \
    WITHOUT_USB_GADGET_EXAMPLES=YES WITHOUT_VT=YES WITHOUT_WIRELESS=YES
# Bits related to software which doesn't exist in Firecracker specifically.
WITHOUT_FC_ENOENT=WITHOUT_ACPI=YES WITHOUT_BOOT=YES WITHOUT_BHYVE=YES \
    WITHOUT_EFI=YES WITHOUT_FDT=YES WITHOUT_HYPERV=YES \
    WITHOUT_LEGACY_CONSOLE=YES WITHOUT_SYSCONS=YES
# Bits which take up a lot of space and probably won't be wanted inside a
# Firecracker VM.
WITHOUT_FC_FEATURES=WITHOUT_DEBUG_FILES=YES WITHOUT_INCLUDES=YES \
		WITHOUT_INSTALLLIB=YES WITHOUT_TESTS=YES WITHOUT_TOOLCHAIN=YES \
		WITHOUT_ACCT=YES WITHOUT_ASAN=YES WITHOUT_AT=YES WITHOUT_AUTHPF=YES \
		WITHOUT_BSNMP=YES WITHOUT_CALENDAR=YES WITHOUT_CDDL=YES WITHOUT_CPP=YES \
		WITHOUT_CLANG=YES WITHOUT_CLANG_EXTRAS=YES \
		WITHOUT_CROSS_COMPILER=YES WITHOUT_DEBUG_FILES=YES WITHOUT_DIALOG=YES \
		WITHOUT_DICT=YES WITHOUT_DMAGENT=YES WITHOUT_DTRACE=YES WITHOUT_EE=YES \
		WITHOUT_EXAMPLES=YES WITHOUT_FINGER=YES WITHOUT_FLOPPY=YES \
		WITHOUT_FORTH=YES WITHOUT_FREEBSD_UPDATE=YES WITHOUT_FTP=YES \
		WITHOUT_GAMES=YES WITHOUT_GOOGLETEST=YES WITHOUT_HAST=YES \
		WITHOUT_HTML=YES WITHOUT_HYPERV=YES WITHOUT_ICONV=YES \
		WITHOUT_IPFILTER=YES WITHOUT_IPFW=YES WITHOUT_IPSEC_SUPPORT=YES \
		WITHOUT_ISCI=YES WITHOUT_KERNEL_SYMBOLS=YES \
		WITHOUT_LDNS=YES WITHOUT_LLDB=YES WITHOUT_LLVM_TARGET_ALL=YES \
		WITHOUT_LOCALES=YES WITHOUT_LOCATE=YES \
		WITHOUT_LRP=YES WITHOUT_LS_COLORS=YES WITHOUT_MAIL=YES \
		WITHOUT_MAILWRAPPER=YES WITHOUT_MAKE=YES WITHOUT_MAN=YES \
		WITHOUT_MANCOMPRESS=YES WITHOUT_MAN_UTILS=YES WITHOUT_MLX5TOOL=YES \
		WITHOUT_NETGRAPH=YES WITHOUT_NETLINK=YES WITHOUT_NLS=YES WITHOUT_NTP=YES \
		WITHOUT_OFED=YES WITHOUT_OPENMP=YES WITHOUT_PF=YES WITHOUT_PMC=YES \
		WITHOUT_PPP=YES WITHOUT_QUOTAS=YES WITHOUT_RADIUS_SUPPORT=YES \
		WITHOUT_RBOOTD=YES WITHOUT_ROUTED=YES WITHOUT_SENDMAIL=YES \
		WITHOUT_SERVICESDB=YES WITHOUT_SHAREDOCS=YES WITHOUT_STATS=YES \
		WITHOUT_SYSTEM_COMPILER=YES WITHOUT_TALK=YES WITHOUT_TESTS=YES \
		WITHOUT_TFTP=YES WITHOUT_WIRELESS=YES WITHOUT_WPA_SUPPLICANT_EAPOL=YES \
		WITHOUT_ZFS=YES
# All the excluded bits
WITHOUTS?=${WITHOUT_VM_ENOENT} ${WITHOUT_FC_ENOENT} ${WITHOUT_FC_FEATURES}

firecracker:	firecracker-freebsd-kern.bin firecracker-freebsd-rootfs.bin

FCKDIR=	${.OBJDIR}/${TARGET}/firecracker-kern
firecracker-freebsd-kern.bin:
.if !defined(DESTDIR) || !exists(${DESTDIR})
	@echo "--------------------------------------------------------------"
	@echo ">>> DESTDIR must point to destination for Firecracker binaries"
	@echo "--------------------------------------------------------------"
	@false
.endif
	mkdir -p ${FCKDIR}
	${MAKE} -C ${WORLDDIR} DESTDIR=${FCKDIR} \
	    KERNCONF=FIRECRACKER TARGET=${TARGET} installkernel
	cp ${FCKDIR}/boot/kernel/kernel ${DESTDIR}/freebsd-kern.bin

FCWDIR=	${.OBJDIR}/${TARGET}/firecracker-world
FCROOTFSSZ?=	1g
firecracker-freebsd-rootfs.bin:
	mkdir -p ${FCWDIR}
	${MAKE} -C ${WORLDDIR} DESTDIR=${FCWDIR} \
	    ${WITHOUTS} TARGET=${TARGET} installworld distribution distrib-dirs
	echo '/dev/ufs/rootfs / ufs rw 1 1' > ${FCWDIR}/etc/fstab
	echo 'hostname="freebsd"' >> ${FCWDIR}/etc/rc.conf
	echo 'ifconfig_vtnet0="inet 172.16.0.2 netmask 255.255.255.0 mtu 16384"' >> ${FCWDIR}/etc/rc.conf
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

# Without this, we end up at the mountroot prompt when booting the VM
cat <<END >> /usr/src/sys/amd64/conf/FIRECRACKER
options ROOTDEVNAME=\"ufs:/dev/vtbd0\"
END

make -j$(sysctl -n hw.ncpu) -C /usr/src buildworld buildkernel KERNCONF=FIRECRACKER
make -C /usr/src/release firecracker DESTDIR=$(pwd)

chown -R vagrant:vagrant $(pwd)
