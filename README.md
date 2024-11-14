```bash
# cloudinitの実行ログチェック(トラブルシュート用)
# だいたいのスクリプトは kube-cp1で動いてます
## check cloud-init 
ssh kube-cp1 "sudo cloud-init query userdata"
ssh kube-cp1 "sudo cloud-init schema --system --annotate"

## check /var/log/cloud-init-output.log
ssh kube-cp1 "sudo cat /var/log/cloud-init-output.log"
ssh kube-wk1 "sudo cat /var/log/cloud-init-output.log"
ssh kube-wk2 "sudo cat /var/log/cloud-init-output.log"

## cloud-init.service - Initial cloud-init job (metadata service crawler)
ssh kube-cp1 "sudo journalctl -u cloud-init.service"
ssh kube-wk1 "sudo journalctl -u cloud-init.service"
ssh kube-wk2 "sudo journalctl -u cloud-init.service"

## cloud-init-local.service - Initial cloud-init job (pre-networking)
ssh kube-cp1 "sudo journalctl -u cloud-init-local.service"
ssh kube-wk1 "sudo journalctl -u cloud-init-local.service"
ssh kube-wk2 "sudo journalctl -u cloud-init-local.service"

## cloud-config.service - Apply the settings specified in cloud-config
ssh kube-cp1 "sudo journalctl -u cloud-config.service"
ssh kube-wk1 "sudo journalctl -u cloud-config.service"
ssh kube-wk2 "sudo journalctl -u cloud-config.service"

## cloud-final.service - Execute cloud user/final scripts
## kube-node-setup.sh などのログはここにあります
ssh kube-cp1 "sudo journalctl -u cloud-final.service"
ssh kube-wk1 "sudo journalctl -u cloud-final.service"
ssh kube-wk2 "sudo journalctl -u cloud-final.service"
```
