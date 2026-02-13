# Integração Opencode com Antigravity Auth

## Visão Geral

O projeto build-iso agora inclui integração com o plugin **opencode-google-antigravity-auth**, que permite usar modelos Gemini do Google Cloud via autenticação OAuth Antigravity.

## Localização

- **Diretório do Plugin:** `.opencode/opencode-google-antigravity-auth/`
- **Documentação de Integração:** `.opencode/opencode-google-antigravity-auth/README-INTEGRACAO.md`

## Dependências

### Sistema

- **Bun** (Runtime JavaScript)
- **Node.js** (^18.0.0)
- **TypeScript** (^5.9.3)

### NPM

```json
{
  "@openauthjs/openauth": "^0.4.3",
  "@opencode-ai/plugin": "^1.0.182",
  "open": "^11.0.0"
}
```

## Configuração Rápida

### 1. Instalar Dependências

```bash
cd .opencode/opencode-google-antigravity-auth
bun install
```

### 2. Configurar Opencode

Crie ou edite `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-google-antigravity-auth"]
}
```

### 3. Autenticar

```bash
opencode auth login
```

Selecione **OAuth with Google (Antigravity)** e complete a autenticação no navegador.

## Modelos Disponíveis

| Modelo                              | Descrição                     | Reasoning |
| ----------------------------------- | ----------------------------- | --------- |
| `gemini-3-pro-preview`              | Gemini 3 Pro                  | ✅        |
| `gemini-3-flash`                    | Gemini 3 Flash                | ✅        |
| `gemini-2.5-flash-lite`             | Gemini 2.5 Flash Lite         | ❌        |
| `gemini-claude-sonnet-4-5-thinking` | Claude Sonnet via Antigravity | ✅        |
| `gemini-claude-opus-4-5-thinking`   | Claude Opus via Antigravity   | ✅        |

## Uso no build-iso

### Exemplos de Comandos

```bash
# Gemini Flash para consultas rápidas
opencode run -m google/gemini-2.5-flash -p "Liste os datasets ZFS recomendados"

# Gemini Pro para tarefas complexas
opencode run -m google/gemini-3-pro-high -p "Crie um script de instalação ZFS automatizado"

# Claude Sonnet via proxy
opencode run -m google/gemini-claude-sonnet-4-5-thinking -p "Revise e otimize este código"
```

## Recursos do Plugin

- **Balanceamento de Carga:** Suporta múltiplas contas Google
- **Fallback de Endpoints:** daily → autopush → prod
- **Busca Google:** Ferramenta `google_search` integrada
- **Thinking Blocks:** Suporte a raciocínio estendido
- **Cross-Model Conversations:** Troca entre Claude e Gemini

## Documentação

Consulte `.opencode/opencode-google-antigravity-auth/README.md` para documentação completa do plugin.

## Links Úteis

- **Repositório Original:** https://github.com/shekohex/opencode-google-antigravity-auth
- **Documentação Antigravity:** https://antigravity.app/
- **Opencode Docs:** https://opencode.ai/docs/config/

## Atualização

Para atualizar o plugin:

```bash
rm -rf ~/.cache/opencode/node_modules/opencode-google-antigravity-auth
opencode
```

---

_Integração adicionada: 2026-02-09_
