#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

# steps/config_wizard.sh
# Exports: step_config_wizard
# Depends on (lazy-loaded by router):
#   libs/auth-utils.sh libs/net-utils.sh libs/time-utils.sh libs/disk-utils.sh libs/zfs-utils.sh libs/validate-utils.sh
# Uses router-provided: ui_*, state_*, sanitize_*

step_config_wizard() {
    ui_hero "${PROJECT_NAME:-FILESERVER INSTALLER}" "${PROJECT_TAGLINE:-Debian 13 + ZFS on Root}"
    ui_section "Assistente de Configuração"

    if ! declare -F state_load >/dev/null 2>&1; then
        ui_error "State handler ausente."
        return 1
    fi
    if ! declare -F state_kv_set >/dev/null 2>&1; then
        ui_error "State handler ausente (state_kv_set)."
        return 1
    fi
    if ! declare -F ui_select >/dev/null 2>&1; then
        ui_error "UI handler ausente (ui_select)."
        return 1
    fi

    state_load || true

    ui_card "Fluxo" \
        "  ${UI_BULLET:-•} Idioma/Locale" \
        "  ${UI_BULLET:-•} Teclado" \
        "  ${UI_BULLET:-•} Hostname" \
        "  ${UI_BULLET:-•} Rede" \
        "  ${UI_BULLET:-•} Timezone/NTP" \
        "  ${UI_BULLET:-•} Usuários" \
        "  ${UI_BULLET:-•} Disco / ZFS / Bootloader" \
        "" \
        "  ${UI_WARN:-⚠} Alguns valores têm defaults seguros; revise no resumo."

    if ! ui_confirm "Iniciar configuração guiada?" "Iniciar" "Voltar"; then
        return 1
    fi

    wizard_locale || return 1
    wizard_keyboard || return 1
    wizard_hostname || return 1
    wizard_network || return 1
    wizard_time_ntp || return 1
    wizard_users || return 1
    wizard_storage_zfs_boot || return 1
    wizard_install_sources || return 1

    if declare -F validate_all_checkpoint >/dev/null 2>&1; then
        if validate_all_checkpoint; then
            ui_success "Configuração validada."
        else
            ui_warn "Configuração salva, porém há pendências de validação. Revise no 'Resumo'."
        fi
    fi

    ui_success "Assistente concluído."
}

wizard_locale() {
    ui_section "1/8 Idioma e Locale"

    local lang locale
    lang="$(sanitize_ws "${install_lang-pt_BR.UTF-8}")"
    locale="$(sanitize_ws "${install_locale-pt_BR.UTF-8}")"

    local choices_lang
    choices_lang=("pt_BR.UTF-8" "en_US.UTF-8" "es_ES.UTF-8")
    lang="$(ui_select "Selecione LANG (padrão: $lang)" "${choices_lang[@]}")"
    lang="$(sanitize_ws "$lang")"
    [[ -z "$lang" ]] && lang="pt_BR.UTF-8"

    local choices_locale
    choices_locale=("pt_BR.UTF-8" "en_US.UTF-8" "es_ES.UTF-8")
    locale="$(ui_select "Selecione LOCALE (padrão: $locale)" "${choices_locale[@]}")"
    locale="$(sanitize_ws "$locale")"
    [[ -z "$locale" ]] && locale="$lang"

    state_kv_set "install_lang" "$lang" || return 1
    state_kv_set "install_locale" "$locale" || return 1
}

wizard_keyboard() {
    ui_section "2/8 Teclado"

    local keymap
    keymap="$(sanitize_ws "${install_keymap-br}")"

    local choices
    choices=("br" "us" "es")
    keymap="$(ui_select "Selecione keymap (padrão: $keymap)" "${choices[@]}")"
    keymap="$(sanitize_ws "$keymap")"
    [[ -z "$keymap" ]] && keymap="br"

    state_kv_set "install_keymap" "$keymap" || return 1
}

