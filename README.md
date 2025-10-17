# VM-Archive
VMのアーカイブに使用しているスクリプト．
Lilyのc0a21023-archivej内にあります．

## jasmin_archive.sh
jasmin_vm_off_count.csvのESXi上のVMごとにOFF状態のカウントを確認し，カウントが30以上の場合そのVMを登録解除します．


## jasmin_vm_track.sh
ESXi上のVMがON状態かOFF状態かを確認し，jasmin_vm_off_count.csvに記録します．
ESXi上のVMごとにOFF状態のカウントを行います
OFF状態の場合，CSV内のカウントを＋1します．ON状態の場合カウントをリセットします．
