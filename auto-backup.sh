#!/bin/bash
# =====================================================
# AUTO BACKUP HARIAN PROXMOX VM
# =====================================================

# Folder tujuan backup
BACKUP_DIR="/var/lib/vz/dump"
LOG_FILE="/root/proxmox-backup.log"
VM_LIST=$(qm list | awk 'NR>1 {print $1}')

echo "=== Backup Harian Proxmox ($(date)) ===" >> $LOG_FILE

for VMID in $VM_LIST; do
  echo "🔹 Membackup VM ID: $VMID" >> $LOG_FILE
  vzdump $VMID --compress zstd --dumpdir $BACKUP_DIR --mode snapshot >> $LOG_FILE 2>&1
done

echo "✅ Backup selesai pada $(date)" >> $LOG_FILE
echo "-----------------------------------------" >> $LOG_FILE