#!/bin/bash

set -euo pipefail


SRC_DIR="$HOME/skriptlinux/praks2/src"
BACKUP_DIR="$HOME/praks2/backup"
LOG_DIR="$HOME/praks2/logs"
LOG_FILE="$LOG_DIR/backup.log"
IGNORE_FILE="$SRC_DIR/.backupignore"
KEEP_COUNT=3


TMP_DIR=$(mktemp -d)
cleanup() {
    rm -rf "$TMP_DIR"
    echo "[ $(date '+%F %T') ] Ajutised failid kustutatud ($TMP_DIR)." >> "$LOG_FILE"
}
trap cleanup EXIT


mkdir -p "$BACKUP_DIR" "$LOG_DIR"

log() {
    local msg="[ $(date '+%F %T') ] $1"
    echo "$msg"
    echo "$msg" >> "$LOG_FILE"
}

log "=== VARUNDAMISE PROTSESS ALUSTATUD ==="


if [ ! -d "$SRC_DIR" ]; then
    log "VIGA: Lähtekataloogi $SRC_DIR ei leitud!"
    exit 1
fi


SRC_SIZE=$(du -sb "$SRC_DIR" | awk '{print $1}')
FREE_SPACE=$(df -B1 "$BACKUP_DIR" | awk 'NR==2{print $4}')

log "Allika suurus: $((SRC_SIZE / 1024)) KB | Vaba ruum: $((FREE_SPACE / 1024)) KB"

if [ "$FREE_SPACE" -le "$SRC_SIZE" ]; then
    log "VIGA: Kettal pole piisavalt vaba ruumi varukoopia tegemiseks!"
    exit 1
fi

# 3. KOMPRESSORI VALIK
COMPRESSOR_CMD=""
EXT=""

if command -v zstd &> /dev/null; then
    COMPRESSOR_CMD="zstd -19 -T0"
    EXT="tar.zst"
    log "Valitud kompressor: zstd (tugev pakkimine)"
elif command -v xz &> /dev/null; then
    COMPRESSOR_CMD="xz"
    EXT="tar.xz"
    log "Valitud kompressor: xz"
else
    COMPRESSOR_CMD="gzip"
    EXT="tar.gz"
    log "Valitud kompressor: gzip"
fi

# 4. VARUKOOPIA NIMI JA IGNOREERIMISE REEGLID
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
ARCHIVE_NAME="src_${TIMESTAMP}.${EXT}"
TARGET_ARCHIVE="$BACKUP_DIR/$ARCHIVE_NAME"

EXTRA_ARGS=()
if [ -f "$IGNORE_FILE" ]; then
    EXTRA_ARGS+=("--exclude-from=$IGNORE_FILE")
    log "Kasutatakse välistusfaili: $IGNORE_FILE"
fi

# 5. ARHIIVI LOOMINE
log "Loon arhiivi: $ARCHIVE_NAME..."
PARENT_DIR=$(dirname "$SRC_DIR")
BASE_NAME=$(basename "$SRC_DIR")

tar -I "$COMPRESSOR_CMD" "${EXTRA_ARGS[@]}" -cf "$TARGET_ARCHIVE" -C "$PARENT_DIR" "$BASE_NAME"

# 6. KONTROLL: Arhiivi terviklikkuse ja sisu kontroll
log "Kontrollin loodud arhiivi loetavust..."
if tar -tf "$TARGET_ARCHIVE" &> /dev/null; then
    log "OK: Arhiiv on korras ja loetav."
else
    log "VIGA: Arhiiv on vigane või kahjustatud!"
    exit 1
fi

# 7. KONTROLLSUMMA (SHA-256) GENERERIMINE JA KONTROLL
log "Arvutan SHA-256 kontrollsumma..."
sha256sum "$TARGET_ARCHIVE" > "$TARGET_ARCHIVE.sha256"

if sha256sum -c "$TARGET_ARCHIVE.sha256" &> /dev/null; then
    log "OK: SHA-256 kontrollsumma klapib."
else
    log "VIGA: SHA-256 kontrollsumma ei klapi!"
    exit 1
fi

# 8. VANADE KOOPATALTE PUHASTUS (Säilitatakse viimased N tükki)
log "Puhastan vanad varukoopiad (alles jäetakse viimased $KEEP_COUNT)..."
ls -1t "$BACKUP_DIR"/src_*."$EXT" 2>/dev/null | tail -n +$((KEEP_COUNT + 1)) | while read -r old_backup; do
    log "Eemaldan vana varukoopia: $old_backup"
    rm -f "$old_backup" "$old_backup.sha256"
done

# 9. LÕPP-KOKKUVÕTE
ARCHIVE_SIZE=$(du -h "$TARGET_ARCHIVE" | awk '{print $1}')
log "Varukoopia edukalt loodud! Faili suurus: $ARCHIVE_SIZE"
log "=== VARUNDAMISE PROTSESS LÕPETATUD ==="

exit 0
