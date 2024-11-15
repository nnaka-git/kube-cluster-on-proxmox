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
```bash
-- 共通設定 ----------------------------------------------------
-- from https://github.com/cri-o/packaging/blob/main/README.md/
-- 
-- 最初にコンテナーランタイム（crioとkubernetesをインストールする）

-- crio 公式より
KUBERNETES_VERSION=v1.31
CRIO_VERSION=v1.31

echo $KUBERNETES_VERSION
echo $CRIO_VERSION

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/rpm/repodata/repomd.xml.key
EOF


cat <<EOF | tee /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/rpm/repodata/repomd.xml.key
EOF

dnf install -y container-selinux
dnf install -y cri-o kubelet kubeadm kubectl

systemctl start crio.service
systemctl enable crio.service
systemctl enable kubelet.service

swapoff -a
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1


-- 共通設定 ---------------------------------------------------- END

-- コントロールプレーンでのみ作業-------------------------------------
kubeadm init --pod-network-cidr=10.244.0.0/16
※flannelを使うから下が正解と思われる

	-- workerの参加コマンドが表示されるので、ここでwk1,wk2を参加させる
	確認コマンド
	kubectl get nodes

-- rootはこれ
export KUBECONFIG=/etc/kubernetes/admin.conf
.bashrcにも追記
echo "" >> ~/.bashrc
echo "# for kubernetes" >> ~/.bashrc
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc

-- 一般ユーザーはこれ
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

-- flannel (L3 switchのpod）
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

-- 確認コマンド
kubectl get pods -A

-- そもそもkubeadm init の際に --pod-network-cidrでCIDRを指定しておけば問題なかったのか？
-- 参考：https://ghostzapper.hatenablog.com/entry/2021/11/16/120402



-- metallb (ロードバランサー）
-- kubernetesのproxy設定が、strictARPになっているかどうかを
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system

-- kubernetesのproxy設定の、strictARPをtrueに設定
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

-- gitのマニュフェストを適用してmetallbを作成
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.8/config/manifests/metallb-native.yaml

-- 作成後にIPAddressPool/L2Advertisementの設定を流し込む
-- IPアドレス範囲は環境に合わせて要調整
cat <<EOF | tee ./ipAddressPool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.121-192.168.1.128
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF

kubectl apply -f ./ipAddressPool.yaml

# podの状態確認
kubectl get pods -n kube-flannel

# pod kube-flannel-ds-bqx4j のログ確認
kubectl logs -n kube-flannel kube-flannel-ds-bqx4j



kubectl describe pods/kube-flannel-ds-bqx4j -n kube-flannel
kubectl describe pods/kube-flannel-ds-cjvpg -n kube-flannel
kubectl describe pods/kube-flannel-ds-g2dls -n kube-flannel


-- ワーカーでこれで参加させる ----------------------------------
kubeadm join 192.168.1.111:6443 --token 7vly8b.5eud346tlqadwv4v \
        --discovery-token-ca-cert-hash sha256:eab62cea2e0c837f2d62687f97d3688e03bd0cc26738e1260eaa30be6763e0eb
-- ワーカーでこれで参加させる ----------------------------------



github アクセストークン（classic）
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

-- これでプライベートリポジトリからでも取得できた
curl -H "Authorization: token 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" \
    -H "Accept: application/vnd.github.v3.raw" \
    https://raw.githubusercontent.com/nnaka-git/kube-cluster-on-proxmox/refs/heads/main/scripts/bootstrap.sh

-- これでもいけた
curl -H "Authorization: token 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" \
    https://raw.githubusercontent.com/nnaka-git/kube-cluster-on-proxmox/refs/heads/main/scripts/bootstrap.sh

```