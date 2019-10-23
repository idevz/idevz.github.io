#!/bin/zsh
. ~/k8s-export
mkdir -p /etc/kubernetes/pki && cd /etc/kubernetes/pki
export PKI_URL="https://kairen.github.io/files/manual-v1.8/pki"
export KUBE_APISERVER="https://10.211.55.3:6443"
#下載ca-config.json與ca-csr.json檔案，並產生 CA 金鑰：

wget "${PKI_URL}/ca-config.json" "${PKI_URL}/ca-csr.json"
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
#API server certificate
#下載apiserver-csr.json檔案，並產生 kube-apiserver certificate 證書：

wget "${PKI_URL}/apiserver-csr.json"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.211.55.3,127.0.0.1 \
  -profile=kubernetes \
  apiserver-csr.json | cfssljson -bare apiserver
#若節點 IP 不同，需要修改apiserver-csr.json的hosts。

#Front proxy certificate
#下載front-proxy-ca-csr.json檔案，並產生 Front proxy CA 金鑰，Front proxy 主要是用在 API aggregator 上:

wget "${PKI_URL}/front-proxy-ca-csr.json"
cfssl gencert \
  -initca front-proxy-ca-csr.json | cfssljson -bare front-proxy-ca

#下載front-proxy-client-csr.json檔案，並產生 front-proxy-client 證書：
wget "${PKI_URL}/front-proxy-client-csr.json"
cfssl gencert \
  -ca=front-proxy-ca.pem \
  -ca-key=front-proxy-ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  front-proxy-client-csr.json | cfssljson -bare front-proxy-client

#Bootstrap Token
#由於透過手動建立 CA 方式太過繁雜，只適合少量機器，因為每次簽證時都需要綁定 Node IP，隨機器增加會帶來很多困擾，因此這邊使用 TLS Bootstrapping 方式進行授權，由 apiserver 自動給符合條件的 Node 發送證書來授權加入叢集。
#主要做法是 kubelet 啟動時，向 kube-apiserver 傳送 TLS Bootstrapping 請求，而 kube-apiserver 驗證 kubelet 請求的 token 是否與設定的一樣，若一樣就自動產生 kubelet 證書與金鑰。具體作法可以參考 TLS bootstrapping。
#首先建立一個變數來產生BOOTSTRAP_TOKEN，並建立 bootstrap.conf 的 kubeconfig 檔：

export BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat <<EOF > /etc/kubernetes/token.csv
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF

# bootstrap set-cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=../bootstrap.conf

# bootstrap set-credentials
kubectl config set-credentials kubelet-bootstrap \
    --token=${BOOTSTRAP_TOKEN} \
    --kubeconfig=../bootstrap.conf

# bootstrap set-context
kubectl config set-context default \
    --cluster=kubernetes \
    --user=kubelet-bootstrap \
   --kubeconfig=../bootstrap.conf

# bootstrap set default context
kubectl config use-context default --kubeconfig=../bootstrap.conf
#若想要用 CA 方式來認證，可以參考 Kubelet certificate。

#Admin certificate
#下載admin-csr.json檔案，並產生 admin certificate 證書：

wget "${PKI_URL}/admin-csr.json"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

#接著透過以下指令產生名稱為 admin.conf 的 kubeconfig 檔：

# admin set-cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=../admin.conf

# admin set-credentials
kubectl config set-credentials kubernetes-admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=../admin.conf

# admin set-context
kubectl config set-context kubernetes-admin@kubernetes \
    --cluster=kubernetes \
    --user=kubernetes-admin \
    --kubeconfig=../admin.conf

# admin set default context
kubectl config use-context kubernetes-admin@kubernetes \
    --kubeconfig=../admin.conf

#Controller manager certificate
#下載manager-csr.json檔案，並產生 kube-controller-manager certificate 證書：

wget "${PKI_URL}/manager-csr.json"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.211.55.3,127.0.0.1 \
  -profile=kubernetes \
  manager-csr.json | cfssljson -bare controller-manager

#若節點 IP 不同，需要修改manager-csr.json的hosts。
#接著透過以下指令產生名稱為controller-manager.conf的 kubeconfig 檔：

# controller-manager set-cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=../controller-manager.conf

# controller-manager set-credentials
kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=controller-manager.pem \
    --client-key=controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=../controller-manager.conf

# controller-manager set-context
kubectl config set-context system:kube-controller-manager@kubernetes \
    --cluster=kubernetes \
    --user=system:kube-controller-manager \
    --kubeconfig=../controller-manager.conf

# controller-manager set default context
kubectl config use-context system:kube-controller-manager@kubernetes \
    --kubeconfig=../controller-manager.conf

#Scheduler certificate
#下載scheduler-csr.json檔案，並產生 kube-scheduler certificate 證書：

wget "${PKI_URL}/scheduler-csr.json"
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.211.55.3,127.0.0.1 \
  -profile=kubernetes \
  scheduler-csr.json | cfssljson -bare scheduler

#若節點 IP 不同，需要修改scheduler-csr.json的hosts。

#接著透過以下指令產生名稱為 scheduler.conf 的 kubeconfig 檔：
# scheduler set-cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=../scheduler.conf

