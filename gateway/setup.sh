#!/bin/bash

#export ingress domain
export INGRESS_DOMAIN=<your.desired.domain>

#export ingress host
export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

#Use this if you don't have a domain
INGRESS_DOMAIN=${INGRESS_HOST}.nip.io

#Generating self signed certificate
CERT_DIR=/tmp/certs
mkdir -p ${CERT_DIR}
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/O=example Inc./CN=*.${INGRESS_DOMAIN}" -keyout ${CERT_DIR}/ca.key -out ${CERT_DIR}/ca.crt
openssl req -out ${CERT_DIR}/cert.csr -newkey rsa:2048 -nodes -keyout ${CERT_DIR}/tls.key -subj "/CN=*.${INGRESS_DOMAIN}/O=example organization"
openssl x509 -req -days 365 -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -set_serial 0 -in ${CERT_DIR}/cert.csr -out ${CERT_DIR}/tls.crt
kubectl create -n istio-system secret tls telemetry-gw-cert --key=${CERT_DIR}/tls.key --cert=${CERT_DIR}/tls.crt

#Moving an existing TLS cert from another namespace to istio-system
kubectl get secret mydomain-tls -n dev -o yaml | sed "s/dev/istio-system/g" | sed "s/mydomain-tls/telemetry-gw-cert/g" | kubectl apply -n istio-system -f -

#Update ingress-gateway's externalTrafficPolicy to Local
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"externalTrafficPolicy":"Local"}}'

#Update ingress-gateway's externalTrafficPolicy to Cluster
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec":{"externalTrafficPolicy":"Cluster"}}'