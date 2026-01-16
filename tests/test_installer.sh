#!/usr/bin/env bash
# test_installer.sh - Testes automatizados do instalador DEBIAN_ZFS
# Fase 9 do Roadmap: Qualidade e Testes

set -euo pipefail

readonly INSTALLER="include/usr/local/bin/installer/install-system"
readonly SCRIPT_NAME="DEBIAN_ZFS Test Suite"

echo "=== ${SCRIPT_NAME} ==="
echo ""

# Contador de testes
TESTS_PASSED=0
TESTS_FAILED=0

# Função para reportar resultado
report_test() {
	local test_name="$1"
	local result="$2"
	local details="${3-}"

	if [[ ${result} == "PASS" ]]; then
		echo "[PASS] ${test_name}"
		((TESTS_PASSED++))
	else
		echo "[FAIL] ${test_name}"
		if [[ -n ${details} ]]; then
			echo "       ${details}"
		fi
		((TESTS_FAILED++))
	fi
}

# Teste 1: Presença do instalador
echo "## Teste 1: Presença do Instalador"
if [[ -f ${INSTALLER} ]]; then
	report_test "Arquivo do instalador existe" "PASS"
else
	report_test "Arquivo do instalador existe" "FAIL" "Arquivo não encontrado:$$$$$$$$${$}I}N}S}T}A}L}L}E}R"
	exit 1
fi

# Teste 2: Permissões
echo "## Teste 2: Permissões do Instalador"
if [[ -x ${INSTALLER} ]]; then
	report_test "Instalador é executável" "PASS"
else
	report_test "Instalador é executável" "FAIL" "Permissão de execução não definida"
fi

# Teste 3: Shebang correto
echo "## Teste 3: Shebang e Configurações"
if head -1 "${INSTALLER}" | grep -q "#!/usr/bin/env bash"; then
	report_test "Shebang correto" "PASS"
else
	report_test "Shebang correto" "FAIL" "Shebang deve ser '#!/usr/bin/env bash'"
fi

if grep -q "set -euo pipefail" "${INSTALLER}"; then
	report_test "Configuração segura (set -euo pipefail)" "PASS"
else
	report_test "Configuração segura (set -euo pipefail)" "FAIL" "Falta configuração segura"
fi

# Teste 4: Módulos Implementados
echo "## Teste 4: Módulos Implementados"

# Fase 1: Infraestrutura Base
if grep -q "^log()" "${INSTALLER}"; then
	report_test "Fase 1: Módulo de logging implementado" "PASS"
else
	report_test "Fase 1: Módulo de logging implementado" "FAIL"
fi

if grep -q "^cleanup()" "${INSTALLER}"; then
	report_test "Fase 1: Função de cleanup implementada" "PASS"
else
	report_test "Fase 1: Função de cleanup implementada" "FAIL"
fi

if grep -q "^preflight_checks()" "${INSTALLER}"; then
	report_test "Fase 1: Verificações de pré-requisitos implementadas" "PASS"
else
	report_test "Fase 1: Verificações de pré-requisitos implementadas" "FAIL"
fi

# Fase 2: Interface TUI
if grep -q "^welcome_screen()" "${INSTALLER}"; then
	report_test "Fase 2: Tela de boas-vindas implementada" "PASS"
else
	report_test "Fase 2: Tela de boas-vindas implementada" "FAIL"
fi

if grep -q "^select_disks()" "${INSTALLER}"; then
	report_test "Fase 2: Seleção de discos implementada" "PASS"
else
	report_test "Fase 2: Seleção de discos implementada" "FAIL"
fi

if grep -q "^select_topology()" "${INSTALLER}"; then
	report_test "Fase 2: Seleção de topologia RAID implementada" "PASS"
else
	report_test "Fase 2: Seleção de topologia RAID implementada" "FAIL"
fi

if grep -q "^configure_zfs_options()" "${INSTALLER}"; then
	report_test "Fase 2: Configuração de opções ZFS implementada" "PASS"
else
	report_test "Fase 2: Configuração de opções ZFS implementada" "FAIL"
fi

if grep -q "^collect_info()" "${INSTALLER}"; then
	report_test "Fase 2: Coleta de informações do usuário implementada" "PASS"
else
	report_test "Fase 2: Coleta de informações do usuário implementada" "FAIL"
fi

if grep -q "^confirm_installation()" "${INSTALLER}"; then
	report_test "Fase 2: Confirmação de instalação implementada" "PASS"
else
	report_test "Fase 2: Confirmação de instalação implementada" "FAIL"
fi

# Fase 3: Preparação do Disco
if grep -q "^prepare_disks()" "${INSTALLER}"; then
	report_test "Fase 3: Preparação de discos implementada" "PASS"