# scheduler set-credentials
kubectl config set-credentials system:kube-scheduler \
    --client-certificate=scheduler.pem \
    --client-key=scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=../scheduler.conf

# scheduler set-context
kubectl config set-context system:kube-scheduler@kubernetes \
    --cluster=kubernetes \
    --user=system:kube-scheduler \
    --kubeconfig=../scheduler.conf

# scheduler set default context
kubectl config use-context system:kube-scheduler@kubernetes \
    --kubeconfig=../scheduler.conf

#Kubelet master certificate
#下載kubelet-csr.json檔案，並產生 master node certificate 證書：

wget "${PKI_URL}/kubelet-csr.json"
sed -i 's/$NODE/master1/g' kubelet-csr.json
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=master1,10.211.55.3,127.0.0.1 \
  -profile=kubernetes \
  kubelet-csr.json | cfssljson -bare kubelet

#這邊$NODE需要隨節點名稱不同而改變。

#接著透過以下指令產生名稱為 kubelet.conf 的 kubeconfig 檔：

# kubelet set-cluster
kubectl config set-cluster kubernetes \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=${KUBE_APISERVER} \
    --kubeconfig=../kubelet.conf

# kubelet set-credentials
kubectl config set-credentials system:node:master1 \
    --client-certificate=kubelet.pem \
    --client-key=kubelet-key.pem \
    --embed-certs=true \
    --kubeconfig=../kubelet.conf

# kubelet set-context
kubectl config set-context system:node:master1@kubernetes \
    --cluster=kubernetes \
    --user=system:node:master1 \
    --kubeconfig=../kubelet.conf

# kubelet set default context
kubectl config use-context system:node:master1@kubernetes \
    --kubeconfig=../kubelet.conf

#Service account key
#Service account 不是透過 CA 進行認證，因此不要透過 CA 來做 Service account key 的檢查，這邊建立一組 Private 與 Public 金鑰提供給 Service account key 使用：

openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub

#完成後刪除不必要檔案：

#rm -rf *.json *.csr
#確認/etc/kubernetes與/etc/kubernetes/pki有以下檔案：

#安裝 Kubernetes 核心元件
#首先下載 Kubernetes 核心元件 YAML 檔案，這邊我們不透過 Binary 方案來建立 Master 核心元件，而是利用 Kubernetes Static Pod 來達成，因此需下載所有核心元件的Static Pod檔案到/etc/kubernetes/manifests目錄：

export CORE_URL="https://kairen.github.io/files/manual-v1.8/master"
mkdir -p /etc/kubernetes/manifests && cd /etc/kubernetes/manifests
for FILE in apiserver manager scheduler; do
    wget "${CORE_URL}/${FILE}.yml.conf" -O ${FILE}.yml
    sed -i 's/172.16.35.12/10.211.55.3/g' ${FILE}.yml
    sed -i 's/10.244.0.0/10.211.0.0/g' ${FILE}.yml
    sed -i 's/gcr.io/108.61.192.8:5000/g' ${FILE}.yml
done
#若IP與教學設定不同的話，請記得修改apiserver.yml、manager.yml、scheduler.yml。
#apiserver 中的 NodeRestriction 請參考 Using Node Authorization。

#產生一個用來加密 Etcd 的 Key：

xx=`head -c 32 /dev/urandom | base64`
#SUpbL4juUYyvxj3/gonV5xVEx8j769/99TSAf8YT/sQ=
在/etc/kubernetes/目錄下，建立encryption.yml的加密 YAML 檔案：

cat <<EOF > /etc/kubernetes/encryption.yml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${xx}
      - identity: {}
EOF
#Etcd 資料加密可參考這篇 Encrypting data at rest。

#在/etc/kubernetes/目錄下，建立audit-policy.yml的進階稽核策略 YAML 檔：

cat <<EOF > /etc/kubernetes/audit-policy.yml
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
EOF

#Audit Policy 請參考這篇 Auditing。

#下載kubelet.service相關檔案來管理 kubelet：

export KUBELET_URL="https://kairen.github.io/files/manual-v1.8/master"
mkdir -p /etc/systemd/system/kubelet.service.d
wget "${KUBELET_URL}/kubelet.service" -O /lib/systemd/system/kubelet.service
wget "${KUBELET_URL}/10-kubelet.conf" -O /etc/systemd/system/kubelet.service.d/10-kubelet.conf
sed '12 aEnvironment="KUBELET_ARGS=--pod_infra_container_image=108.61.192.8:5000/google-containers/pause-amd64:3.0"' -i /etc/systemd/system/kubelet.service.d/10-kubelet.conf
sed '$s/$/ $KUBELET_ARGS/' -i /etc/systemd/system/kubelet.service.d/10-kubelet.conf
#最後建立 var 存放資訊，然後啟動 kubelet 服務:

mkdir -p /var/lib/kubelet /var/log/kubernetes
systemctl enable kubelet.service && systemctl start kubelet.service
#完成後會需要一段時間來下載映像檔與啟動元件，可以利用該指令來監看：


10.96.0.10