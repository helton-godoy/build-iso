#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# Module: step/config_wizard
# Handler: step_config_wizard
# Single responsibility: guided configuration (language/keyboard/hostname/network/time/users/storage/zfs/boot) -> writes state.env

step_config_wizard() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Assistente de Configuração"

    if ! declare -F state_load >/dev/null 2>&1 || ! declare -F state_kv_set >/dev/null 2>&1; then
        ui_error "State engine não carregado (router)."
        return 1
    fi
    if ! declare -F ui_select >/dev/null 2>&1 || ! declare -F ui_confirm >/dev/null 2>&1; then
        ui_error "UI não carregada (router)."
        return 1
    fi
    if ! declare -F diskutils_disks_human_table >/dev/null 2>&1; then
        ui_error "Disk utils não carregado (disk-utils.sh)."
        return 1
    fi
    if ! declare -F netutils_list_ifaces >/dev/null 2>&1; then
        ui_error "Net utils não carregado (net-utils.sh)."
        return 1
    fi
    if ! declare -F timeutils_list_timezones >/dev/null 2>&1; then
        ui_error "Time utils não carregado (time-utils.sh)."
        return 1
    fi
    if ! declare -F authutils_password_validate_all >/dev/null 2>&1; then
        ui_error "Auth utils não carregado (auth-utils.sh)."
        return 1
    fi
    if ! declare -F validate_all_checkpoint >/dev/null 2>&1; then
        ui_error "Validate utils não carregado (validate-utils.sh)."
        return 1
    fi

    state_load || true

    wizard_screen_welcome || return 1
    wizard_screen_locale || return 1
    wizard_screen_keyboard || return 1
    wizard_screen_hostname || return 1
    wizard_screen_network || return 1
    wizard_screen_time || return 1
    wizard_screen_users || return 1
    wizard_screen_storage || return 1
    wizard_screen_zfs || return 1
    wizard_screen_boot || return 1

    wizard_screen_summary || return 1

    if ! validate_all_checkpoint; then
        ui_error "Configuração inválida. Revise e corrija."
        return 1
    fi

    ui_success "Configuração concluída e validada."
    state_kv_set "install_stage_config_done" "1" || true
}

wizard_screen_welcome() {
    ui_section "Boas-vindas"
    ui_card "Bem-vindo" \
        "  ${UI_BULLET:-•} Este assistente vai coletar as configurações essenciais." \
        "  ${UI_BULLET:-•} Ao final, você verá um resumo e poderá iniciar a instalação." \
        "" \
        "  ${UI_WARN:-⚠} A instalação pode apagar discos conforme sua escolha."
    ui_confirm "Continuar?" "Continuar" "Sair"
}

wizard_screen_locale() {
    ui_section "Idioma e Localização"

    local lang locale
    lang="$(sanitize_ws "${install_lang-}")"
    locale="$(sanitize_ws "${install_locale-}")"

    local opt_lang
    opt_lang="$(ui_select "Selecione o idioma (LANG)" \
        "pt_BR.UTF-8" "en_US.UTF-8" "es_ES.UTF-8" "fr_FR.UTF-8" "de_DE.UTF-8")"
    opt_lang="$(sanitize_ws "$opt_lang")"
    if [[ -z "$opt_lang" ]]; then
        opt_lang="${lang:-pt_BR.UTF-8}"
    fi

    local opt_locale
    opt_locale="$(ui_select "Selecione o locale padrão (LC_ALL)" \
        "$opt_lang" "pt_BR.UTF-8" "en_US.UTF-8")"
    opt_locale="$(sanitize_ws "$opt_locale")"
    if [[ -z "$opt_locale" ]]; then
        opt_locale="${locale:-$opt_lang}"
    fi

    state_kv_set "install_lang" "$opt_lang" || return 1
    state_kv_set "install_locale" "$opt_locale" || return 1
}

