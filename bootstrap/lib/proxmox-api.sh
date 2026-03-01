#!/usr/bin/env bash
# Proxmox REST API curl wrappers

PVE_TICKET=""
PVE_CSRF=""



pve_get() {
  local node="$1"
  local path="$2"

  echo $( curl -sk -w "%{http_code}" -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
  "https://${node}:8006${path}" )

}

pve_post() {
  local node="$1"
  local path="$2"
  shift 2
  local data=("$@")

  local data_args=()
  for d in "${data[@]}"; do
    data_args+=(-d "$d")
  done

  echo $( curl -sk -w "%{http_code}" -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
    "${data_args[@]}" \
    "https://${node}:8006${path}" )
}

pve_put() {
  local node="$1"
  local path="$2"
  shift 2
  local data=("$@")

  local data_args=()
  for d in "${data[@]}"; do
    data_args+=(-d "$d")
  done

  echo $( curl -sk -X PUT -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
    "${data_args[@]}" \
    "https://${node}:8006${path}" )
}

pve_delete() {
  local node="$1"
  local path="$2"

  echo $( curl -sk -X DELETE -H "Authorization: PVEAPIToken=${PVE_API_TOKEN_ID}=${PVE_API_TOKEN_SECRET}" \
    "https://${node}:8006${path}" )
}
