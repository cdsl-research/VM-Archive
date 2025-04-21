#!/bin/bash


REMOTE_HOST="jasmine"
CSV_FILE="/home/c0a22069/archive/${REMOTE_HOST}/${REMOTE_HOST}_vm_off_count.csv"
TMP_FILE="vm_tmp_$(date +%s).csv"
LOG_DIR="/var/log/ESXi-archive-logs/${REMOTE_HOST}-log/daily-log"
# LOG_FILE="$LOG_DIR/$(date +%F).csv" 
LOG_FILE="$LOG_DIR/$(date +%F_%H-%M-%S).log"

# リモートでVM情報を取得（VMID,Name,PowerState）
vm_data=$(ssh "$REMOTE_HOST" sh <<'EOF'
for vmid in $(vim-cmd vmsvc/getallvms | awk 'NR>1 {print $1}'); do
  name=$(vim-cmd vmsvc/getallvms | awk -v id=$vmid '$1==id {print $2}')
  power_state=$(vim-cmd vmsvc/power.getstate "$vmid" | tail -n 1)
  echo "$vmid,$name,$power_state"
done
EOF
)

# ESXiがOFF状態の場合
if [ -z "$vm_data" ]; then
  echo "[$(date '+%F %T')] ESXiがOFF状態のため，全VMのカウントを +1 します" >> "$LOG_DIR/fallback.log"

  # 全VMのOFFカウント +1
  {
    echo "VMID,Name,ConsecutiveOffCount"
    tail -n +2 "$CSV_FILE" | while IFS=',' read -r vmid name count; do
      if [[ "$count" =~ ^[0-9]+$ ]]; then
        echo "$vmid,$name,$((count + 1))"
      else
        echo "$vmid,$name,1" 
      fi
    done
  } > "$TMP_FILE"

  mv "$TMP_FILE" "$CSV_FILE"
  cp "$CSV_FILE" "$LOG_FILE"

  exit 0
fi

# CSVがなければ作成
if [ ! -f "$CSV_FILE" ]; then
  echo "VMID,Name,ConsecutiveOffCount" > "$CSV_FILE"
fi

# CSV更新
{
  echo "VMID,Name,ConsecutiveOffCount"

  while IFS=',' read -r vmid name state; do
    current_count=$(awk -F, -v id="$vmid" '$1 == id {print $3}' "$CSV_FILE")
    [ -z "$current_count" ] && current_count=0

    if [ "$state" = "Powered off" ]; then
      count=$((current_count + 1))
    else
      count=0
    fi

    echo "$vmid,$name,$count"
  done <<< "$vm_data"

} > "$TMP_FILE"

mv "$TMP_FILE" "$CSV_FILE"

echo "CSV更新完了：$CSV_FILE"

# ログ記録
cp "$CSV_FILE" "$LOG_FILE"

# 連続31回以上OFFのVMを表示
echo
echo "連続で31回以上OFFのVM一覧："
awk -F, 'NR>1 && $3 >= 30 { print "- " $2 "（" $3 "回 OFF）" }' "$CSV_FILE"
