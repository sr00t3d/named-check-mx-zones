# Check MX Zones in NAMED

Readme: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/named-check-mx-zones) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="named-check-mx-zones-cover.webp" />

Um script Bash moderno projetado para administradores de sistemas e equipes DevOps validarem arquivos de zona DNS locais (BIND/Named em cPanel, DirectAdmin ou servidores dedicados) contra consultas reais em servidores de nomes autoritativos ou recursivos.

O script analisa os arquivos de zona (`.db`), consulta os nameservers configurados, faz validação cruzada para detectar divergências de propagação ou desync, suporta verificação de registro de domínio via WHOIS e classifica o status de forma granular.

## 🚀 Funcionalidades (v1.1.0)

* **Auto-detecção de Nameservers:** Detecta automaticamente os nameservers em `/etc/nameserverips` (cPanel) ou `/etc/resolv.conf`, com fallback inteligente para `1.1.1.1` e `8.8.8.8`.
* **Argumentos de Linha de Comando:** Configure diretório, servidores DNS, timeout e filtros diretamente via flags no terminal sem precisar editar o código.
* **Consistência de MX & Status Detalhado:**
  * `OK`: Registro MX sincronizado entre os nameservers e compatível com a configuração.
  * `EXTERNAL_MX`: Registro válido e sincronizado, porém apontando para provedor externo (Google Workspace, Microsoft 365, Zoho, etc.).
  * `DESYNC`: Divergência entre `NS1` e `NS2` (possível atraso de propagação ou falha de replicação de cluster DNS).
  * `NO_MX`: Nenhum registro MX retornado na consulta pública.
* **Parser Robusto de Zonas BIND:** Compatível com notação `@`, diretivas de TTL e registros com prioridades variadas.
* **Verificação WHOIS Segura:** Suporte a múltiplos TLDs (`.br`, `.com`, `.net`, `.io`, etc.) com timeout integrado para evitar travamento em servidores de whois lentos, além da opção `--skip-whois` para varreduras ultrarrápidas.
* **Saída Formatada e Colorida:** Tabela alinhada com cores indicativas no terminal e fallback automático para ambientes sem `column`.

## 📋 Pré-requisitos

O script requer os seguintes utilitários instalados:

* `bash` (4.0+)
* `dig` (pacote `bind-utils` no RHEL/CentOS/AlmaLinux ou `dnsutils` no Debian/Ubuntu)
* `whois` (opcional; o script desativa automaticamente se não estiver presente)
* `column` (opcional; o script possui fallback formatado nativo via `printf`)

## 🔧 Uso e Exemplos

**1. Baixe o script:**

```bash
curl -O https://raw.githubusercontent.com/sr00t3d/named-check-mx-zones/refs/heads/main/check-mx-zones.sh
chmod +x check-mx-zones.sh
```

**2. Opções de execução:**

```text
Usage: check-mx-zones.sh [OPTIONS]

Options:
  -d, --dir DIR          Diretório contendo arquivos .db do BIND (padrão: /var/named)
  -1, --ns1 SERVER       Servidor DNS primário para consulta (padrão: auto-detectado ou 1.1.1.1)
  -2, --ns2 SERVER       Servidor DNS secundário para consulta (padrão: auto-detectado ou 8.8.8.8)
  -t, --timeout SEC      Timeout de consulta DNS em segundos (padrão: 2)
  -w, --skip-whois       Pular consultas WHOIS para varredura mais rápida
  -a, --all              Verificar todos os domínios com MX, não apenas mail.<dominio>
  -v, --verbose          Exibir progresso domínio a domínio durante a execução
  --no-color             Desativar cores na saída
  -h, --help             Exibir menu de ajuda e sair
```

**3. Exemplos práticos:**

* **Execução padrão (auto-detecta servidores e analisa `/var/named`):**
  ```bash
  ./check-mx-zones.sh
  ```

* **Definindo nameservers autoritativos específicos:**
  ```bash
  ./check-mx-zones.sh -1 ns1.seudominio.com.br -2 ns2.seudominio.com.br
  ```

* **Varredura rápida em massa (pulando WHOIS):**
  ```bash
  ./check-mx-zones.sh --skip-whois -a
  ```

* **Diretório personalizado com timeout reduzido:**
  ```bash
  ./check-mx-zones.sh -d /etc/bind/zones -t 1 --skip-whois
  ```

## 📝 Exemplo de Saída

```text
Starting DNS Zone check (v1.1.0)...
Scanning directory: /var/named
Nameserver 1 (NS1): 1.1.1.1
Nameserver 2 (NS2): 8.8.8.8
DNS Query Timeout:  2s
WHOIS Lookups:      Enabled
Filter:             All MX zones

================================================================================
DOMAIN                REGISTERED  MX RECORD             STATUS
--------------------------------------------------------------------------------
exemplo.com.br        YES         0 mail.exemplo.com.br. OK
cliente-externo.com   YES         10 aspmx.l.google.com. EXTERNAL_MX
desync-domain.org     YES         10 mail.desync.org.   DESYNC
zona-antiga.net       NO          (none)                NO_MX
================================================================================
Total zones checked: 4
Summary: Discrepancies found (Check ERROR/DESYNC/EXTERNAL_MX/NO_MX status).
Total execution time: 2s
```

## ⚠️ Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Certifique-se sempre de testar primeiro em um ambiente de desenvolvimento. O autor não se responsabiliza por qualquer uso indevido, consequências legais ou impacto em dados causado por esta ferramenta.

---

## 📚 Tutorial Detalhado

Para um guia completo passo a passo, confira o artigo no blog:

👉 [**Verificar MX de Zonas de Domínio no NAMED**](https://perciocastelo.com.br/blog/check-domains-zone-mx-in-named.html)

## Licença 📄

Este projeto está licenciado sob a **Apache License 2.0**. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.
