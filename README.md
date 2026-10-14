# Delete Cookies — limpeza diaria de cookies Chromium (Windows)

Cria uma Scheduled Task que apaga **todos os cookies** dos browsers Chromium
**todos os dias as 05:30**.

## Ficheiros

| Ficheiro | Função |
|---|---|
| `Clear-ChromiumCookies.ps1` | Faz a limpeza: fecha o browser, apaga a base de dados `Cookies` de cada perfil, escreve log. |
| `Install-CookieCleanupTask.ps1` | Instala/atualiza/remove a Scheduled Task. |
| `Install.cmd` | Duplo-clique para instalar (chama o installer). |

## Instalar

Duplo-clique em `Install.cmd`, ou no PowerShell:

```powershell
cd "C:\caminho\Delete Cookies"
.\Install-CookieCleanupTask.ps1
```

Não precisa de administrador: a tarefa corre com a conta do utilizador atual e
só toca em ficheiros do próprio perfil.

## Opções

```powershell
# Outra hora
.\Install-CookieCleanupTask.ps1 -Time 03:30

# Só Chrome e Edge
.\Install-CookieCleanupTask.ps1 -Browser Chrome,Edge

# Não fechar browsers (cookies ficam se o ficheiro estiver bloqueado)
.\Install-CookieCleanupTask.ps1 -NoStopBrowsers

# Remover tarefa e script instalado
.\Install-CookieCleanupTask.ps1 -Uninstall
```

Browsers suportados: `Chrome`, `Chromium`, `Edge`, `Brave`, `Vivaldi`, `Opera`.

## Testar / verificar

```powershell
Start-ScheduledTask -TaskName 'Clear Chromium Cookies Daily'
Get-ScheduledTaskInfo -TaskName 'Clear Chromium Cookies Daily'
Get-Content "$env:LOCALAPPDATA\ClearChromiumCookies\clear-cookies.log" -Tail 30
```

## Notas

- O ficheiro `Cookies` está bloqueado enquanto o browser corre, por isso o
  script fecha o browser antes de apagar (sessão/abas são restauradas no
  arranque seguinte). Com `-NoStopBrowsers` nada é fechado e perfis bloqueados
  são ignorados.
- Apagar cookies termina as sessões de todos os sites (logins).
- A tarefa usa `-StartWhenAvailable`: se o PC estiver desligado/suspenso às
  05:30, corre no arranque seguinte. Não acorda o PC.
- O browser recria uma base de dados de cookies vazia no arranque seguinte.

## Instalador Windows (setup.exe)

`installer/DeleteCookies.iss` é um script [Inno Setup 6](https://jrsoftware.org/isinfo.php)
que empacota tudo num único `setup.exe`.

### Compilar (numa máquina Windows)

```bat
winget install -e --id JRSoftware.InnoSetup
installer\build.cmd
```

Resultado: `installer\dist\DeleteCookies-Setup-1.0.0.exe`.

### O que o setup.exe faz

1. Instala em `%LOCALAPPDATA%\Programs\Delete Cookies` (**sem pedir administrador**).
2. Pergunta a hora da limpeza (default `05:30`) e quais os browsers.
3. Registra a Scheduled Task `Clear Chromium Cookies Daily` com essas escolhas.
4. Cria atalhos no menu Iniciar: *Limpar cookies agora* e *Ver log*.
5. Opção no fim para correr a limpeza imediatamente.

Desinstalar por Aplicações e funcionalidades do Windows (ou `unins000.exe`)
remove a tarefa agendada **e** os ficheiros.

### Instalação silenciosa

```bat
DeleteCookies-Setup-1.0.0.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
```

Em modo silencioso são usados os defaults: 05:30 e todos os browsers.

## Instalador NSIS (.exe pronto a usar)

`installer/DeleteCookies.nsi` produz o mesmo instalador que o script Inno, mas
**compila em macOS e Linux** — não precisa de uma máquina Windows.

```bash
brew install makensis        # macOS   (Linux: apt install nsis)
installer/build-nsis.sh
```

No Windows: `winget install -e --id NSIS.NSIS` e depois `installer\build-nsis.cmd`.

Resultado: `installer/dist/DeleteCookies-Setup-1.0.0.exe` (~96 KB).

O instalador:

1. Instala em `%LOCALAPPDATA%\Programs\Delete Cookies` — sem UAC.
2. Página de opções: hora (default `05:30`, validada HH:MM) e checkboxes dos browsers.
3. Registra a tarefa `Clear Chromium Cookies Daily` com essas opções.
4. Atalhos no menu Iniciar: *Limpar cookies agora*, *Ver log*, *Desinstalar*.
5. Entrada em Aplicações e funcionalidades; desinstalar remove a tarefa e os ficheiros.

Silencioso (defaults 05:30 + todos os browsers):

```bat
DeleteCookies-Setup-1.0.0.exe /S
```

O .exe não está assinado, logo o SmartScreen pode avisar na primeira execução
("Mais informações" > "Executar mesmo assim").

### Logs e diagnóstico

A página de opções tem a checkbox **"Se ocorrer um erro, abrir a janela com o
log dos erros"** (ligada por omissão). Se o registo da tarefa falhar:

- a lista de detalhes do instalador abre automaticamente;
- o log abre numa janela do Bloco de Notas.

Ficheiros de log, dentro da pasta de instalação:

| Ficheiro | Conteúdo |
|---|---|
| `install-output.log` | Transcrição completa (stdout + stderr) do PowerShell. Existe mesmo que o PowerShell falhe a arrancar. |
| `install-task.log` | Log estruturado do script: versão do PowerShell, utilizador, argumentos, XML gerado, saída do `schtasks`, linha que falhou. |
| `%LOCALAPPDATA%\ClearChromiumCookies\clear-cookies.log` | Log de cada limpeza diária. |

Atalho no menu Iniciar: **Log de instalação**.
