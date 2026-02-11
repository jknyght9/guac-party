#!/usr/bin/env bash
# Proxmox REST API curl wrappers

PVE_TICKET=""
PVE_CSRF=""

pve_auth() {
  local node="$1"
  local user="$2"
  local password="$3"

  local response
  response="$(curl -sk --connect-timeout 10 \
    -d "username=${user}&password=${password}" \
    "https://${node}:8006/api2/json/access/ticket")"

  PVE_TICKET="$(echo "$response" | grep -o '"ticket":"[^"]*"' | cut -d'"' -f4)"
  PVE_CSRF="$(echo "$response" | grep -o '"CSRFPreventionToken":"[^"]*"' | cut -d'"' -f4)"

  if [[ -z "$PVE_TICKET" ]]; then
    echo "ERROR: Authentication failed for ${user} on ${node}."
    echo "Response: ${response}"
    return 1
  fi

  export PVE_TICKET PVE_CSRF
  echo "OK: Authenticated to ${node} as ${user}."
}

pve_get() {
  local node="$1"
  local path="$2"

  curl -sk \
    -b "PVEAuthCookie=${PVE_TICKET}" \
    "https://${node}:8006${path}"
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

  curl -sk \
    -b "PVEAuthCookie=${PVE_TICKET}" \
    -H "CSRFPreventionToken: ${PVE_CSRF}" \
    "${data_args[@]}" \
    "https://${node}:8006${path}"
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

  curl -sk -X PUT \
    -b "PVEAuthCookie=${PVE_TICKET}" \
    -H "CSRFPreventionToken: ${PVE_CSRF}" \
    "${data_args[@]}" \
    "https://${node}:8006${path}"
}

pve_delete() {
  local node="$1"
  local path="$2"

  curl -sk -X DELETE \
    -b "PVEAuthCookie=${PVE_TICKET}" \
    -H "CSRFPreventionToken: ${PVE_CSRF}" \
    "https://${node}:8006${path}"
}