wizard_screen_keyboard() {
    ui_section "Teclado"

    local keymap
    keymap="$(sanitize_ws "${install_keymap-}")"

    local opt
    opt="$(ui_select "Layout do teclado" "br" "us" "us-intl" "pt" "es" "fr" "de")"
    opt="$(sanitize_ws "$opt")"
    if [[ -z "$opt" ]]; then
        opt="${keymap:-br}"
    fi

    state_kv_set "install_keymap" "$opt" || return 1
}

wizard_screen_hostname() {
    ui_section "Hostname"

    local hn dom
    hn="$(sanitize_ws "${install_hostname-}")"
    dom="$(sanitize_ws "${install_domain-}")"

    local opt_hn opt_dom
    opt_hn="$(wizard_input_text "Hostname (ex: fileserver)" "${hn:-fileserver}" "^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$")"
    opt_hn="$(sanitize_ws "$opt_hn")"
    if [[ -z "$opt_hn" ]]; then
        ui_error "Hostname inválido."
        return 1
    fi

    opt_dom="$(wizard_input_text "Domínio (opcional, ex: lab.local)" "$dom" "^$|^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)*[a-zA-Z]{2,63}$")"
    opt_dom="$(sanitize_ws "$opt_dom")"

    state_kv_set "install_hostname" "$opt_hn" || return 1
    state_kv_set "install_domain" "$opt_dom" || return 1
}

wizard_screen_network() {
    ui_section "Rede"

    local ifc method
    ifc="$(sanitize_ws "${install_net_iface-}")"
    method="$(sanitize_id "${install_net_method-}")"

    local ifaces
    ifaces="$(netutils_list_ifaces)"
    ifaces="$(sanitize_ws "$ifaces")"
    if [[ -z "$ifaces" ]]; then
        ui_error "Nenhuma interface de rede encontrada."
        return 1
    fi

    local choices=()
    local line
    while IFS= read -r line; do
        line="$(sanitize_ws "$line")"
        [[ -z "$line" ]] && continue
        choices+=("$line")
    done <<<"$(printf '%s\n' "$ifaces")"

    local opt_ifc
    opt_ifc="$(ui_select "Interface de rede" "${choices[@]}")"
    opt_ifc="$(sanitize_ws "$opt_ifc")"
    if [[ -z "$opt_ifc" ]]; then
        opt_ifc="$ifc"
    fi
    if [[ -z "$opt_ifc" ]]; then
        ui_error "Interface inválida."
        return 1
    fi

    local opt_method
    opt_method="$(ui_select "Método de configuração" "dhcp" "manual")"
    opt_method="$(sanitize_id "$opt_method")"
    if [[ -z "$opt_method" ]]; then
        opt_method="${method:-dhcp}"
    fi

    state_kv_set "install_net_iface" "$opt_ifc" || return 1
    state_kv_set "install_net_method" "$opt_method" || return 1

    local proxy
    proxy="$(sanitize_ws "${install_proxy-}")"
    proxy="$(wizard_input_text "Proxy (opcional) ex: http://proxy:3128" "$proxy" "^$|^(https?://)?[^[:space:]]+$")"
    proxy="$(sanitize_ws "$proxy")"
    state_kv_set "install_proxy" "$proxy" || return 1

    if [[ "$opt_method" == "manual" ]]; then
        local ip cidr gw dns
        ip="$(sanitize_ws "${install_net_ip-}")"
        cidr="$(sanitize_ws "${install_net_mask-}")"
        gw="$(sanitize_ws "${install_net_gw-}")"
        dns="$(sanitize_ws "${install_net_dns-}")"

        ip="$(wizard_input_text "IP (IPv4)" "$ip" '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')"
        cidr="$(wizard_input_text "Máscara CIDR (0-32)" "${cidr:-24}" '^([0-9]|[12][0-9]|3[0-2])$')"
        gw="$(wizard_input_text "Gateway (IPv4)" "$gw" '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')"
        dns="$(wizard_input_text "DNS (IPv4, separados por espaço)" "${dns:-1.1.1.1 8.8.8.8}" '^$|^([0-9]{1,3}\.){3}[0-9]{1,3}([[:space:]]+([0-9]{1,3}\.){3}[0-9]{1,3})*$')"

        state_kv_set "install_net_ip" "$(sanitize_ws "$ip")" || return 1
        state_kv_set "install_net_mask" "$(sanitize_ws "$cidr")" || return 1
        state_kv_set "install_net_gw" "$(sanitize_ws "$gw")" || return 1
        state_kv_set "install_net_dns" "$(sanitize_ws "$dns")" || return 1
    else
        state_kv_set "install_net_ip" "" || true
        state_kv_set "install_net_mask" "" || true
        state_kv_set "install_net_gw" "" || true
        state_kv_set "install_net_dns" "" || true
    fi
}

