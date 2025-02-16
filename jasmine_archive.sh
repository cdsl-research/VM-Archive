#!/bin/bash

#ハッシュ値を出力できるようにしたシェルで

# 仮想環境のパス
VENV_PATH="/home/ishikawa/archive/.venv"

# ESXiホストのIPアドレスとユーザー
ESXI_USER="archive"
ESXI_HOST="jasmine"

# スプレッドシートからVM名を読み取るCSVファイル
CSV_FILE="/home/ishikawa/archive/jasmine/jasmine_vms.csv" #jasmineの部分を各ESXiに変更する
COPY_DEST="/vmfs/volumes/StoreNAS-Public/VM-archive"
VM_SOURCE_DIR="/vmfs/volumes/StoreNAS-Jasmine2" #jasmineの部分を各ESXiに変更する

# ハッシュ値を計算するシェルスクリプトのパス
VM_HASH_SCRIPT="/home/ishikawa/archive/jasmine/hash.sh" #jasmineの部分を各ESXiに変更する

# エラーフラグ
ERROR_OCCURRED=0

# CSVファイルの存在確認
if [[ ! -f "$CSV_FILE" ]]; then
  echo "CSVファイルが見つかりません: $CSV_FILE"
  exit 1
fi

# CSVファイルからVM名を読み取る
VM_NAMES=$(cat "$CSV_FILE")

# 各VMを処理
for VM_NAME in $VM_NAMES; do
  echo "Processing VM: $VM_NAME"

  # リモートでVMの状態をチェック
  VM_ID=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "vim-cmd vmsvc/getallvms | grep -w '$VM_NAME' | awk '{print \$1}'")
  if [[ -z "$VM_ID" ]]; then
    echo "VMが見つかりません: $VM_NAME"
    continue
  fi

  POWER_STATE=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "vim-cmd vmsvc/power.getstate $VM_ID | tail -1")
  if [[ "$POWER_STATE" == "Powered on" ]]; then
    echo "VM is powered on, powering off: $VM_NAME"
    ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "vim-cmd vmsvc/power.off $VM_ID"
    if [[ $? -ne 0 ]]; then
      echo "VMの電源をオフにできませんでした: $VM_NAME"
      continue
    fi
  fi

  # リモートホストからVMディレクトリをコピー先にコピー
  VM_DIR="$VM_SOURCE_DIR/$VM_NAME"
  DEST_DIR="$COPY_DEST/$VM_NAME"
  echo "Copying $VM_DIR to $DEST_DIR"
  ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "cp -r $VM_DIR $DEST_DIR"
  if [[ $? -ne 0 ]]; then
    echo "VMディレクトリをコピーできませんでした: $VM_NAME"
    continue
  fi

  echo "正常にコピーされました: $VM_NAME"

  # コピー元VMのハッシュ値を計算
  SOURCE_HASH=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "sh -s" < $VM_HASH_SCRIPT "$VM_DIR")
  if [[ -z "$SOURCE_HASH" ]]; then
    echo "コピー元のハッシュ値を取得できませんでした: $VM_NAME"
    continue
  fi
  echo "コピー元のハッシュ値: $SOURCE_HASH"

  # コピーが完了してからコピー先VMのハッシュ値を計算
  DEST_HASH=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "sh -s" < $VM_HASH_SCRIPT "$DEST_DIR")
  if [[ -z "$DEST_HASH" ]]; then
    echo "コピー先のハッシュ値を取得できませんでした: $VM_NAME"
    continue
  fi
  echo "コピー先のハッシュ値: $DEST_HASH"

  # ハッシュ値の比較
  if [[ "$SOURCE_HASH" == "$DEST_HASH" ]]; then
    echo "ハッシュ値が一致しました。登録解除してからコピー元のVMを削除します。"

    # リモートで登録解除
    echo "登録解除 VM: $VM_NAME"
    ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "vim-cmd vmsvc/unregister $VM_ID"
    if [[ $? -ne 0 ]]; then
      echo "VMの登録解除に失敗しました: $VM_NAME"
      continue
    fi
    echo "VMの登録解除に成功しました: $VM_NAME"

    # コピー元VMを削除する
    echo "コピー元のVMを削除中: $VM_NAME"
    ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "rm -rf $VM_DIR"
    if [[ $? -ne 0 ]]; then
      echo "VMを削除できませんでした: $VM_NAME"
      ERROR_OCCURRED=1
    fi
  else
    echo "ハッシュ値が一致しませんでした: $VM_NAME"
  fi

  # コピー先VMのサイズを計算
  SIZE=$(ssh -o "StrictHostKeyChecking=no" -i "/home/ishikawa/.ssh/esxi-key" $ESXI_USER@$ESXI_HOST "du -sh $DEST_DIR | cut -f1")

  # 現在の日付と時刻を取得
  DATE=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S')

  # 仮想環境をアクティブにしてデータベースを実行
  source "$VENV_PATH/bin/activate"
  python3 /home/ishikawa/archive/jasmine/database.py "$DATE" "$VM_NAME" "$ESXI_HOST" "$DEST_HASH" "user" "$SIZE" #jasmineの部分を各ESXiに変更する

  # データベースへの書き込みが完了したVMをCSVファイルから削除
  sed -i "/^$VM_NAME$/d" "$CSV_FILE"

done

if [[ $ERROR_OCCURRED -eq 0 ]]; then
  echo "全てのVMのコピーが完了しました。"
fi