else
	report_test "Fase 3: Preparação de discos implementada" "FAIL"
fi

if grep -q "wipefs" "${INSTALLER}"; then
	report_test "Fase 3: Uso de wipefs confirmado" "PASS"
else
	report_test "Fase 3: Uso de wipefs confirmado" "FAIL"
fi

if grep -q "sgdisk" "${INSTALLER}"; then
	report_test "Fase 3: Uso de sgdisk confirmado" "PASS"
else
	report_test "Fase 3: Uso de sgdisk confirmado" "FAIL"
fi

# Fase 4: Configuração ZFS
if grep -q "^create_pool()" "${INSTALLER}"; then
	report_test "Fase 4: Criação de pool ZFS implementada" "PASS"
else
	report_test "Fase 4: Criação de pool ZFS implementada" "FAIL"
fi

if grep -q "^create_datasets()" "${INSTALLER}"; then
	report_test "Fase 4: Criação de datasets implementada" "PASS"
else
	report_test "Fase 4: Criação de datasets implementada" "FAIL"
fi

# Verificar suporte a topologias
if grep -q "mirror" "${INSTALLER}" && grep -q "raidz1" "${INSTALLER}"; then
	report_test "Fase 4: Suporte a múltiplas topologias RAID" "PASS"
else
	report_test "Fase 4: Suporte a múltiplas topologias RAID" "FAIL"
fi

# Verificar opções ZFS avançadas
if grep -q "ashift" "${INSTALLER}" && grep -q "compression" "${INSTALLER}"; then
	report_test "Fase 4: Opções ZFS avançadas (ashift, compression)" "PASS"
else
	report_test "Fase 4: Opções ZFS avançadas (ashift, compression)" "FAIL"
fi

# Fase 5: Extração do Sistema
if grep -q "^extract_system()" "${INSTALLER}"; then
	report_test "Fase 5: Extração do sistema implementada" "PASS"
else
	report_test "Fase 5: Extração do sistema implementada" "FAIL"
fi

if grep -q "unsquashfs" "${INSTALLER}"; then
	report_test "Fase 5: Uso de unsquashfs confirmado" "PASS"
else
	report_test "Fase 5: Uso de unsquashfs confirmado" "FAIL"
fi

# Fase 6: Configuração Chroot
if grep -q "^configure_hostname()" "${INSTALLER}"; then
	report_test "Fase 6: Configuração de hostname implementada" "PASS"
else
	report_test "Fase 6: Configuração de hostname implementada" "FAIL"
fi

if grep -q "^configure_users()" "${INSTALLER}"; then
	report_test "Fase 6: Configuração de usuários implementada" "PASS"
else
	report_test "Fase 6: Configuração de usuários implementada" "FAIL"
fi

if grep -q "^configure_locales()" "${INSTALLER}"; then
	report_test "Fase 6: Configuração de locales implementada" "PASS"
else
	report_test "Fase 6: Configuração de locales implementada" "FAIL"
fi

if grep -q "^generate_hostid()" "${INSTALLER}"; then
	report_test "Fase 6: Geração de hostid implementada" "PASS"
else
	report_test "Fase 6: Geração de hostid implementada" "FAIL"
fi

# Fase 7: ZFSBootMenu
if grep -q "^format_esp()" "${INSTALLER}"; then
	report_test "Fase 7: Formatação de ESP implementada" "PASS"
else
	report_test "Fase 7: Formatação de ESP implementada" "FAIL"
fi

if grep -q "^copy_zbm_binaries()" "${INSTALLER}"; then
	report_test "Fase 7: Cópia de binários ZFSBootMenu implementada" "PASS"
else
	report_test "Fase 7: Cópia de binários ZFSBootMenu implementada" "FAIL"
fi

if grep -q "^configure_efi()" "${INSTALLER}"; then
	report_test "Fase 7: Configuração EFI implementada" "PASS"
else
	report_test "Fase 7: Configuração EFI implementada" "FAIL"
fi

# Verificar se ZFSBootMenu é usado (não GRUB)
if ! grep -q "grub-install\|update-grub" "${INSTALLER}"; then
	report_test "Fase 7: Não usa GRUB (usa ZFSBootMenu)" "PASS"
else
	report_test "Fase 7: Não usa GRUB (usa ZFSBootMenu)" "FAIL"
fi

# Fase 8: Finalização
if grep -q "^create_snapshot()" "${INSTALLER}"; then
	report_test "Fase 8: Criação de snapshot implementada" "PASS"
else
	report_test "Fase 8: Criação de snapshot implementada" "FAIL"
fi

