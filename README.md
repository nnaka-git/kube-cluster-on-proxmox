```bash
# cloudinitの実行ログチェック(トラブルシュート用)
# だいたいのスクリプトは k8s-cp1で動いてます
## check cloud-init 
sudo cloud-init query userdata
sudo cloud-init schema --system --annotate

## check /var/log/cloud-init-output.log
ssh k8s-cp1 "sudo cat /var/log/cloud-init-output.log"
ssh k8s-wk1 "sudo cat /var/log/cloud-init-output.log"
ssh k8s-wk2 "sudo cat /var/log/cloud-init-output.log"

## cloud-init.service - Initial cloud-init job (metadata service crawler)
ssh k8s-cp1 "sudo journalctl -u cloud-init.service"
ssh k8s-wk1 "sudo journalctl -u cloud-init.service"
ssh k8s-wk2 "sudo journalctl -u cloud-init.service"

## cloud-init-local.service - Initial cloud-init job (pre-networking)
ssh k8s-cp1 "sudo journalctl -u cloud-init-local.service"
ssh k8s-wk1 "sudo journalctl -u cloud-init-local.service"
ssh k8s-wk2 "sudo journalctl -u cloud-init-local.service"

## cloud-config.service - Apply the settings specified in cloud-config
ssh k8s-cp1 "sudo journalctl -u cloud-config.service"
ssh k8s-wk1 "sudo journalctl -u cloud-config.service"
ssh k8s-wk2 "sudo journalctl -u cloud-config.service"

## cloud-final.service - Execute cloud user/final scripts
## k8s-node-setup.sh などのログはここにあります
ssh k8s-cp1 "sudo journalctl -u cloud-final.service"
ssh k8s-wk1 "sudo journalctl -u cloud-final.service"
ssh k8s-wk2 "sudo journalctl -u cloud-final.service"
```