wizard_screen_time() {
    ui_section "Fuso Horário e Relógio"

    local tz ntp ntp_server
    tz="$(sanitize_ws "${install_tz-}")"
    ntp="$(sanitize_ws "${install_ntp-}")"
    ntp_server="$(sanitize_ws "${install_ntp_server-}")"

    local opt_tz
    opt_tz="$(wizard_pick_timezone "${tz:-UTC}")"
    opt_tz="$(sanitize_ws "$opt_tz")"
    if [[ -z "$opt_tz" ]]; then
        ui_error "Timezone inválido."
        return 1
    fi

    local opt_ntp
    opt_ntp="$(ui_select "Ativar NTP?" "1" "0")"
    opt_ntp="$(sanitize_ws "$opt_ntp")"
    if [[ -z "$opt_ntp" ]]; then
        opt_ntp="${ntp:-1}"
    fi

    local opt_srv
    opt_srv="$ntp_server"
    if [[ "$opt_ntp" == "1" ]]; then
        opt_srv="$(wizard_input_text "Servidor NTP" "${ntp_server:-pool.ntp.org}" '^[^[:space:]]+$')"
        opt_srv="$(sanitize_ws "$opt_srv")"
        [[ -z "$opt_srv" ]] && opt_srv="pool.ntp.org"
    fi

    state_kv_set "install_tz" "$opt_tz" || return 1
    state_kv_set "install_ntp" "$opt_ntp" || return 1
    state_kv_set "install_ntp_server" "$opt_srv" || return 1
}

