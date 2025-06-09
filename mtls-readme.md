# Server Setup for RHOBS Observatorium with mTLS

## Provision an existing cluster

You will need to have an OCP cluster with cert-manager installed and running.
An OSD cluster will have cert-manager installed by default.
If you want to install cert-manager manually you can run the following command:

```bash
mage CertManager
```

## Generate the CA

We need to generate a CA that will be used to sign the server and client certificates.

```bash
mage GenerateCA
```

## Create the Secret and the issuer

Next we will create the Secret and the issuer we will need to support mTLS.

```bash
# Create the RHOBS namespace with the CA secret
kubectl create namespace rhobs-production --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret tls my-server-ca-secret \
  --cert=/tmp/mtls-cas/intermediate-server.crt \
  --key=/tmp/mtls-cas/intermediate-server.key \
  -n rhobs-production \
  --dry-run=client -o yaml | kubectl apply -f -
 
 sleep 2
  
 # Create namespaced Issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: my-ca-issuer
  namespace: rhobs-production
spec:
  ca:
    secretName: my-server-ca-secret
EOF


# We also want the CA for the tenants 
kubectl create secret generic test-tenant-client-ca \
  -n rhobs-production \
  --from-file=tls.crt=/tmp/mtls-cas/client-ca-bundle.pem
```



## Setup Thanos

Next we want to set up Thanos as the metrics backend for RHOBS Observatorium. We will do so with Thanos operator.

```bash
oc process --local -f ./resources/services/bundle/production/thanos-operator-crds.yaml \
  | oc apply --namespace=rhobs-production --server-side -f -
  
oc process --local -f ./resources/services/bundle/production/operator.yaml \
  | oc apply --namespace=rhobs-production --server-side -f -


kubectl apply -f ./resources/services/rhobs-thanos-operator/mtls-spike/thanos.yaml
```




## Create the server certificate

Now that we have the issuer, we can create the server certificate that will be used by RHOBS Observatorium.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-service-cert
  namespace: rhobs-production
spec:
  secretName: my-service-tls
  duration: 2160h
  renewBefore: 360h
  commonName: observatorium-api.rhobs-production.svc
  issuerRef:
    name: my-ca-issuer
    kind: Issuer
EOF
```

## Setup Observatorium with mTLS supported 

Now we can set up Observatorium with mTLS support. We will use the `observatorium-api` service to expose the API.

```bash
kubectl apply -f ./resources/services/rhobs-thanos-operator/mtls-spike/api.yaml

oc get route observatorium-api -n rhobs-production -o jsonpath='{.spec.host}' > /tmp/route-host.txt

cat <<EOF > patch.yaml
spec:
  dnsNames:
    - $(cat /tmp/route-host.txt)
  commonName: observatorium-api
EOF

oc patch certificate my-service-cert -n rhobs-production --type=merge --patch-file=patch.yaml
rm patch.yaml
oc rollout restart deployment/observatorium-api -n rhobs-production
```

# Client Setup

## Provision a KinD cluster

To simulate an OSD cluster in the wild, we can run a KinD cluster locally.

```bash
mage ClientCluster
kind export kubeconfig
# The following command should show a list of Pods we will use as an example app
kubectl -n test-tenant get pods
```

## Create the client certificate

```bash
kubectl -n test-tenant create secret tls client-ca-secret \
  --cert=/tmp/mtls-cas/intermediate-client.crt \
  --key=/tmp/mtls-cas/intermediate-client.key | true
  
 kubectl -n test-tenant create secret generic observatorium-server-ca \
  --from-file=ca.crt=/tmp/mtls-cas/intermediate-server.crt | true 

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: client-ca-issuer
  namespace: test-tenant
spec:
  ca:
    secretName: client-ca-secret
EOF

cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: prometheus-remote-write-client-cert
  namespace: test-tenant
spec:
  secretName: prometheus-remote-write-client-tls
  commonName: test-tenant
  dnsNames:
    - test-tenant
  duration: 2160h
  renewBefore: 360h
  usages:
    - client auth
  issuerRef:
    name: client-ca-issuer
    kind: Issuer
EOF
```


## Setup remote write
Now we can set up the remote write configuration for the client to send metrics to Observatorium.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus-dev
  namespace: test-tenant
spec:
  serviceAccountName: prometheus
  secrets:
    - prometheus-remote-write-client-tls
    - observatorium-server-ca
  serviceMonitorSelector:
    matchLabels:
      team: frontend
  externalLabels:
    env: dev
  remoteWrite:
    - name: observatorium-api
      url: https://$(cat /tmp/route-host.txt)/api/metrics/v1/test-tenant/api/v1/receive
      tlsConfig:
        caFile: /etc/prometheus/secrets/observatorium-server-ca/ca.crt
        certFile: /etc/prometheus/secrets/prometheus-remote-write-client-tls/tls.crt
        keyFile: /etc/prometheus/secrets/prometheus-remote-write-client-tls/tls.key
EOF
```



