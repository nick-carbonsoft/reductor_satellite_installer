#!/bin/bash

. /opt/reductor_satellite/etc/const

BK=/root/backup.tar.gz

$BINDIR/export.sh $BK
umount /opt/reductor_satellite/reductor_container/proc || true
umount /opt/reductor_satellite/reductor_container/dev  || true
cd /opt/reductor_satellite_installer/
git pull origin master
./install.sh
$BINDIR/import.sh $BK