wizard_hostname() {
    ui_section "3/8 Hostname"

    local hn dom
    hn="$(sanitize_ws "${install_hostname-debian-zfs}")"
    dom="$(sanitize_ws "${install_domain-}")"

    if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then
        state_kv_set "install_hostname" "$hn" || return 1
        state_kv_set "install_domain" "$dom" || return 1
        return 0
    fi

    if ui_has_gum >/dev/null 2>&1; then
        hn="$("$GUM_BIN" input --header "Hostname" --value "$hn" 2>/dev/null || true)"
        hn="$(sanitize_ws "$hn")"
        [[ -z "$hn" ]] && hn="debian-zfs"

        dom="$("$GUM_BIN" input --header "Domínio (opcional)" --value "$dom" 2>/dev/null || true)"
        dom="$(sanitize_ws "$dom")"
    else
        stdout "Hostname (padrão: $hn): "
        local x
        IFS= read -r x || true
        x="$(sanitize_ws "$x")"
        [[ -n "$x" ]] && hn="$x"

        stdout "Domínio (opcional, padrão vazio): "
        IFS= read -r x || true
        x="$(sanitize_ws "$x")"
        [[ -n "$x" ]] && dom="$x"
    fi

    state_kv_set "install_hostname" "$hn" || return 1
    state_kv_set "install_domain" "$dom" || return 1
}

