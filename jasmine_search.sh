#!/bin/bash

# ESXiホストの情報
ESXI_USER="archive"
ESXI_HOST="jasmine" #jasmineの部分を各ESXi名に変更
POWER_STATUS_CSV="/home/ishikawa/archive/jasmine/ps_jasmine.csv" #jasmineの部分を各ESXi名に変更
COPY_LIST_CSV="/home/ishikawa/archive/jasmine/jasmine_vms.csv" #jasmineの部分を各ESXi名に変更
TODAY=$(date +%Y-%m-%d)

# CSVファイルがなければ作成
touch "$POWER_STATUS_CSV"
touch "$COPY_LIST_CSV"

# すべてのVMのリストを取得
VM_LIST=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" "$ESXI_USER@$ESXI_HOST" "vim-cmd vmsvc/getallvms")

# VMリストを配列に格納
mapfile -t VM_ARRAY < <(echo "$VM_LIST" | tail -n +2)

# VM電源状態の確認
echo "Checking VMs..."

for line in "${VM_ARRAY[@]}"; do
    # VMのIDと名前を抽出
    VM_ID=$(echo "$line" | awk '{print $1}')
    VM_NAME=$(echo "$line" | awk '{print $2}')

    # 空行や無効なIDをスキップ
    if [[ -z "$VM_ID" || "$VM_ID" =~ [^0-9] ]]; then
        continue
    fi

    # VMの電源状態を取得
    POWER_STATE=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" "$ESXI_USER@$ESXI_HOST" "vim-cmd vmsvc/power.getstate $VM_ID" | grep -Eo '(Powered on|Powered off)' | tr -d '[:space:]')

    # 電源オフのVMを処理
    if [[ "$POWER_STATE" == "Poweredoff" ]]; then
        # 既にvm_power_status.csvにあるか確認
        if ! grep -q "^$VM_NAME," "$POWER_STATUS_CSV"; then
            # なければ新規に追加
            echo "$VM_NAME,$TODAY" >> "$POWER_STATUS_CSV"
            echo "Added $VM_NAME to $POWER_STATUS_CSV"
        fi
    else
        # 電源オンならvm_power_status.csvから削除
        if grep -q "^$VM_NAME," "$POWER_STATUS_CSV"; then
            sed -i "/^$VM_NAME,/d" "$POWER_STATUS_CSV"
            echo "Removed $VM_NAME from $POWER_STATUS_CSV (powered on)"
        fi
    fi
done

# 1か月経過したVMをチェック
while IFS=, read -r vm_name date; do
    # 日付の差を計算
    diff_days=$(( ( $(date -d "$TODAY" +%s) - $(date -d "$date" +%s) ) / 86400 ))

    if [ "$diff_days" -ge 30 ]; then
        # 1か月経過したらvmcopy_list.csvに追加し、vm_power_status.csvから削除
        echo "$vm_name" >> "$COPY_LIST_CSV"
        sed -i "/^$vm_name,/d" "$POWER_STATUS_CSV"
        echo "Moved $vm_name to $COPY_LIST_CSV after 1 month half of being powered off"
    fi
done < "$POWER_STATUS_CSV"
