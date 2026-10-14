# Delete Cookies

Limpeza automática e diária dos cookies de todos os browsers baseados em
Chromium, em Windows.

A solução instala uma tarefa no Programador de Tarefas do Windows que, a uma
hora fixa (por omissão **05:30**), fecha os browsers e elimina as bases de
dados de cookies de todos os perfis. No arranque seguinte cada browser cria
uma base de dados vazia, pelo que o utilizador começa o dia sem rasto de
navegação e sem sessões abertas.

Não são necessários direitos de administrador: tudo corre na conta do
utilizador e só toca em ficheiros do seu próprio perfil.

---

## Browsers suportados

| Browser | Localização dos perfis |
|---|---|
| Google Chrome | `%LOCALAPPDATA%\Google\Chrome\User Data` |
| Chromium | `%LOCALAPPDATA%\Chromium\User Data` |
| Microsoft Edge | `%LOCALAPPDATA%\Microsoft\Edge\User Data` |
| Brave | `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\User Data` |
| Vivaldi | `%LOCALAPPDATA%\Vivaldi\User Data` |
| Opera | `%APPDATA%\Opera Software\Opera Stable` |

Os browsers que não estiverem instalados são ignorados sem erro. Todos os
perfis são tratados — `Default`, `Profile 1`, `Profile 2`, etc.

---

## O que acontece em cada execução

1. **Fecha os browsers.** O ficheiro `Cookies` é uma base de dados SQLite que
   fica bloqueada enquanto o processo corre. A tarefa pede o fecho da janela
   e, se o processo resistir mais de 10 segundos, termina-o. As abas são
   restauradas no arranque seguinte.
2. **Elimina as bases de dados de cookies** de cada perfil: `Cookies` e os
   ficheiros auxiliares `Cookies-journal`, `Cookies-wal` e `Cookies-shm`.
   São procuradas tanto na localização atual (`<Perfil>\Network\Cookies`)
   como na usada por versões antigas (`<Perfil>\Cookies`).
3. **Regista o resultado** em
   `%LOCALAPPDATA%\ClearChromiumCookies\clear-cookies.log`, com uma linha por
   ficheiro apagado ou ignorado.

Apenas os cookies são removidos. Histórico, favoritos, palavras-passe
guardadas, extensões e definições mantêm-se intactos.

---

## Instalação

Descarregar o instalador da
[última versão](https://github.com/antoniocostalopes/Delete-Cookies/releases/latest)
e executar.

O assistente pergunta:

- **A hora da limpeza diária** (formato 24 h, por omissão `05:30`).
- **Que browsers limpar** (por omissão, todos).
- Se deve **abrir a janela de log** caso algo falhe.

No fim fica registada a tarefa `Clear Chromium Cookies Daily`, visível no
Programador de Tarefas do Windows, e são criados atalhos no menu Iniciar para
limpar os cookies manualmente, consultar os logs e desinstalar.

O executável não está assinado digitalmente, pelo que o SmartScreen mostra um
aviso na primeira execução (*Mais informações* → *Executar mesmo assim*).

### Desinstalação

Pelas *Aplicações e funcionalidades* do Windows. A desinstalação remove a
tarefa agendada, os scripts e os atalhos.

---

## Comportamento da tarefa agendada

| Situação | Resultado |
|---|---|
| PC ligado à hora marcada | A limpeza corre normalmente. |
| PC desligado ou suspenso | Corre no arranque seguinte (`StartWhenAvailable`). A tarefa nunca acorda o PC. |
| A correr com bateria | Corre na mesma; não é interrompida se o portátil passar a bateria. |
| Execução anterior ainda a decorrer | A nova execução é ignorada. |
| Limpeza acima de 10 minutos | É terminada, para nunca ficar pendurada. |

A tarefa corre com privilégios normais, no contexto do utilizador que a
instalou. Só é visível no Programador de Tarefas quando este é aberto nessa
conta ou com privilégios de administrador.

---

## Componentes

| Ficheiro | Função |
|---|---|
| `Clear-ChromiumCookies.ps1` | Faz a limpeza: fecha os browsers, apaga os cookies de cada perfil e escreve o log. |
| `Install-CookieCleanupTask.ps1` | Regista, atualiza ou remove a tarefa agendada. |
| `installer/DeleteCookies.nsi` | Instalador NSIS, com assistente, atalhos e desinstalador. |
| `installer/DeleteCookies.iss` | Instalador equivalente em Inno Setup. |
| `Install.cmd` | Instalação direta pelos scripts, sem instalador gráfico. |

A tarefa é criada através do `schtasks.exe` com um ficheiro XML, por ser o
mecanismo disponível em qualquer versão do Windows — o módulo PowerShell
`ScheduledTasks` só existe a partir do Windows 8. Os scripts são compatíveis
com o PowerShell 2.0 que acompanha o Windows 7.

---

## Requisitos

- Windows 7 ou superior (testado em Windows 10, PowerShell 5.1)
- Nenhuma dependência externa
- Sem direitos de administrador

---

## Nota importante

A eliminação dos cookies **termina a sessão em todos os sites**: no dia
seguinte é preciso voltar a iniciar sessão em cada serviço. É esse o objetivo
da solução.