wizard_screen_users() {
    ui_section "Usuários e Senhas"

    local fullname username
    fullname="$(sanitize_ws "${install_user_fullname-}")"
    username="$(sanitize_ws "${install_username-}")"

    local opt_full opt_user
    opt_full="$(wizard_input_text "Nome completo" "${fullname:-Administrador}" '^.+$')"
    opt_full="$(sanitize_ws "$opt_full")"
    if [[ -z "$opt_full" ]]; then
        ui_error "Nome completo inválido."
        return 1
    fi

    opt_user="$(wizard_input_text "Nome de usuário (linux)" "${username:-admin}" '^[a-z_][a-z0-9_-]{0,31}$')"
    opt_user="$(sanitize_ws "$opt_user")"
    if [[ -z "$opt_user" ]]; then
        ui_error "Usuário inválido."
        return 1
    fi

    local pw1 pw2
    pw1="$(wizard_input_secret "Senha do usuário" "")"
    pw2="$(wizard_input_secret "Confirmar senha do usuário" "")"
    if [[ -z "$(sanitize_ws "$pw1")" || -z "$(sanitize_ws "$pw2")" ]]; then
        ui_error "Senha vazia."
        return 1
    fi
    if [[ "$pw1" != "$pw2" ]]; then
        ui_error "Senha não confere."
        return 1
    fi
    if ! authutils_password_validate_all "$pw1" "" ""; then
        ui_error "Senha fraca (mínimo e complexidade)."
        return 1
    fi

    local root_enable same_root
    root_enable="$(sanitize_ws "${install_root_enable-0}")"
    same_root="$(sanitize_ws "${install_root_same_as_user-0}")"

    local opt_root_enable
    opt_root_enable="$(ui_select "Criar conta root com senha?" "0" "1")"
    opt_root_enable="$(sanitize_ws "$opt_root_enable")"
    [[ -z "$opt_root_enable" ]] && opt_root_enable="$root_enable"

    local opt_same
    opt_same="$(ui_select "Usar mesma senha do usuário para root?" "0" "1")"
    opt_same="$(sanitize_ws "$opt_same")"
    [[ -z "$opt_same" ]] && opt_same="$same_root"

    local rp1="" rp2=""
    if [[ "$opt_root_enable" == "1" ]]; then
        if [[ "$opt_same" == "1" ]]; then
            rp1="$pw1"
            rp2="$pw2"
        else
            rp1="$(wizard_input_secret "Senha do root" "")"
            rp2="$(wizard_input_secret "Confirmar senha do root" "")"
            if [[ "$rp1" != "$rp2" ]]; then
                ui_error "Senha do root não confere."
                return 1
            fi
            if ! authutils_password_validate_all "$rp1" "" ""; then
                ui_error "Senha do root fraca."
                return 1
            fi
        fi
    fi

    state_kv_set "install_user_fullname" "$opt_full" || return 1
    state_kv_set "install_username" "$opt_user" || return 1
    state_kv_set "install_user_password" "$pw1" || return 1
    state_kv_set "install_user_password_confirm" "$pw2" || return 1

    state_kv_set "install_root_enable" "$opt_root_enable" || return 1
    state_kv_set "install_root_same_as_user" "$opt_same" || return 1
    state_kv_set "install_root_password" "$rp1" || true
    state_kv_set "install_root_password_confirm" "$rp2" || true

    state_kv_set "install_admin_policy" "sudo" || true
}

wizard_screen_storage() {
    ui_section "Armazenamento"

    ui_card "Discos detectados" "$(diskutils_disks_human_table "${install_min_disk_bytes-21474836480}" 2>/dev/null || true)"

    local disk
    disk="$(sanitize_ws "${install_disk-}")"

    local opt_disk
    opt_disk="$(wizard_pick_disk "${disk:-}")"
    opt_disk="$(sanitize_ws "$opt_disk")"
    if [[ -z "$opt_disk" ]]; then
        ui_error "Disco não selecionado."
        return 1
    fi

    if declare -F diskutils_refuse_install_on_media_disk >/dev/null 2>&1; then
        if ! diskutils_refuse_install_on_media_disk "$opt_disk"; then
            ui_error "Disco selecionado parece ser a mídia/ambiente atual."
            return 1
        fi
    fi

    local smart
    smart="$(ui_select "Verificar SMART (opcional)?" "0" "1")"
    smart="$(sanitize_ws "$smart")"
    [[ -z "$smart" ]] && smart="0"

    if [[ "$smart" == "1" ]]; then
        if declare -F diskutils_smart_short_test >/dev/null 2>&1; then
            ui_warn "Executando teste SMART (best-effort)..."
            diskutils_smart_short_test "$opt_disk" "30" || ui_warn "SMART falhou ou não suportado (prosseguindo)."
        fi
    fi

    local wipe
    wipe="$(ui_select "Confirmar WIPE do disco selecionado?" "0" "1")"
    wipe="$(sanitize_ws "$wipe")"
    if [[ "$wipe" != "1" ]]; then
        ui_error "Wipe não confirmado; não é possível prosseguir."
        return 1
    fi

    state_kv_set "install_disk" "$opt_disk" || return 1
    state_kv_set "install_wipe_confirmed" "1" || return 1
}

