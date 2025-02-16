#!/bin/bash

# ディレクトリのパスを引数として受け取る
directory="$1"

# ディレクトリ内のすべてのファイルのパスをアルファベット順に取得
files=$(find "$directory" -type f | sort)

# ファイルのパスを改行区切りでバイナリデータに結合してハッシュ値を計算
combined_data=$(cat $files | md5sum)

# ハッシュ値のみを出力
echo "$combined_data" | cut -d ' ' -f 1