if grep -q "^unmount_all()" "${INSTALLER}"; then
	report_test "Fase 8: Desmontagem de filesystems implementada" "PASS"
else
	report_test "Fase 8: Desmontagem de filesystems implementada" "FAIL"
fi

if grep -q "^success_message()" "${INSTALLER}"; then
	report_test "Fase 8: Mensagem de sucesso implementada" "PASS"
else
	report_test "Fase 8: Mensagem de sucesso implementada" "FAIL"
fi

# Teste 5: Validação de sintaxe
echo "## Teste 5: Validação de Sintaxe"

if bash -n "${INSTALLER}" 2>/dev/null; then
	report_test "Sintaxe Bash válida (bash -n)" "PASS"
else
	report_test "Sintaxe Bash válida (bash -n)" "FAIL"
fi

if command -v shellcheck >/dev/null 2>&1; then
	if shellcheck "${INSTALLER}" 2>&1 | grep -q "SC"; then
		report_test "Shellcheck sem warnings" "FAIL" "Shellcheck encontrou warnings"
	else
		report_test "Shellcheck sem warnings" "PASS"
	fi
else
	echo "[SKIP] Shellcheck não instalado"
fi

# Teste 6: Interface Gum
echo "## Teste 6: Interface TUI"

if grep -q "gum" "${INSTALLER}"; then
	report_test "Interface Gum implementada" "PASS"
else
	report_test "Interface Gum implementada" "FAIL"
fi

if grep -q "gum confirm\|gum choose\|gum input\|gum format" "${INSTALLER}"; then
	report_test "Funções Gum utilizadas" "PASS"
else
	report_test "Funções Gum utilizadas" "FAIL"
fi

# Teste 7: Variáveis globais
echo "## Teste 7: Variáveis Globais"

if grep -q "readonly.*POOL_NAME" "${INSTALLER}"; then
	report_test "Variável POOL_NAME definida" "PASS"
else
	report_test "Variável POOL_NAME definida" "FAIL"
fi

if grep -q "readonly.*MOUNT_POINT" "${INSTALLER}"; then
	report_test "Variável MOUNT_POINT definida" "PASS"
else
	report_test "Variável MOUNT_POINT definida" "FAIL"
fi

# Teste 8: Logging
echo "## Teste 8: Sistema de Logging"

if grep -q "LOG_FILE" "${INSTALLER}"; then
	report_test "Arquivo de log configurado" "PASS"
else
	report_test "Arquivo de log configurado" "FAIL"
fi

if grep -q "error_exit()" "${INSTALLER}"; then
	report_test "Função de erro implementada" "PASS"
else
	report_test "Função de erro implementada" "FAIL"
fi

# Teste 9: Hierarquia de Datasets
echo "## Teste 9: Hierarquia de Datasets"

expected_datasets=(
	"ROOT/debian"
	"home"
	"var/log"
	"var/cache"
	"var/tmp"
)

for dataset in "${expected_datasets[@]}"; do
	if grep -q "\"${POOL_NAME}/${dataset}\"" "${INSTALLER}"; then
		report_test "Dataset ${dataset} criado" "PASS"
	else
		report_test "Dataset ${dataset} criado" "FAIL"
	fi
done

# Teste 10: Decisões de Design
echo "## Teste 10: Decisões de Design"

# Unsquashfs (não rsync para extração principal)
if grep -q "unsquashfs.*-f.*-d" "${INSTALLER}"; then
	report_test "Decisão: Usa unsquashfs (não rsync) para extração" "PASS"
else
	report_test "Decisão: Usa unsquashfs (não rsync) para extração" "FAIL"
fi

# Instalação offline (não debootstrap)
if ! grep -q "debootstrap.*install" "${INSTALLER}"; then
	report_test "Decisão: Instalação offline (não debootstrap)" "PASS"
else
	report_test "Decisão: Instalação offline (não debootstrap)" "FAIL"
fi

# ZFSBootMenu (não GRUB)
if grep -q "zfsbootmenu\|ZBM\|VMLINUZ.EFI" "${INSTALLER}"; then
	report_test "Decisão: Usa ZFSBootMenu (não GRUB)" "PASS"
else
	report_test "Decisão: Usa ZFSBootMenu (não GRUB)" "FAIL"
fi

# Relatório final
echo ""
echo "=== Resumo dos Testes ==="
echo "Total de testes: $((TESTS_PASSED + TESTS_FAILED))"
echo "Testes passados: ${TESTS_PASSED}"
echo "Testes falhados: ${TESTS_FAILED}"
echo ""

if [[ ${TESTS_FAILED} -eq 0 ]]; then
	echo "✅ Todos os testes passaram!"
	exit 0
else
	echo "❌ Alguns testes falharam."
	exit 1
fi