wizard_screen_zfs() {
    ui_section "ZFS"

    local strategy topo pool comp dedup preset arc_mode arc_max ashift swap_mib
    strategy="$(sanitize_id "${install_zfs_strategy-}")"
    topo="$(sanitize_id "${zfs_topology-}")"
    pool="$(sanitize_ws "${zfs_pool_name-}")"
    comp="$(sanitize_id "${zfs_compression-}")"
    dedup="$(sanitize_id "${zfs_dedup-}")"
    preset="$(sanitize_id "${zfs_dataset_preset-}")"
    arc_mode="$(sanitize_id "${zfs_arc_mode-}")"
    arc_max="$(sanitize_ws "${zfs_arc_max-}")"
    ashift="$(sanitize_ws "${zfs_ashift-}")"
    swap_mib="$(sanitize_ws "${install_swap_mib-0}")"

    local opt_strategy
    opt_strategy="$(ui_select "Tipo de instalação ZFS" "auto" "manual")"
    opt_strategy="$(sanitize_id "$opt_strategy")"
    [[ -z "$opt_strategy" ]] && opt_strategy="${strategy:-auto}"

    if [[ "$opt_strategy" == "manual" ]]; then
        ui_warn "Modo manual registrado. (Implementação manual completa depende do step ZFS manual.)"
    fi

    local opt_pool
    opt_pool="$(wizard_input_text "Nome do pool ZFS" "${pool:-rpool}" '^[A-Za-z][A-Za-z0-9_.:-]{0,47}$')"
    opt_pool="$(sanitize_ws "$opt_pool")"
    [[ -z "$opt_pool" ]] && opt_pool="rpool"

    local opt_topo
    opt_topo="$(ui_select "Topologia do pool" "mirror" "raidz1" "raidz2" "stripe")"
    opt_topo="$(sanitize_id "$opt_topo")"
    [[ -z "$opt_topo" ]] && opt_topo="${topo:-mirror}"

    local opt_comp
    opt_comp="$(ui_select "Compressão" "zstd" "lz4" "lzjb")"
    opt_comp="$(sanitize_id "$opt_comp")"
    [[ -z "$opt_comp" ]] && opt_comp="${comp:-zstd}"

    local opt_dedup
    opt_dedup="$(ui_select "Deduplicação" "0" "1")"
    opt_dedup="$(sanitize_ws "$opt_dedup")"
    [[ -z "$opt_dedup" ]] && opt_dedup="${dedup:-0}"

    if declare -F zfsutils_recommend_dedup_warning >/dev/null 2>&1; then
        if zfsutils_recommend_dedup_warning "$opt_dedup"; then
            ui_warn "Dedup ON aumenta uso de RAM e pode degradar performance."
            if ! ui_confirm "Manter dedup ON mesmo assim?" "Manter" "Desativar"; then
                opt_dedup="0"
            fi
        fi
    fi

    local opt_preset
    opt_preset="$(ui_select "Preset de datasets" "default" "server" "custom")"
    opt_preset="$(sanitize_id "$opt_preset")"
    [[ -z "$opt_preset" ]] && opt_preset="${preset:-default}"

    local opt_ashift
    opt_ashift="$(wizard_input_text "ashift (recomendado 12)" "${ashift:-12}" '^[0-9]+$')"
    opt_ashift="$(sanitize_ws "$opt_ashift")"
    [[ -z "$opt_ashift" ]] && opt_ashift="12"

    local opt_arc_mode
    opt_arc_mode="$(ui_select "ARC máximo" "auto" "custom")"
    opt_arc_mode="$(sanitize_id "$opt_arc_mode")"
    [[ -z "$opt_arc_mode" ]] && opt_arc_mode="${arc_mode:-auto}"

    local opt_arc_max=""
    if [[ "$opt_arc_mode" == "custom" ]]; then
        opt_arc_max="$(wizard_input_text "ARC máximo (ex: 4G ou 4294967296)" "${arc_max:-4G}" '^[0-9]+$|^[0-9]+[KMGTP]$')"
        opt_arc_max="$(sanitize_ws "$opt_arc_max")"
        [[ -z "$opt_arc_max" ]] && opt_arc_max="4G"
    fi

    local opt_swap
    opt_swap="$(wizard_input_text "SWAP (MiB, 0 para desativar)" "${swap_mib:-0}" '^[0-9]+$')"
    opt_swap="$(sanitize_ws "$opt_swap")"
    [[ -z "$opt_swap" ]] && opt_swap="0"

    state_kv_set "install_zfs_strategy" "$opt_strategy" || return 1
    state_kv_set "zfs_topology" "$opt_topo" || return 1
    state_kv_set "zfs_pool_name" "$opt_pool" || return 1
    state_kv_set "zfs_compression" "$opt_comp" || return 1
    state_kv_set "zfs_dedup" "$opt_dedup" || return 1
    state_kv_set "zfs_dataset_preset" "$opt_preset" || return 1
    state_kv_set "zfs_ashift" "$opt_ashift" || return 1
    state_kv_set "zfs_arc_mode" "$opt_arc_mode" || return 1
    state_kv_set "zfs_arc_max" "$opt_arc_max" || true
    state_kv_set "install_swap_mib" "$opt_swap" || return 1
}

