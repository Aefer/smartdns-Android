#!/system/bin/sh
MODDIR=${0%/*}
source $MODDIR/constant.sh

mkdir -p "$CORE_DIR"
mkdir -p "$DATA_DIR"

mount -o bind "$CORE_INTERNAL_DIR" "$CORE_DIR"
mount -o bind "$DATA_INTERNAL_DIR" "$DATA_DIR"

LOG_PATH="/data/local/tmp/boot.log"
[ -f $LOG_PATH ] && rm $LOG_PATH
exec 1>>$LOG_PATH 2>&1
set -x

/system/bin/sh $MODDIR/system/xbin/smartdns -start
sleep 5
cat /data/local/tmp/smartdns.log

exit 0
