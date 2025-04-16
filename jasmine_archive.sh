#!/bin/bash

REMOTE_HOST="jasmine"
CSV_FILE="/home/c0a22069/archive/${REMOTE_HOST}/${REMOTE_HOST}_vm_off_count.csv"
THRESHOLD=30
BACKUP_BASE="/vmfs/volumes/StoreNAS-Public/VM-archive"
CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

mapfile -t vmid_list < <(awk -F, -v t="$THRESHOLD" 'NR>1 && $3 >= t {print $1}' "$CSV_FILE")

# SSH接続し，VM名を取得し変数に代入する
for vmid in "${vmid_list[@]}"; do
  echo "処理対象 VMID: $vmid"

  vm_name=$(ssh "$REMOTE_HOST" /bin/sh <<EOF
vmid=$vmid

vm_info=\$(vim-cmd vmsvc/getallvms | awk -v id=\$vmid '\$1 == id')
if [ -z "\$vm_info" ]; then
  echo "__NOT_FOUND__"
  exit 1
fi

vm_name=\$(echo "\$vm_info" | awk '{print \$2}')
echo "\$vm_name"
EOF
)

  if [ "$vm_name" = "__NOT_FOUND__" ]; then
    echo "VMID $vmid は見つかりませんでした。スキップします。"
    continue
  fi

  # 再度 SSHしてバックアップ・解除を実行
  ssh "$REMOTE_HOST" /bin/sh <<EOF
vmid=$vmid
vm_name="$vm_name"
vm_info=\$(vim-cmd vmsvc/getallvms | awk -v id=\$vmid '\$1 == id')
vm_fullpath=\$(echo "\$vm_info" | cut -d']' -f2 | cut -d' ' -f2)
datastore=\$(echo "\$vm_info" | awk -F'[][]' '{print \$2}')
vm_dir="/vmfs/volumes/\$datastore/\$(dirname "\$vm_fullpath")"
backup_dir="$BACKUP_BASE/\${vm_name}_\$(date +%Y%m%d_%H%M%S)"

mkdir -p "\$backup_dir"
echo "バックアップ: \$vm_dir → \$backup_dir"

for file in "\$vm_dir"/*; do
  basefile=\$(basename "\$file")
  if echo "\$basefile" | grep -q "\.vmdk\$"; then
    vmkfstools -i "\$file" "\$backup_dir/\$basefile"
  else
    cp "\$file" "\$backup_dir/"
  fi
done

echo "登録解除: \$vm_name"
vim-cmd vmsvc/unregister "\$vmid"

# VM削除（必要な場合のみ有効にする）
# echo "ディレクトリ削除: \$vm_dir"
# rm -rf "\$vm_dir"
EOF

# ログ記録
echo "[$CURRENT_DATE] ${vm_name}をアーカイブしました" >> /var/log/ESXi-archive-logs/$REMOTE_HOST-log/archive-vm.log

done