wizard_screen_boot() {
    ui_section "Boot"

    local bl cmdline
    bl="$(sanitize_id "${bootloader-}")"
    cmdline="$(sanitize_ws "${kernel_params-}")"

    local opt_bl
    opt_bl="$(ui_select "Bootloader" "grub" "zfsbootmenu" "refind" "none")"
    opt_bl="$(sanitize_id "$opt_bl")"
    [[ -z "$opt_bl" ]] && opt_bl="${bl:-grub}"

    local base_hint
    base_hint="root=ZFS=$(sanitize_ws "${zfs_pool_name-rpool}")/ROOT/debian"
    local opt_cmd
    opt_cmd="$(wizard_input_text "Parâmetros do kernel (opcional)" "${cmdline:-$base_hint}" '^$|^[[:print:]]+$')"
    opt_cmd="$(sanitize_ws "$opt_cmd")"

    state_kv_set "bootloader" "$opt_bl" || return 1
    state_kv_set "kernel_params" "$opt_cmd" || true
}

wizard_screen_summary() {
    ui_section "Resumo"

    state_load || true

    local hn dom lang locale keymap tz ntp ntpsrv ifc method proxy disk pool topo comp dedup preset bl swap_mib
    hn="$(sanitize_ws "${install_hostname-}")"
    dom="$(sanitize_ws "${install_domain-}")"
    lang="$(sanitize_ws "${install_lang-}")"
    locale="$(sanitize_ws "${install_locale-}")"
    keymap="$(sanitize_ws "${install_keymap-}")"
    tz="$(sanitize_ws "${install_tz-}")"
    ntp="$(sanitize_ws "${install_ntp-}")"
    ntpsrv="$(sanitize_ws "${install_ntp_server-}")"
    ifc="$(sanitize_ws "${install_net_iface-}")"
    method="$(sanitize_ws "${install_net_method-}")"
    proxy="$(sanitize_ws "${install_proxy-}")"
    disk="$(sanitize_ws "${install_disk-}")"
    pool="$(sanitize_ws "${zfs_pool_name-}")"
    topo="$(sanitize_ws "${zfs_topology-}")"
    comp="$(sanitize_ws "${zfs_compression-}")"
    dedup="$(sanitize_ws "${zfs_dedup-}")"
    preset="$(sanitize_ws "${zfs_dataset_preset-}")"
    bl="$(sanitize_ws "${bootloader-}")"
    swap_mib="$(sanitize_ws "${install_swap_mib-0}")"

    ui_card "Resumo de Configuração" \
        "  ${UI_BULLET:-•} Host: ${hn}${dom:+.${dom}}" \
        "  ${UI_BULLET:-•} Locale: LANG=${lang} LC_ALL=${locale} Keymap=${keymap}" \
        "  ${UI_BULLET:-•} Time: TZ=${tz} NTP=${ntp} ${ntpsrv:+server=${ntpsrv}}" \
        "  ${UI_BULLET:-•} Rede: iface=${ifc} method=${method} ${proxy:+proxy=${proxy}}" \
        "  ${UI_BULLET:-•} Disco: ${disk}" \
        "  ${UI_BULLET:-•} ZFS: pool=${pool} topo=${topo} comp=${comp} dedup=${dedup} preset=${preset} swap_mib=${swap_mib}" \
        "  ${UI_BULLET:-•} Boot: ${bl}"

    if ! ui_confirm "Confirmar e salvar? (prosseguir para instalação)" "Confirmar" "Voltar"; then
        return 1
    fi
    return 0
}

