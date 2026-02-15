#!/usr/bin/env bash
# @INST_LIB_NAME: state-utils
# @INST_DESC: Gerenciamento de estado e persistência via pares chave-valor.
# @INST_FUNC: state_kv_set
# @INST_DESC: Salva o valor de uma chave no arquivo de estado persistente.
# @INST_FUNC: state_kv_get
# @INST_DESC: Recupera o valor de uma chave do arquivo de estado.

state_prepare() {
  # @ID: STATE_PREPARE
  # @STEP: Garante diretorio e arquivo de estado antes de operacoes de leitura/escrita.
  # @DATA: OUT STATE_DIR, STATE_FILE
  mkdirs "$STATE_DIR"
  if [[ ! -f "$STATE_FILE" ]]; then
    : >"$STATE_FILE"
  fi
}

_state_is_valid_key() {
  local key
  key="${1-}"
  [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]
}

_state_decode_value() {
  local raw
  raw="${1-}"
  local decoded=""
  if [[ -z "$raw" ]]; then
    printf '%s' ""
    return 0
  fi
  if eval "decoded=$raw" 2>/dev/null; then
    printf '%s' "$decoded"
  else
    printf '%s' "$raw"
  fi
}

state_kv_set() {
  # @ID: STATE_KV_SET
  # @STEP: Persiste chave/valor no arquivo de estado com substituicao idempotente.
  # @REQ: STATE_PREPARE
  # @FAIL: STATE_WRITE_FAILED
  # @DATA: OUT STATE_FILE
  local key
  key="$(sanitize_id "${1-}")"
  local val
  val="$(sanitize_ws "${2-}")"
  local enc=""
  local tmp=""
  if [[ -z "$key" ]]; then
    stderr "Erro: state_kv_set key vazia."
    return 1
  fi
  if ! _state_is_valid_key "$key"; then
    stderr "Erro: state_kv_set key inválida: $key"
    return 1
  fi
  if [[ ! -f "$STATE_FILE" ]]; then
    state_prepare || return 1
  fi
  printf -v enc '%q' "$val"

  tmp="$(mktemp)" || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
    local lk="${BASH_REMATCH[1]}"
    if [[ "$lk" == "$key" ]]; then
      continue
    fi
    printf '%s\n' "$line" >>"$tmp" || return 1
  done <"$STATE_FILE"

  printf '%s=%s\n' "$key" "$enc" >>"$tmp" || return 1
  mv "$tmp" "$STATE_FILE" || {
    # @ID: STATE_WRITE_FAILED
    # @STEP: Sinaliza falha ao gravar estado persistido.
    # @REQ: STATE_KV_SET
    # @DATA: OUT STDERR
    return 1
  }
}

state_kv_get() {
  # @ID: STATE_KV_GET
  # @STEP: Recupera ultimo valor conhecido de uma chave no estado persistido.
  # @REQ: STATE_PREPARE
  # @DATA: IN STATE_FILE
  local key
  key="$(sanitize_id "${1-}")"
  local last_raw=""
  local line=""

  if [[ -z "$key" ]]; then
    return 1
  fi
  if ! _state_is_valid_key "$key"; then
    return 1
  fi

  if [[ -f "$STATE_FILE" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
      local lk="${BASH_REMATCH[1]}"
      local lv="${BASH_REMATCH[2]}"
      if [[ "$lk" == "$key" ]]; then
        last_raw="$lv"
      fi
    done <"$STATE_FILE"

    _state_decode_value "$last_raw"
  fi
}

state_load() {
  # @ID: STATE_LOAD_EXPORT
  # @STEP: Carrega todas as chaves persistidas para variaveis de sessao corrente.
  # @REQ: STATE_KV_GET
  # @DATA: IN STATE_FILE
  if [[ -f "$STATE_FILE" ]]; then
    local line=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
      local lk="${BASH_REMATCH[1]}"
      local lv="${BASH_REMATCH[2]}"
      local decoded=""
      decoded="$(_state_decode_value "$lv")"
      printf -v "$lk" '%s' "$decoded"
    done <"$STATE_FILE"
  fi
}
