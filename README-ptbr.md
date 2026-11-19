# Check MX Zones in NAMED

Readme: [EN](README.md)

![License](https://img.shields.io/github/license/sr00t3d/named-check-mx-zones) ![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

<img width="700" src="named-check-mx-zones-cover.webp" />

Um script Bash moderno e de alta performance projetado para administradores de sistemas e equipes DevOps validarem arquivos de zona DNS locais (BIND/Named em cPanel, DirectAdmin ou servidores dedicados) contra consultas reais em servidores de nomes autoritativos ou recursivos.

O script analisa os arquivos de zona (`.db`), consulta os nameservers configurados, faz validação cruzada para detectar divergências de propagação ou desync, suporta verificação de registro de domínio via WHOIS e gera relatórios estruturados (Tabela, JSON, CSV).

## 🚀 Funcionalidades (v1.2.0)

* **Varredura Concorrente Multi-Thread (`-j, --jobs`):** Acelera drasticamente a auditoria em frotas com centenas ou milhares de domínios utilizando processamento concorrente em segundo plano.
* **Formatos Estruturados de Saída (`-o table|json|csv`):** Exportação nativa em JSON ou CSV para integração com pipelines CI/CD, Zabbix, Prometheus, SIEMs ou painéis de observabilidade.
* **Modo Domínio Único (`-D, --domain`):** Diagnóstico instantâneo de um domínio específico ou arquivo de zona sem precisar escanear todo o diretório `/var/named`.
* **Filtro de Divergências (`-e, --only-issues`):** Exibe somente domínios com problemas (`DESYNC`, `NO_MX`, `EXTERNAL_MX`, `NOT_REGISTERED`), ocultando os registros conformes.
* **Modo de Consulta Autoritativa (`--auth`):** Descobre e consulta dinamicamente os nameservers autoritativos delegados de cada domínio em vez de apenas resolvers estáticos.
* **Auto-detecção de Nameservers:** Detecta automaticamente os nameservers em `/etc/nameserverips` (cPanel) ou `/etc/resolv.conf`, com fallback inteligente para `1.1.1.1` e `8.8.8.8`.
* **Classificação Granular de Status:**
  * `OK`: Registro MX sincronizado entre os nameservers e compatível com a configuração.
  * `EXTERNAL_MX`: Registro válido e sincronizado, porém apontando para provedor externo (Google Workspace, Microsoft 365, Zoho, etc.).
  * `DESYNC`: Divergência entre `NS1` e `NS2` (possível atraso de propagação ou falha de replicação de cluster DNS).
  * `NO_MX`: Nenhum registro MX retornado na consulta pública.
  * `NOT_REGISTERED`: Domínio expirado ou disponível para registro conforme consulta WHOIS.
* **Parser Robusto de Zonas BIND:** Compatível com notação `@`, diretivas de TTL, comentários em linha (`;`) e registros com prioridades variadas.
* **Verificação WHOIS Segura:** Suporte a múltiplos TLDs (`.br`, `.com`, `.net`, `.io`, etc.) com timeout integrado para evitar travamento em servidores de whois lentos, além da opção `--skip-whois`.
* **Saída Formatada e Colorida:** Tabela alinhada com cores indicativas no terminal e fallback automático para ambientes sem `column`.

## 📋 Pré-requisitos

O script requer os seguintes utilitários instalados:

* `bash` (4.0+)
* `dig` (pacote `bind-utils` no RHEL/CentOS/AlmaLinux ou `dnsutils` no Debian/Ubuntu)
* `whois` (opcional; o script desativa automaticamente se não estiver presente)
* `python3` (opcional; necessário apenas para gerar exportação em `-o json`)
* `column` (opcional; o script possui fallback formatado nativo via `printf`)

## 🔧 Uso e Opções

```text
Named Check MX Zones v1.2.0

Uso: check-mx-zones.sh [OPÇÕES]

Opções de Escopo e Diretório:
  -d, --dir DIR          Diretório com arquivos .db do BIND/Named (padrão: /var/named)
  -D, --domain DOMÍNIO   Verificar um domínio único ou arquivo de zona específico
  -a, --all              Verificar todos os registros MX, não apenas mail.<domínio>

Opções de Servidores DNS & Rede:
  -1, --ns1 SERVIDOR     Servidor DNS primário para consulta (padrão: auto-detectado ou 1.1.1.1)
  -2, --ns2 SERVIDOR     Servidor DNS secundário para consulta (padrão: auto-detectado ou 8.8.8.8)
  --auth, --authoritative Consultar os servidores NS autoritativos delegados de cada domínio
  -t, --timeout SEG      Timeout de consulta DNS por servidor em segundos (padrão: 2)
  -j, --jobs NUM         Número de tarefas paralelas concorrentes (padrão: 5, 1=sequencial)
  -w, --skip-whois       Pular consultas WHOIS de registro para varredura ultrarrápida

Opções de Saída e Relatório:
  -o, --output FORMATO   Formato de saída: table (padrão), json, csv
  -e, --only-issues      Exibir apenas domínios com divergências (DESYNC, NO_MX, EXTERNAL_MX, etc.)
  -v, --verbose          Exibir log detalhado de cada checagem no stderr
  --no-color             Desativar cores na saída de terminal
  -h, --help             Exibir este menu de ajuda e sair
```

## 💡 Exemplos Práticos

* **Execução padrão (auto-detecta servidores e analisa `/var/named`):**
  ```bash
  ./check-mx-zones.sh
  ```

* **Auditoria ultrarrápida multi-thread (10 threads) exportando em JSON:**
  ```bash
  ./check-mx-zones.sh -j 10 --skip-whois -o json > audit.json
  ```

* **Checagem de domínio único contra os nameservers autoritativos:**
  ```bash
  ./check-mx-zones.sh -D exemplo.com.br --auth -a
  ```

* **Auditar apenas divergências e exportar em CSV:**
  ```bash
  ./check-mx-zones.sh -e -o csv > divergencias.csv
  ```

* **Diretório personalizado com nameservers específicos:**
  ```bash
  ./check-mx-zones.sh -d /var/named -1 ns1.seudominio.com.br -2 ns2.seudominio.com.br
  ```

## 📝 Exemplo de Saída

### Formato Tabela:
```text
Starting Named Check MX Zones (v1.2.0)...
Diretório de Zonas: /var/named
Nameserver 1:       1.1.1.1
Nameserver 2:       8.8.8.8
DNS Timeout:        2s
Concorrência:       5 threads simultâneas
Filtro WHOIS:       Ativado
Filtro de Escopo:   Todos os MX

================================================================================
DOMAIN                REGISTERED  MX RECORD             STATUS
--------------------------------------------------------------------------------
exemplo.com.br        YES         0 mail.exemplo.com.br. OK
cliente-externo.com   YES         10 aspmx.l.google.com. EXTERNAL_MX
desync-domain.org     YES         10 mail.desync.org.   DESYNC
zona-antiga.net       NO          (none)                NOT_REGISTERED
================================================================================
Total de zonas auditadas: 4
Resumo: Encontradas 3 divergência(s) (verifique STATUS acima).
Tempo total de execução: 1s
```

### Formato JSON (`-o json`):
```json
{
  "version": "1.2.0",
  "total_checked": 2,
  "issues_found": 1,
  "execution_time_seconds": 0.45,
  "results": [
    {
      "domain": "exemplo.com.br",
      "registered": "YES",
      "mx_records": ["0 mail.exemplo.com.br."],
      "status": "OK",
      "has_issue": false
    },
    {
      "domain": "zona-antiga.net",
      "registered": "NO",
      "mx_records": [],
      "status": "NOT_REGISTERED",
      "has_issue": true
    }
  ]
}
```

## 📄 Licença

Este projeto é distribuído sob a licença [Apache License 2.0](LICENSE).

---
Autor: **Percio Castelo**  
Contato: [contato@perciocastelo.com.br](mailto:contato@perciocastelo.com.br)  
Website: [https://perciocastelo.com.br](https://perciocastelo.com.br)