wizard_input_text() {
    # Args: prompt default regex
    local prompt; prompt="$(sanitize_ws "${1-}")"
    local def; def="$(sanitize_ws "${2-}")"
    local re; re="${3-}"
    local val=""

    if [[ "${NONINTERACTIVE-0}" == "1" ]]; then
        printf '%s' "$def"
        return 0
    fi

    if command -v gum >/dev/null 2>&1; then
        val="$(gum input --prompt "$prompt: " --value "$def" 2>/dev/null || true)"
        val="$(sanitize_ws "$val")"
    else
        stdout "$prompt"
        if [[ -n "$def" ]]; then
            stdout "Padrão: $def"
        fi
        stdout "> "
        IFS= read -r val || true
        val="$(sanitize_ws "$val")"
        [[ -z "$val" ]] && val="$def"
    fi

    if [[ -n "$re" ]]; then
        if ! printf '%s' "$val" | grep -Eq "$re"; then
            printf '%s' ""
            return 0
        fi
    fi
    printf '%s' "$val"
}

wizard_input_secret() {
    # Args: prompt default (ignored for secret)
    local prompt; prompt="$(sanitize_ws "${1-}")"
    local val=""

    if [[ "${NONINTERACTIVE-0}" == "1" ]]; then
        printf '%s' ""
        return 0
    fi

    if command -v gum >/dev/null 2>&1; then
        val="$(gum input --password --prompt "$prompt: " 2>/dev/null || true)"
        val="$(sanitize_ws "$val")"
        printf '%s' "$val"
        return 0
    fi

    stderr "Erro: modo sem gum não suporta input secreto com segurança."
    printf '%s' ""
}

wizard_pick_timezone() {
    # Args: default_tz
    local def; def="$(sanitize_ws "${1-UTC}")"
    local pick

    if [[ "${NONINTERACTIVE-0}" == "1" ]]; then
        printf '%s' "$def"
        return 0
    fi

    if command -v gum >/dev/null 2>&1; then
        pick="$(timeutils_list_timezones | gum filter --placeholder "Buscar timezone..." --limit 1 2>/dev/null || true)"
        pick="$(sanitize_ws "$pick")"
        [[ -z "$pick" ]] && pick="$def"
        printf '%s' "$pick"
        return 0
    fi

    pick="$(wizard_input_text "Timezone (ex: America/Sao_Paulo)" "$def" '^[A-Za-z]+(/[A-Za-z0-9._+-]+)+$')"
    pick="$(sanitize_ws "$pick")"
    [[ -z "$pick" ]] && pick="$def"
    printf '%s' "$pick"
}

wizard_pick_disk() {
    # Args: default_disk
    local def; def="$(sanitize_ws "${1-}")"
    local disks
    disks="$(lsblk -dn -o PATH,TYPE 2>/dev/null | awk '$2=="disk"{print $1}' || true)"
    disks="$(sanitize_ws "$disks")"
    if [[ -z "$disks" ]]; then
        printf '%s' ""
        return 0
    fi

    local choices=()
    local d
    while IFS= read -r d; do
        d="$(sanitize_ws "$d")"
        [[ -z "$d" ]] && continue
        choices+=("$d")
    done <<<"$(printf '%s\n' "$disks")"

    local pick
    pick="$(ui_select "Selecione o disco para instalação" "${choices[@]}")"
    pick="$(sanitize_ws "$pick")"
    [[ -z "$pick" ]] && pick="$def"
    printf '%s' "$pick"
}
