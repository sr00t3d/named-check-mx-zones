# Check MX Zones in NAMED

Readme: [Inglês](README.md)

![License](https://img.shields.io/github/license/sr00t3d/named-check-mx-zones)
![Shell Script](https://img.shields.io/badge/language-Bash-green.svg)

Um script Bash projetado para administradores de sistemas validarem arquivos de zona DNS locais contra consultas reais em servidores de nomes. Ele tem como alvo específico domínios configurados com um registro MX local apontando para `mail.domain.tld`.

O script percorre arquivos de zona (geralmente BIND/Named), consulta dois servidores de nomes definidos, faz a validação cruzada dos resultados e verifica o status de registro do domínio via WHOIS.

## 🚀 Funcionalidades

* **Consistência de MX:** Compara os registros MX retornados por `NS1` e `NS2` para garantir sincronização.
* **Validação de Configuração:** Verifica especificamente se o registro MX ativo corresponde à configuração local (apontando para `mail.domain` com prioridade `0`).
* **Verificação de Registro:** Executa uma consulta `whois` para verificar se o domínio está atualmente registrado ou disponível (útil para limpeza de zonas antigas).
* **Saída Formatada:** Gera uma tabela alinhada para facilitar a leitura.

## 📋 Pré-requisitos

O script requer os seguintes utilitários instalados no sistema host:

* `bash` (4.0+)
* `dig` (geralmente parte do `bind-utils` ou `dnsutils`)
* `whois`
* `column` (parte do `util-linux` ou `bsdmainutils`)

## ⚙️ Configuração

Abra o script e modifique as variáveis no topo do arquivo para corresponder ao seu ambiente:

```bash
NS1="ns1.yourserver.com"   # Servidor de Nomes primário para consulta
NS2="ns2.yourserver.com"   # Servidor de Nomes secundário para consulta
ZONEDIR="/var/named"       # Diretório contendo arquivos de zona .db
```

## 🔧 Uso

**1. Baixe o script (ex.: check_mx.sh):**

```bash
wget https://raw.githubusercontent.com/sr00t3d/named-check-mx-zones/refs/heads/main/check-mx-zones.sh
```

**2. Torne-o executável:**

```bash
chmod +x check-mx-zones.sh
```

**Execute o script (pode exigir `sudo` dependendo das permissões de leitura do seu `$ZONEDIR`):**

```bash
sudo ./check-mx-zones.sh
```

## ⚠️ Observações Importantes

> Limitação de Taxa do Whois: O script executa uma consulta whois para cada domínio correspondente. Se você tiver centenas de domínios, isso pode acionar limitação de taxa por provedores WHOIS ou desacelerar significativamente a execução.

> Lógica de Destino: O script atualmente filtra arquivos de zona locais contendo IN MX [prioridade] mail.domain.. Se seus arquivos de zona utilizam um formato diferente (ex.: apontando diretamente para Google Workspace ou Office 365), eles serão ignorados, a menos que você modifique a lógica de regex do grep dentro do loop.

📝 Exemplo de Saída

```bash
DOMAIN          REGISTERED  MX RECORD             STATUS
example.com     YES         0 mail.example.com.   OK
test-site.net   NO          0 mail.test-site.net. ERROR
```

## ⚠️ Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Embora extensivamente testado em ambientes Dovecot, **sempre realize um backup completo** dos seus diretórios Maildir antes de executar qualquer script de conversão. O autor não se responsabiliza por qualquer perda de dados.

---

## 📚 Tutorial Detalhado

Para um guia completo passo a passo sobre como importar os arquivos gerados no Thunderbird e solucionar problemas comuns de migração, confira meu artigo completo:

👉 [**Verificar MX de Zonas de Domínio no NAMED**](https://perciocastelo.com.br/blog/check-domains-zone-mx-in-named.html)

## Licença 📄

Este projeto está licenciado sob a **GNU General Public License v3.0**. Veja o arquivo [LICENSE](LICENSE) para detalhes.
