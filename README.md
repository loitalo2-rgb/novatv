# Nova TV

Player de IPTV multiplataforma com visual inspirado nos grandes serviços de streaming.
Funciona em **Android TV**, **Windows** e **Web**, com layout em fileiras horizontais,
canais ao vivo, filmes, séries, guia de programação (EPG), favoritos e "continuar assistindo".

O Nova TV é apenas um **player**: ele não fornece, hospeda nem distribui canais, filmes ou séries.
Você adiciona suas próprias listas M3U/EPG ou listas licenciadas que tenha autorização para usar.

## Recursos

- **Múltiplas listas M3U/M3U8** com atualização automática (15 min a 6 h, ou manual) e cache local.
- **Detecção automática** de canais ao vivo, filmes e séries a partir do `group-title`/título.
- **EPG XMLTV** opcional por lista, com programação atual e próxima.
- **Home estilo streaming**: destaque (hero), "Continue assistindo", "Ao vivo agora" e favoritos.
- **Aba Destaques** com filmes e séries em destaque.
- **Aba Catálogo** com todos os filmes e séries, filtros por tipo/categoria e ordenação A–Z.
- **Ao Vivo em duas colunas**: canais à esquerda e vídeo tocando à direita; clique no vídeo para ampliar.
- **Troca de servidores e idioma**: escolha entre as fontes alternativas de canais, filmes e episódios (inclusive no player em tela cheia). Filmes e séries com dublado/legendado mostram as opções de idioma ao abrir.
- **Capas do catálogo**: pôsteres TMDB carregados de `fichas.txt`, com correspondência tolerante a acentos, ano, pontuação e espaços.
- **Busca** por todo o catálogo.
- **Favoritos** e **progresso** salvos no aparelho; retomada de onde parou.
- **Player** com `media_kit`/mpv: play/pause, seek, volume, faixas de áudio/legenda, tela cheia.
- **Navegação por controle remoto** (foco, setas e OK) para Android TV.
- **Lista de demonstração** com vídeos públicos (Blender/W3C) para testar sem configurar nada.

## Como rodar

Pré-requisitos: [Flutter](https://docs.flutter.dev/get-started/install) 3.24 ou superior
(o projeto foi desenvolvido com Flutter 3.47 / Dart 3.13).

```bash
flutter pub get
```

### Web

```bash
flutter run -d chrome
# ou build de produção
flutter build web --release
```

Sirva a pasta `build/web` (por exemplo `npx serve build/web`) e abra no navegador.

### Windows

Requer **Visual Studio 2022** com a carga de trabalho *Desenvolvimento para desktop com C++*
e **Modo de Desenvolvedor** ativado no Windows (necessário para os links simbólicos dos plugins).

```bash
flutter config --enable-windows-desktop
flutter run -d windows
flutter build windows --release
```

### Android TV

Requer o **Android SDK** e um emulador ou TV box com depuração USB.

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

O manifesto já inclui `LEANBACK_LAUNCHER`, suporte a controle remoto e `usesCleartextTraffic`
para listas HTTP. Para publicar na Play Store é necessário ícone de banner de TV (320x180)
e demais requisitos da categoria Android TV.

## Usando o app

1. Abra **Ajustes → Adicionar lista**.
2. Informe o nome, o link `.m3u`/`.m3u8` e, se quiser, o link do EPG `.xml`/`.xmltv`.
3. Escolha o intervalo de atualização automática.
4. Use a lista de demonstração para testar a interface sem cadastrar nada.

### Importar um arquivo do computador

1. **Ajustes → Adicionar** e toque em **Importar arquivo .m3u**.
2. No **Web/desktop**, toque em **Escolher arquivo .m3u** e selecione o arquivo. No
   **Windows/Linux/macOS** também é possível digitar o caminho completo do arquivo.
3. O nome da lista é preenchido a partir do nome do arquivo (pode alterar).
4. Para trocar o conteúdo depois, use o menu da lista → **Editar → Trocar arquivo da lista**.

O conteúdo do arquivo importado fica guardado somente no aparelho (não é enviado para
nenhum servidor) e continua disponível depois de fechar o app. Listas importadas não
dependem de internet para carregar o catálogo, mas os canais/filmes continuam precisando
de conexão para tocar.

## Estrutura do projeto

```
lib/
  core/            tema e utilitários
  data/
    models/        MediaItem, PlaylistSource, EpgProgram, WatchProgress
    parsers/       M3U e XMLTV
    repositories/  carregamento de listas e EPG
    services/      HTTP, preferências, cache (IO/Web) e importação de arquivo .m3u
    demo_content.dart
  state/           AppState (Provider): listas, catálogo, EPG, favoritos, progresso
  ui/
    screens/       home, ao vivo (duas colunas), destaques, catálogo, detalhes, busca, player, ajustes
    widgets/       hero, fileiras, cards com foco, estados vazios
    dialogs/       formulário de lista e importação de arquivo
```

## Testes

```bash
flutter analyze
flutter test
```

## Aviso legal

O Nova TV não fornece conteúdo. Você é responsável pelas listas M3U/EPG que adicionar e por
ter autorização para acessá-las. A lista de demonstração usa apenas vídeos públicos e livres
da Blender Foundation e do W3C.

Feito com Flutter, `media_kit` (mpv) e layout próprio.
