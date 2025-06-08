#!/usr/local/bin/bash

function file_exists() {
  local item="$1"
  if [[ -f "$item" && ! -L "$item" ]]; then
    return 0
  fi
  return 1
}

function dir_exists_and_writable() {
  local item="$1"
  if [[ -d "$item" && -w "$item" ]]; then
    return 0
  fi
  return 1
}

function error_exit() {
  local message="$1"
  echo "Error: $message"
  exit 1
}

function update_progress() {
  processed_files=$((processed_files + 1))
  if [ $(($processed_files % 10)) -eq 0 ]; then
    echo -e "\rProcessed $processed_files/$total_files files..."
  fi
}

function log_error() {
  echo "[ERROR] $1"
}

function log_warn() {
  echo "[WARN] $1"
}

function log_info() {
  echo "[INFO] $1"
}


