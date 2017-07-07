#!/bin/bash

TARGET_ARCH=armhf
TARGET_DIST=stretch
DEB_MIRROR=http://http.debian.net/debian/
PACKAGES=firmware-brcm80211,e2fsprogs,vim,u-boot-tools,cpufrequtils,linux-image-armmp

CLEANUP=( )
cleanup() {
  set +e
  if [ ${#CLEANUP[*]} -gt 0 ]; then
    LAST_ELEMENT=$((${#CLEANUP[*]}-1))
    REVERSE_INDEXES=$(seq ${LAST_ELEMENT} -1 0)
    for i in $REVERSE_INDEXES; do
      ${CLEANUP[$i]}
    done
  fi
}
trap cleanup EXIT

export LC_ALL=C LANGUAGE=C LANG=C
export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

cd "$(dirname "$(readlink "$0")")"

help()
{
	echo "Usage: $0 rootdir board"
	exit 1
}

if [ $# -ne 2 ]; then
	help
fi

rootdir="$1"
board="$2"
boarddir="boards/$board"

echo "** Installing stretch into $rootdir, for board $board"

mkdir -p "$rootdir"

# extract common files
tar cf - -C common/root . | tar xf - -C "$rootdir"

# extract board specific files
if [ -d "$boarddir/root" ]; then
	tar cf - -C "$boarddir/root" . | tar xf - -C "$rootdir"
fi

if [ $(dpkg --print-architecture) != $TARGET_ARCH ]; then
	mkdir -p $rootdir/usr/bin/
	cp /usr/bin/qemu-arm-static $rootdir/usr/bin/ # XXX
	CLEANUP+=("rm $rootdir/usr/bin/qemu-arm-static")
fi

debootstrap --components=main,contrib,non-free --arch $TARGET_ARCH $TARGET_DIST $rootdir $DEB_MIRROR

cat <<EOF >$rootdir/etc/apt/sources.list
deb $DEB_MIRROR $TARGET_DIST main contrib non-free
deb $DEB_MIRROR $TARGET_DIST-updates main contrib non-free
deb http://http.debian.net/debian-security/ $TARGET_DIST/updates main contrib non-free
EOF

chroot $rootdir apt-get update
chroot $rootdir apt-get dist-upgrade -f -y
chroot $rootdir apt-get install -f -y ${PACKAGES//,/ }

echo "$board" > $rootdir/etc/hostname

echo 'GOVERNOR="conservative"' > $rootdir/etc/default/cpufrequtils

echo "root:pi" | chroot $rootdir chpasswd

chroot $rootdir systemctl enable systemd-timesyncd
