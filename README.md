# VM-Archive

VMのアーカイブに使用しているスクリプト．  
Lilyのc0a21023-archivej内にあります．

## 概要

ESXi上の仮想マシンの電源状態を追跡し、長期間停止しているVMを自動的にアーカイブするシステムです．

## ファイル構成

### jasmine_vm_track.sh

ESXi上のVMがON状態かOFF状態かを確認し、jasmine_vm_off_count.csvに記録します．  
ESXi上のVMごとにOFF状態のカウントを行います．  
OFF状態の場合、CSV内のカウントを＋1します．ON状態の場合カウントをリセットします．

**詳細機能：**
- SSH経由でESXi（jasmine）に接続し、全VMの電源状態を取得
- 各VMの連続OFF日数をCSVファイルに記録
- ESXiがOFF状態の場合は、全VMのカウントを+1
- Powered offの場合：カウントを+1
- Powered onの場合：カウントを0にリセット
- 連続31回以上OFFのVMをコンソールに表示

**出力ファイル：**
- CSV: `/home/c0a22069/archive/jasmine/jasmine_vm_off_count.csv`
- ログ: `/var/log/ESXi-archive-logs/jasmine-log/daily-log/日時.log`

### jasmine_archive.sh

jasmine_vm_off_count.csvのESXi上のVMごとにOFF状態のカウントを確認し、カウントが30以上の場合そのVMを登録解除します．

**詳細機能：**
- CSVファイルからOFFカウントが30以上のVMを抽出
- 対象VMのファイルを全てバックアップ
  - `.vmdk`ファイル：`vmkfstools -i`でクローン
  - その他のファイル：`cp`でコピー
- VMの登録解除（`vim-cmd vmsvc/unregister`）
- アーカイブ処理をログに記録

**バックアップ先：**
- `/vmfs/volumes/StoreNAS-Public/VM-archive/VM名_日時/`

**ログファイル：**
- `/var/log/ESXi-archive-logs/jasmine-log/archive-vm.log`

## CSVファイル形式

`jasmine_vm_off_count.csv`の形式：

```csv
VMID,Name,ConsecutiveOffCount
123,vm-name-01,5
456,vm-name-02,31
```

- **VMID**: ESXi上のVM ID
- **Name**: VM名
- **ConsecutiveOffCount**: 連続OFF日数

## 使用方法

### 日次監視（推奨：cron等で自動実行）

```bash
./jasmine_vm_track.sh
```

### アーカイブ実行

```bash
./jasmine_archive.sh
```

**注意：** アーカイブ実行後、VMは登録解除されますが、元のディレクトリは削除されません（スクリプト内の該当行がコメントアウトされています）．
