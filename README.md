# Wine-custom-build

Сборка `Wine 11.6` из `https://github.com/wine-mirror/wine` для `Winlator CMOD (StevenMXZ)` в двух вариантах:

- `x64/x86 (WoW64)` → в пакетах Winlator помечается как `x86_64`
- `arm64ec`

> `Winlator` ожидает суффиксы `x86_64` и `arm64ec`, поэтому вариант `x64-86` в `.wcp` оформляется как `x86_64`, но внутри это именно сборка `x64/x86`.

## Что есть в репозитории

- `scripts/install-build-deps.sh` — ставит зависимости для Ubuntu 24.04
- `scripts/build-winlator-wine.sh` — собирает `x64-x86`, `arm64ec` или обе версии
- `scripts/package-wcp.sh` — упаковывает runtime в `.tar.xz` и `.wcp`
- `.github/workflows/build-wine-11.6-winlator.yml` — GitHub Actions для облачной сборки

## Быстрый старт

```bash
cd /workspaces/Wine-custom-build
chmod +x scripts/*.sh
./scripts/install-build-deps.sh
./scripts/build-winlator-wine.sh all
```

### Отдельные варианты

```bash
./scripts/build-winlator-wine.sh x64-x86
./scripts/build-winlator-wine.sh arm64ec
```

или через `make`:

```bash
make deps
make x64-x86
make arm64ec
make all
```

## Артефакты

После сборки файлы появляются в `dist/`:

- `wine-11.6-x64-x86.tar.xz`
- `wine-11.6-x64-x86.wcp`
- `wine-11.6-arm64ec.tar.xz`
- `wine-11.6-arm64ec.wcp`

## Настраиваемые переменные

```bash
WINE_REF=wine-11.6
JOBS=$(nproc)
LLVM_MINGW_VERSION=20251007
LLVM_MINGW_ROOT=$PWD/work/toolchains/llvm-mingw-20251007
```

Пример:

```bash
WINE_REF=wine-11.6 JOBS=16 ./scripts/build-winlator-wine.sh arm64ec
```

## GitHub Actions

В репозитории уже добавлен workflow `build-wine-11.6-winlator`.
Его можно запустить вручную через **Actions → build-wine-11.6-winlator → Run workflow** и выбрать:

- `all`
- `x64-x86`
- `arm64ec`

## Примечания

- исходник берётся напрямую из `wine-mirror/wine`
- тег `wine-11.6` проверен и существует
- для `arm64ec` используется `llvm-mingw` + `aarch64-linux-gnu`
- упаковка `.wcp` уже совместима с импортом в Winlator CMOD
