ETCD_ADVERTISE_URL=$(kubectl get pod $(kubectl get pod | grep etcd | awk '{print $1}') -o yaml | grep advertise-client-urls | awk -F= '{print $2}')
ETCD_POD_NAME=$(kubectl get pod | grep etcd | awk '{print $1}')

kubectl exec $ETCD_POD_NAME -n kube-system -- sh -c \
    "ETCDCTL_API=3 etcdctl \
--endpoints $ETCD_ADVERTISE_URL \
--cacert /etc/kubernetes/pki/ca.pem \
--key /etc/kubernetes/pki/kubernetes-key.pem \
--cert /etc/kubernetes/pki/kubernetes.pem \
get \"\" --prefix=true -w json" >etcd-kv.json

for k in $(cat etcd-kv.json | jq '.kvs[].key' | cut -d '"' -f2); do
    echo $k | base64 --decode
    echo
done | grep crdstart

KEY="/registry/deployments/default/crdstart"

kubectl exec $ETCD_POD_NAME -n kube-system -- sh -c \
    "ETCDCTL_API=3 etcdctl \
--endpoints $ETCD_ADVERTISE_URL \
--cacert /etc/kubernetes/pki/ca.pem \
--key /etc/kubernetes/pki/kubernetes-key.pem \
--cert /etc/kubernetes/pki/kubernetes.pem \
get \"$KEY\" -w json" | jq '.kvs[0].key' | cut -d '"' -f2 | base64 --decode

k exec $ETCD_POD_NAME -n kube-system -- sh -c \
    "ETCDCTL_API=3 etcdctl \
--endpoints $ETCD_ADVERTISE_URL \
--cacert /etc/kubernetes/pki/ca.pem \
--key /etc/kubernetes/pki/kubernetes-key.pem \
--cert /etc/kubernetes/pki/kubernetes.pem \
get \"$KEY\" -w json" | jq '.kvs[0].value' | cut -d '"' -f2 | base64 --decode

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fa0a14ebe3a2"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fa0a89fe47bc"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fa0ae16b8025"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fa0ae5e511ea"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fa0b20c41b80"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fb097e703932"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fb09bd062e45"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fb0a0791e147"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fb0a0965c905"

KEY="/registry/events/default/crdstart-6c4d7f447-lc42p.15c5fb0a21bfe852"