wizard_network() {
    ui_section "4/8 Rede"

    local method iface
    method="$(sanitize_id "${install_net_method-dhcp}")"
    iface="$(sanitize_ws "${install_net_iface-}")"

    local ifaces=()
    if declare -F netutils_list_ifaces >/dev/null 2>&1; then
        local line
        while IFS= read -r line; do
            line="$(sanitize_ws "$line")"
            [[ -z "$line" ]] && continue
            ifaces+=("$line")
        done < <(netutils_list_ifaces || true)
    fi
    [[ ${#ifaces[@]} -eq 0 ]] && ifaces=("auto")

    iface="$(ui_select "Interface de rede (padrão: ${iface:-${ifaces[0]}})" "${ifaces[@]}")"
    iface="$(sanitize_ws "$iface")"
    [[ -z "$iface" ]] && iface="${ifaces[0]}"

    local choices_method=("dhcp" "manual")
    method="$(ui_select "Método (DHCP/Manual) (padrão: $method)" "${choices_method[@]}")"
    method="$(sanitize_id "$method")"
    [[ -z "$method" ]] && method="dhcp"

    state_kv_set "install_net_iface" "$iface" || return 1
    state_kv_set "install_net_method" "$method" || return 1

    if [[ "$method" == "manual" ]]; then
        local ip cidr gw dns
        ip="$(sanitize_ws "${install_net_ip-}")"
        cidr="$(sanitize_ws "${install_net_mask-24}")"
        gw="$(sanitize_ws "${install_net_gw-}")"
        dns="$(sanitize_ws "${install_net_dns-1.1.1.1 8.8.8.8}")"

        if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then
            [[ -z "$cidr" ]] && cidr="24"
            [[ -z "$dns" ]] && dns="1.1.1.1 8.8.8.8"
        else
            if ui_has_gum >/dev/null 2>&1; then
                ip="$("$GUM_BIN" input --header "IPv4 (ex: 192.168.1.10)" --value "$ip" 2>/dev/null || true)"
                cidr="$("$GUM_BIN" input --header "CIDR (0-32)" --value "$cidr" 2>/dev/null || true)"
                gw="$("$GUM_BIN" input --header "Gateway (ex: 192.168.1.1)" --value "$gw" 2>/dev/null || true)"
                dns="$("$GUM_BIN" input --header "DNS (space-separated)" --value "$dns" 2>/dev/null || true)"
            else
                stdout "IPv4: "
                IFS= read -r ip || true
                stdout "CIDR (0-32): "
                IFS= read -r cidr || true
                stdout "Gateway: "
                IFS= read -r gw || true
                stdout "DNS (space-separated): "
                IFS= read -r dns || true
            fi
        fi

        ip="$(sanitize_ws "$ip")"
        cidr="$(sanitize_ws "$cidr")"
        gw="$(sanitize_ws "$gw")"
        dns="$(sanitize_ws "$dns")"
        [[ -z "$cidr" ]] && cidr="24"

        state_kv_set "install_net_ip" "$ip" || return 1
        state_kv_set "install_net_mask" "$cidr" || return 1
        state_kv_set "install_net_gw" "$gw" || return 1
        state_kv_set "install_net_dns" "$dns" || return 1
    else
        state_kv_set "install_net_ip" "" || true
        state_kv_set "install_net_mask" "" || true
        state_kv_set "install_net_gw" "" || true
        state_kv_set "install_net_dns" "" || true
    fi

    local proxy
    proxy="$(sanitize_ws "${install_proxy-}")"
    local set_proxy
    if ui_confirm "Configurar proxy APT (opcional)?" "Sim" "Não"; then
        if [[ "${NONINTERACTIVE:-0}" == "1" ]]; then
            :
        else
            if ui_has_gum >/dev/null 2>&1; then
                proxy="$("$GUM_BIN" input --header "Proxy (ex: http://proxy:3128)" --value "$proxy" 2>/dev/null || true)"
            else
                stdout "Proxy: "
                IFS= read -r proxy || true
            fi
        fi
        set_proxy="1"
    else
        set_proxy="0"
    fi
    proxy="$(sanitize_ws "$proxy")"
    if [[ "$set_proxy" == "0" ]]; then
        proxy=""
    fi
    state_kv_set "install_proxy" "$proxy" || return 1
}

wizard_time_ntp() {
    ui_section "5/8 Timezone e NTP"

    local tz ntp ntp_server
    tz="$(sanitize_ws "${install_tz-UTC}")"
    ntp="$(sanitize_ws "${install_ntp-1}")"
    ntp_server="$(sanitize_ws "${install_ntp_server-pool.ntp.org}")"

    if declare -F timeutils_list_timezones >/dev/null 2>&1; then
        local tzs=()
        local line
        local count=0
        while IFS= read -r line; do
            line="$(sanitize_ws "$line")"
            [[ -z "$line" ]] && continue
            tzs+=("$line")
            count=$((count + 1))
            [[ "$count" -ge 50 ]] && break
        done < <(timeutils_list_timezones || true)

        if [[ ${#tzs[@]} -gt 0 ]]; then
            tz="$(ui_select "Selecione Timezone (lista parcial; padrão: $tz)" "${tzs[@]}")"
            tz="$(sanitize_ws "$tz")"
            [[ -z "$tz" ]] && tz="${install_tz-UTC}"
        fi
    fi
    [[ -z "$tz" ]] && tz="UTC"

    local ntp_choices=("1" "0")
    ntp="$(ui_select "Ativar NTP? (1=Sim,0=Não) (padrão: $ntp)" "${ntp_choices[@]}")"
    ntp="$(sanitize_ws "$ntp")"
    [[ "$ntp" != "0" && "$ntp" != "1" ]] && ntp="1"

    if [[ "$ntp" == "1" ]]; then
        if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
            if ui_has_gum >/dev/null 2>&1; then
                ntp_server="$("$GUM_BIN" input --header "Servidor NTP" --value "$ntp_server" 2>/dev/null || true)"
            else
                stdout "Servidor NTP (padrão: $ntp_server): "
                local x
                IFS= read -r x || true
                x="$(sanitize_ws "$x")"
                [[ -n "$x" ]] && ntp_server="$x"
            fi
        fi
        ntp_server="$(sanitize_ws "$ntp_server")"
        [[ -z "$ntp_server" ]] && ntp_server="pool.ntp.org"
    else
        ntp_server=""
    fi

    state_kv_set "install_tz" "$tz" || return 1
    state_kv_set "install_ntp" "$ntp" || return 1
    state_kv_set "install_ntp_server" "$ntp_server" || return 1
}

wizard_users() {
    ui_section "6/8 Usuários e Senhas"

    local fullname username
    fullname="$(sanitize_ws "${install_user_fullname-}")"
    username="$(sanitize_id "${install_username-}")"

    local user_pw user_pw2
    user_pw="${install_user_password-}"
    user_pw2="${install_user_password_confirm-}"

    if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
        if ui_has_gum >/dev/null 2>&1; then
            fullname="$("$GUM_BIN" input --header "Nome completo" --value "$fullname" 2>/dev/null || true)"
            username="$("$GUM_BIN" input --header "Nome de usuário (linux)" --value "$username" 2>/dev/null || true)"
        else
            stdout "Nome completo: "
            IFS= read -r fullname || true
            stdout "Nome de usuário: "
            IFS= read -r username || true
        fi
    fi

    fullname="$(sanitize_ws "$fullname")"
    username="$(sanitize_id "$username")"
    [[ -z "$username" ]] && username="admin"
    [[ -z "$fullname" ]] && fullname="Administrator"

    if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
        if ui_has_gum >/dev/null 2>&1; then
            user_pw="$("$GUM_BIN" input --password --header "Senha do usuário" 2>/dev/null || true)"
            user_pw2="$("$GUM_BIN" input --password --header "Confirmar senha do usuário" 2>/dev/null || true)"
        else
            stdout "Senha do usuário: "
            IFS= read -r user_pw || true
            stdout "Confirmar senha: "
            IFS= read -r user_pw2 || true
        fi
    fi

    user_pw="$(sanitize_ws "$user_pw")"
    user_pw2="$(sanitize_ws "$user_pw2")"

    if declare -F authutils_password_validate_all >/dev/null 2>&1; then
        authutils_password_validate_all "$user_pw" "$username" "$(sanitize_ws "${install_hostname-}")" || { ui_error "Senha do usuário não atende política."; return 1; }
    fi
    if [[ "$user_pw" != "$user_pw2" ]]; then
        ui_error "Senha do usuário não confere."
        return 1
    fi

    state_kv_set "install_user_fullname" "$fullname" || return 1
    state_kv_set "install_username" "$username" || return 1
    state_kv_set "install_user_password" "$user_pw" || return 1
    state_kv_set "install_user_password_confirm" "$user_pw2" || return 1

    local root_enable same_root
    root_enable="$(sanitize_ws "${install_root_enable-0}")"
    same_root="$(sanitize_ws "${install_root_same_as_user-0}")"

    local root_choices=("0" "1")
    root_enable="$(ui_select "Criar/Ativar conta root? (1=Sim,0=Não) (padrão: $root_enable)" "${root_choices[@]}")"
    root_enable="$(sanitize_ws "$root_enable")"
    [[ "$root_enable" != "0" && "$root_enable" != "1" ]] && root_enable="0"

    same_root="0"
    if [[ "$root_enable" == "1" ]]; then
        if ui_confirm "Usar a MESMA senha do usuário para root?" "Usar mesma" "Definir outra"; then
            same_root="1"
        fi
    fi
    state_kv_set "install_root_enable" "$root_enable" || return 1
    state_kv_set "install_root_same_as_user" "$same_root" || return 1

    if [[ "$root_enable" == "1" && "$same_root" == "0" ]]; then
        local root_pw root_pw2
        root_pw="${install_root_password-}"
        root_pw2="${install_root_password_confirm-}"

        if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
            if ui_has_gum >/dev/null 2>&1; then
                root_pw="$("$GUM_BIN" input --password --header "Senha do root" 2>/dev/null || true)"
                root_pw2="$("$GUM_BIN" input --password --header "Confirmar senha do root" 2>/dev/null || true)"
            else
                stdout "Senha do root: "
                IFS= read -r root_pw || true
                stdout "Confirmar senha do root: "
                IFS= read -r root_pw2 || true
            fi
        fi

        root_pw="$(sanitize_ws "$root_pw")"
        root_pw2="$(sanitize_ws "$root_pw2")"

        if declare -F authutils_password_validate_all >/dev/null 2>&1; then
            authutils_password_validate_all "$root_pw" "root" "$(sanitize_ws "${install_hostname-}")" || { ui_error "Senha do root não atende política."; return 1; }
        fi
        if [[ "$root_pw" != "$root_pw2" ]]; then
            ui_error "Senha do root não confere."
            return 1
        fi

        state_kv_set "install_root_password" "$root_pw" || return 1
        state_kv_set "install_root_password_confirm" "$root_pw2" || return 1
    else
        state_kv_set "install_root_password" "" || true
        state_kv_set "install_root_password_confirm" "" || true
    fi
}

wizard_storage_zfs_boot() {
    ui_section "7/8 Armazenamento + ZFS + Boot"

    if ! declare -F diskutils_list_disks >/dev/null 2>&1; then
        ui_error "disk-utils.sh não carregado."
        return 1
    fi

    local disks=()
    local line
    while IFS= read -r line; do
        line="$(sanitize_ws "$line")"
        [[ -z "$line" ]] && continue
        disks+=("$line")
    done < <(diskutils_list_disks || true)

    if [[ ${#disks[@]} -eq 0 ]]; then
        ui_error "Nenhum disco detectado."
        return 1
    fi

    local disk
    disk="$(sanitize_ws "${install_disk-}")"
    local pick
    pick="$(ui_select "Selecione o DISCO de destino (DESTRUTIVO) (padrão: ${disk:-${disks[0]}})" "${disks[@]}")"
    pick="$(sanitize_ws "$pick")"
    [[ -z "$pick" ]] && pick="${disks[0]}"
    disk="$pick"

    ui_card "Confirmação de wipe" \
        "  ${UI_WARN:-⚠} O disco será APAGADO (GPT/ZFS)." \
        "  ${UI_BULLET:-•} Disco: $disk"

    local wipe="0"
    if ui_confirm "Confirmar WIPE completo do disco selecionado?" "Confirmar" "Cancelar"; then
        wipe="1"
    fi
    if [[ "$wipe" != "1" ]]; then
        ui_error "Wipe não confirmado."
        return 1
    fi

    state_kv_set "install_disk" "$disk" || return 1
    state_kv_set "install_wipe_confirmed" "$wipe" || return 1

    local strategy topo pool comp dedup arc_mode arc_max preset ashift
    strategy="$(sanitize_id "${install_zfs_strategy-auto}")"
    topo="$(sanitize_id "${zfs_topology-mirror}")"
    pool="$(sanitize_ws "${zfs_pool_name-rpool}")"
    comp="$(sanitize_id "${zfs_compression-zstd}")"
    dedup="$(sanitize_id "${zfs_dedup-0}")"
    arc_mode="$(sanitize_id "${zfs_arc_mode-auto}")"
    arc_max="$(sanitize_ws "${zfs_arc_max-}")"
    preset="$(sanitize_id "${zfs_dataset_preset-default}")"

    if declare -F diskid_recommend_ashift >/dev/null 2>&1; then
        ashift="$(sanitize_ws "$(diskid_recommend_ashift "$disk" || true)")"
    else
        ashift="$(sanitize_ws "${zfs_ashift-12}")"
    fi
    [[ -z "$ashift" ]] && ashift="12"

    local strategy_choices=("auto" "manual")
    strategy="$(ui_select "Modo ZFS (padrão: $strategy)" "${strategy_choices[@]}")"
    strategy="$(sanitize_id "$strategy")"
    [[ -z "$strategy" ]] && strategy="auto"

    local topo_choices=("stripe" "mirror" "raidz1" "raidz2" "raidz3")
    topo="$(ui_select "Topologia (padrão: $topo)" "${topo_choices[@]}")"
    topo="$(sanitize_id "$topo")"
    [[ -z "$topo" ]] && topo="mirror"

    if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
        if ui_has_gum >/dev/null 2>&1; then
            pool="$("$GUM_BIN" input --header "Nome do pool (padrão: $pool)" --value "$pool" 2>/dev/null || true)"
        else
            stdout "Nome do pool (padrão: $pool): "
            local x
            IFS= read -r x || true
            x="$(sanitize_ws "$x")"
            [[ -n "$x" ]] && pool="$x"
        fi
    fi
    pool="$(sanitize_ws "$pool")"
    [[ -z "$pool" ]] && pool="rpool"

    local comp_choices=("zstd" "lz4" "lzjb")
    comp="$(ui_select "Compressão (padrão: $comp)" "${comp_choices[@]}")"
    comp="$(sanitize_id "$comp")"
    [[ -z "$comp" ]] && comp="zstd"

    local dedup_choices=("0" "1")
    dedup="$(ui_select "Deduplicação (padrão: $dedup) (⚠ recomendação: 0)" "${dedup_choices[@]}")"
    dedup="$(sanitize_id "$dedup")"
    [[ "$dedup" != "0" && "$dedup" != "1" ]] && dedup="0"

    local arc_choices=("auto" "custom")
    arc_mode="$(ui_select "ARC máximo (auto/custom) (padrão: $arc_mode)" "${arc_choices[@]}")"
    arc_mode="$(sanitize_id "$arc_mode")"
    [[ -z "$arc_mode" ]] && arc_mode="auto"

    if [[ "$arc_mode" == "custom" ]]; then
        if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
            if ui_has_gum >/dev/null 2>&1; then
                arc_max="$("$GUM_BIN" input --header "ARC max (bytes ou sufixo K/M/G/T/P, ex: 8G)" --value "${arc_max:-8G}" 2>/dev/null || true)"
            else
                stdout "ARC max (bytes ou K/M/G...): "
                IFS= read -r arc_max || true
            fi
        fi
        arc_max="$(sanitize_ws "$arc_max")"
        [[ -z "$arc_max" ]] && arc_max="8G"
    else
        arc_max=""
    fi

    local preset_choices=("default" "server" "custom")
    preset="$(ui_select "Preset de datasets (padrão: $preset)" "${preset_choices[@]}")"
    preset="$(sanitize_id "$preset")"
    [[ -z "$preset" ]] && preset="default"

    state_kv_set "install_zfs_strategy" "$strategy" || return 1
    state_kv_set "zfs_topology" "$topo" || return 1
    state_kv_set "zfs_pool_name" "$pool" || return 1
    state_kv_set "zfs_compression" "$comp" || return 1
    state_kv_set "zfs_dedup" "$dedup" || return 1
    state_kv_set "zfs_arc_mode" "$arc_mode" || return 1
    state_kv_set "zfs_arc_max" "$arc_max" || return 1
    state_kv_set "zfs_dataset_preset" "$preset" || return 1
    state_kv_set "zfs_ashift" "$ashift" || return 1

    local swap_mib
    swap_mib="$(sanitize_ws "${install_swap_mib-0}")"
    local swap_choices=("0" "2048" "4096" "8192" "16384")
    swap_mib="$(ui_select "SWAP MiB (0=desabilitar) (padrão: $swap_mib)" "${swap_choices[@]}")"
    swap_mib="$(sanitize_ws "$swap_mib")"
    [[ -z "$swap_mib" ]] && swap_mib="0"
    state_kv_set "install_swap_mib" "$swap_mib" || return 1

    local boot_choices=("grub" "refind" "zfsbootmenu" "none")
    local bootloader
    bootloader="$(sanitize_id "${bootloader-grub}")"
    bootloader="$(ui_select "Bootloader (padrão: $bootloader)" "${boot_choices[@]}")"
    bootloader="$(sanitize_id "$bootloader")"
    [[ -z "$bootloader" ]] && bootloader="grub"
    state_kv_set "bootloader" "$bootloader" || return 1

    local kparams
    kparams="$(sanitize_ws "${kernel_params-}")"
    if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
        if ui_has_gum >/dev/null 2>&1; then
            kparams="$("$GUM_BIN" input --header "Parâmetros do kernel (opcional)" --value "$kparams" 2>/dev/null || true)"
        else
            stdout "Parâmetros do kernel (opcional): "
            IFS= read -r kparams || true
        fi
    fi
    kparams="$(sanitize_ws "$kparams")"
    state_kv_set "kernel_params" "$kparams" || return 1
}

wizard_install_sources() {
    ui_section "8/8 Repositórios (APT) e Suite"

    local suite mirror
    suite="$(sanitize_ws "${install_suite-stable}")"
    mirror="$(sanitize_ws "${install_mirror-http://deb.debian.org/debian}")"

    local suite_choices=("stable" "testing" "bookworm" "trixie")
    suite="$(ui_select "Suite (padrão: $suite)" "${suite_choices[@]}")"
    suite="$(sanitize_ws "$suite")"
    [[ -z "$suite" ]] && suite="stable"

    if [[ "${NONINTERACTIVE:-0}" != "1" ]]; then
        if ui_has_gum >/dev/null 2>&1; then
            mirror="$("$GUM_BIN" input --header "Mirror (padrão: $mirror)" --value "$mirror" 2>/dev/null || true)"
        else
            stdout "Mirror (padrão: $mirror): "
            local x
            IFS= read -r x || true
            x="$(sanitize_ws "$x")"
            [[ -n "$x" ]] && mirror="$x"
        fi
    fi
    mirror="$(sanitize_ws "$mirror")"
    [[ -z "$mirror" ]] && mirror="http://deb.debian.org/debian"

    local retries timeout
    retries="$(sanitize_ws "${install_apt_retries-5}")"
    timeout="$(sanitize_ws "${install_apt_timeout-30}")"

    local retries_choices=("3" "5" "10")
    retries="$(ui_select "APT retries (padrão: $retries)" "${retries_choices[@]}")"
    retries="$(sanitize_ws "$retries")"
    [[ -z "$retries" ]] && retries="5"

    local timeout_choices=("15" "30" "60")
    timeout="$(ui_select "APT timeout (padrão: $timeout)" "${timeout_choices[@]}")"
    timeout="$(sanitize_ws "$timeout")"
    [[ -z "$timeout" ]] && timeout="30"

    state_kv_set "install_suite" "$suite" || return 1
    state_kv_set "install_mirror" "$mirror" || return 1
    state_kv_set "install_apt_retries" "$retries" || return 1
    state_kv_set "install_apt_timeout" "$timeout" || return 1
}
