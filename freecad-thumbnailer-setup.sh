#!/usr/bin/env bash
# >>> DOCUMENTACION COMPLETA (este bloque no aparece en --help) >>>>>>>>>>>>>>
# ============================================================================
# FREECAD-THUMBNAILER-SETUP  v2.1  (carlymx, licencia MIT)
# ============================================================================
#
# QUE ES
#   Script autocontenido (solo bash + python3, sin instalacion previa de
#   paquetes) que instala un "thumbnailer": un generador de miniaturas para
#   los archivos .FCStd de FreeCAD.
#
# PARA QUE SIRVE
#   Para que el explorador de archivos muestre una vista previa del modelo
#   en cada .FCStd en lugar del icono generico, y asi localizar un archivo
#   sin abrirlo en FreeCAD. A la vez activa en FreeCAD la opcion "Guardar la
#   miniatura en el archivo del proyecto al guardar" (SaveThumbnail), de modo
#   que la propia miniatura viaja dentro del .FCStd y se puede regenerar
#   aunque el archivo se copie a otro equipo.
#
# COMO FUNCIONA
#   1. Instala el generador: freecad-thumbnailer.py. Primero intenta leer la
#      miniatura embebida en el .FCStd (Document.xml, GuiDocument.xml);
#      si no existe, la genera con FreeCAD en modo consola (FreeCADCmd del
#      PATH, el de flatpak o el de snap) y la guarda en PNG.
#   2. Registra el tipo MIME application/x-extension-fcstd (XML de
#      freedesktop + update-mime-database) y publica una entrada
#      FreeCAD.thumbnailer en la carpeta de thumbnailers del explorador:
#        ~/.local/share/thumbnailers  (siempre mirada primero por
#        cinnamon-desktop, tumbler y los demas)  o  /usr/share/thumbnailers.
#   3. Habilita la previsualizacion en el explorador detectado
#      (gsettings en Nemo/Nautilus/Caja, xfconf en Thunar, Dolphin,
#      PCManFM) y activa SaveThumbnail en los user.cfg de FreeCAD.
#   4. Borra los fallos de la cache de miniaturas (~/.cache/thumbnails/fail),
#      reinicia el explorador y verifica el resultado generando una miniatura
#      de prueba y consultando la fabrica de miniaturas del escritorio.
#   Cada ajuste de configuracion que cambia se guarda antes en
#   ~/.local/state/freecad-thumbnailer-setup/state para poder deshacerlo.
#
# REQUISITOS
#   Obligatorios: Linux, bash, python3 y un explorador compatible: Nemo
#   (Cinnamon), Nautilus (GNOME), Dolphin (KDE), Thunar (XFCE), Caja (MATE)
#   o PCManFM/PCManFM-Qt (LXDE/LXQt).
#   Para instalar en todo el sistema (--system) hace falta sudo y una
#   terminal donde poder pedir la contrasena.
#   Para descargar el icono de respaldo: curl o wget (si no, se usa el icono
#   del flatpak/deb de FreeCAD si existe).
#   Distribuciones: Debian/Ubuntu (Mint, LMDE, Ubuntu, Pop, elementary,
#   Zorin), Fedora/Bazzite/Silverblue (inmutable, usa rpm-ostree),
#   Arch/Manjaro y openSUSE. Si el SO o el explorador no son compatibles el
#   script lo avisa y sale (o sigue con --force).
#   FreeCAD (flatpak, deb/rpm o snap) es opcional: sin el, los .FCStd que no
#   traen miniatura embebida se mostraran con el icono generico.
#   pygobject (python3-gi) es opcional: solo lo usa la verificacion contra la
#   fabrica de miniaturas del escritorio.
#   Paquetes opcionales (se ofrecen y solo se instalan si lo aceptas):
#     tumbler              miniaturas en Thunar
#     kde-fcstd-thumbnailer miniatura nativa en Dolphin
#
# INSTALACION
#   chmod +x freecad-thumbnailer-setup.sh
#   ./freecad-thumbnailer-setup.sh            # menu interactivo (sin argumentos)
#   ./freecad-thumbnailer-setup.sh --user     # solo tu usuario, sin sudo
#   ./freecad-thumbnailer-setup.sh --system   # todo el sistema (pide sudo)
#   ./freecad-thumbnailer-setup.sh --yes      # sin preguntas (automatizacion)
#   ./freecad-thumbnailer-setup.sh --dry-run  # ver que haria sin cambiar nada
#   En el menu: 1 instala, 2 desinstala, q sale; una opcion no valida vuelve
#   a preguntar y el fin de entrada (Ctrl+D) sale sin tocar nada.
#   Sin argumentos y sin terminal (pipe, cron) instala directamente, para no
#   bloquearse esperando una respuesta.
#
# FICHEROS QUE TOCA (modo usuario; con --system van a /usr)
#   ~/.local/bin/freecad-thumbnailer.py                       generador
#   ~/.local/share/thumbnailers/FreeCAD.thumbnailer           entrada .thumbnailer
#   ~/.local/share/mime/packages/org.freecadweb.FreeCAD.xml   tipo MIME
#   ~/.local/share/icons/hicolor/48x48/apps/freecad.png       icono de respaldo
#   Ademas cambia claves gsettings/xfconf del explorador,
#   SaveThumbnail en los user.cfg de FreeCAD (con copia .bak-thumbnailer)
#   y guarda su estado en:
#   ~/.local/state/freecad-thumbnailer-setup/{state,setup.log}
#
# DESINSTALACION
#   ./freecad-thumbnailer-setup.sh --uninstall      (o la opcion 2 del menu)
#     - borra los ficheros instalados (en user o en system segun el modo)
#     - restaura los ajustes del explorador y de FreeCAD desde el estado
#       guardado y elimina ese estado
#     - borra los fallos de la cache de miniaturas y reinicia el explorador
#   --uninstall --dry-run solo dice lo que borraria/restauraria: no toca nada.
#   Si un fichero esta en /usr y no hay sudo, se avisa y hay que repetirlo
#   como root.
#
# USO Y DIAGNOSTICO
#   --help     resumen de opciones (este bloque completo esta en el fichero)
#   --status   diagnostico completo, no cambia nada
#   --test     solo comprueba que el generador funciona
#   --demo     crea un .FCStd de prueba en el escritorio
#   El menu (sin argumentos) ya muestra un panel con el estado resumido.
#   El log de cada ejecucion: ~/.local/state/freecad-thumbnailer-setup/setup.log
#
# SOLUCION DE PROBLEMAS
#   - Antes de nada:  ./freecad-thumbnailer-setup.sh --status  (o el panel del
#     menu) para ver que detecta el script y si el modulo esta instalado.
#   - No se ve ninguna miniatura: Nemo/Nautilus -> Ver > Vista de iconos y
#     Editar > Preferencias > Previsualizacion = "Archivos locales"
#     (o "Siempre"); Thunar -> Preferencias > Mostrar miniaturas;
#     Dolphin -> Configurar Dolphin > General > Previsualizaciones.
#   - Se veia y dejo de verse:  rm -rf ~/.cache/thumbnails/fail  y reinicia
#     el explorador (tambien --full-cache para vaciar toda la cache).
#   - FreeCAD no guarda la miniatura: Editar > Preferencias > General >
#     Documento > "Guardar la miniatura en el archivo del proyecto al guardar".
#   - Archivo copiado de otro equipo sin miniatura: vuelve a guardarlo en
#     FreeCAD con SaveThumbnail activo.
#   - Si algo fallo a medias: lee el log y vuelve a ejecutar el script, o
#     desinstala (--uninstall) y vuelve a instalar.
#
# MAS INFORMACION
#   Resumen de opciones:   ./freecad-thumbnailer-setup.sh --help
#   Diagnostico:           ./freecad-thumbnailer-setup.sh --status
#   Documentacion (EN):    README.md
#   Documentacion (ES):    README_ES.md
#   Plan y estado:         PLAN.md
#   Upstream del generador: https://github.com/andesfreedesign/FreeCAD-thumbnailer
# ============================================================================
# <<< DOCUMENTACION COMPLETA <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#
# freecad-thumbnailer-setup.sh (v2.1)
#
# Previsualizacion de archivos FreeCAD (.FCStd) en el explorador de archivos.
# Soporta: Nemo (Cinnamon), Nautilus (GNOME), Dolphin (KDE), Thunar (XFCE),
# Caja (MATE) y PCManFM (LXDE/LXQt), en distribuciones Debian/Ubuntu, Fedora,
# Bazzite/ostree, Arch y openSUSE.
#
# Documentacion completa (que es, para que sirve, como funciona, que ficheros
# instala, como se instala y como se desinstala) en los comentarios del inicio
# de este fichero. Hay versiones en Markdown en README.md (EN) y
# README_ES.md (ES); el estado del proyecto y las tareas estan en PLAN.md.
#
# Uso:
#   ./freecad-thumbnailer-setup.sh              # instalacion automatica
#   ./freecad-thumbnailer-setup.sh --user       # solo para tu usuario (sin sudo)
#   ./freecad-thumbnailer-setup.sh --system     # en todo el sistema (pide sudo)
#   ./freecad-thumbnailer-setup.sh --status     # diagnostico, no cambia nada
#   ./freecad-thumbnailer-setup.sh --test       # solo verifica que funciona
#   ./freecad-thumbnailer-setup.sh --demo       # crea un .FCStd de prueba
#   ./freecad-thumbnailer-setup.sh --dry-run    # muestra lo que haria sin hacerlo
#   ./freecad-thumbnailer-setup.sh --uninstall  # desinstala y restaura ajustes
#   ./freecad-thumbnailer-setup.sh --help       # esta ayuda
#
#   Sin argumentos y con terminal abre un panel de estado (SO, FreeCAD,
#   explorador, modulo instalado, previsualizacion y modo) y un menu:
#     1  instalar
#     2  desinstalar
#     q  salir
#
#   Opciones:
#     --yes         no preguntar (acepta instalaciones opcionales)
#     --force       seguir aunque el SO o el explorador no sean compatibles
#     --full-cache  vaciar tambien las miniaturas ya generadas
#     --keep-cache  no tocar la cache de miniaturas
#     --no-deps     no instalar paquetes opcionales (tumbler, kde-fcstd-thumbnailer)
#     --no-config   no cambiar la configuracion de FreeCAD ni del explorador
#     --no-test     no verificar al finalizar
#     --no-restart  no reiniciar el explorador de archivos
#
set -Eeuo pipefail

# ===========================================================================
# constantes
# ===========================================================================
SCRIPT_VERSION="2.1"
UPSTREAM_RAW="https://raw.githubusercontent.com/andesfreedesign/FreeCAD-thumbnailer/main"
REPO_URL="https://github.com/andesfreedesign/FreeCAD-thumbnailer"
THUMB_SIZE_DEFAULT="34359738368"

# ===========================================================================
# opciones
# ===========================================================================
MODE="auto"
DO_DEPS=1
DO_INSTALL=1
DO_CONFIG=1
DO_ENABLE=1
DO_CACHE_CLEAR=1
DO_RESTART=1
DO_TEST=1
UNINSTALL=0
FORCE=0
DRY_RUN=0
YES=0
WANT_STATUS=0
WANT_DEMO=0
FULL_CACHE=0

# ===========================================================================
# entorno detectado
# ===========================================================================
OS_ID=""
OS_LIKE=""
OS_NAME=""
OS_VERSION=""
OS_FAMILY=""
PKG_MGR="desconocido"
IS_IMMUTABLE=0
OS_OK=0
FM_NEMO=0
FM_NAUTILUS=0
FM_DOLPHIN=0
FM_THUNAR=0
FM_CAJA=0
FM_PCMANFM=0
FM_LIST=""
FM_OK=0
NEED_REBOOT=0
SUDO=()
MENU_ACTION=""
FREECAD_DESC=""
FREECAD_OK=0
MOD_OK=0
MOD_MODE="ninguno"
MOD_DETAIL="NO instalado (0/4)"

# ===========================================================================
# salida
# ===========================================================================
if [ -t 1 ]; then
  C_RST=$'\033[0m'; C_GRN=$'\033[32m'; C_RED=$'\033[31m'
  C_YEL=$'\033[33m'; C_BLU=$'\033[34m'; C_BLD=$'\033[1m'
else
  C_RST=""; C_GRN=""; C_RED=""; C_YEL=""; C_BLU=""; C_BLD=""
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/freecad-thumbnailer-setup"
STATE_FILE="$STATE_DIR/state"
LOG_FILE="$STATE_DIR/setup.log"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE" 2>/dev/null || true; }
step() { printf '%s==>%s %s\n' "$C_BLU" "$C_RST" "$*"; log "==> $*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GRN" "$C_RST" "$*"; log "ok $*"; }
warn() { printf '%s aviso%s %s\n' "$C_YEL" "$C_RST" "$*" >&2; log "aviso $*"; }
err()  { printf '%serror%s %s\n' "$C_RED" "$C_RST" "$*" >&2; log "error $*"; }
die()  { err "$*"; exit 1; }

on_error() {
  err "fallo en la linea $1 (codigo $2); detalle en $LOG_FILE"
}
trap 'on_error $LINENO $?' ERR

usage() {
  # imprime solo el resumen de cabecera; el bloque de documentacion completo
  # (delimitado por las marcas >>> y <<<) solo esta en el fichero
  awk '
    NR == 1 { next }
    /^set -E/ { exit }
    /^# >>> DOCUMENTACION/ { indoc = 1; next }
    /^# <<< DOCUMENTACION/ { indoc = 0; next }
    indoc { next }
    { sub(/^# ?/, ""); if (!started && $0 == "") next; started = 1; print }
  ' "$0"
  exit 0
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "falta el comando: $1"; }

confirm() {
  local prompt="$1" ans=""
  if [ "$YES" = "1" ]; then
    log "confirmacion automatica (--yes): $prompt"
    return 0
  fi
  if [ ! -t 0 ]; then
    warn "$prompt -> no (sin terminal; usa --yes para aceptar)"
    return 1
  fi
  printf '%s¿%s? [s/N] %s' "$C_YEL" "$prompt" "$C_RST"
  read -r ans || ans=""
  case "$ans" in
    s|S|si|sí|y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s dry-run%s %s\n' "$C_BLU" "$C_RST" "$*"
    log "dry-run: $*"
    return 0
  fi
  log "ejec: $*"
  "$@"
}

# ===========================================================================
# argumentos
# ===========================================================================
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --user)        MODE="user" ;;
      --system)      MODE="system" ;;
      --auto)        MODE="auto" ;;
      --test)        DO_DEPS=0; DO_INSTALL=0; DO_CONFIG=0; DO_ENABLE=0
                     DO_CACHE_CLEAR=0; DO_RESTART=0; DO_TEST=1 ;;
      --no-test)     DO_TEST=0 ;;
      --no-deps)     DO_DEPS=0 ;;
      --no-config)   DO_CONFIG=0 ;;
      --keep-cache)  DO_CACHE_CLEAR=0 ;;
      --full-cache)  FULL_CACHE=1 ;;
      --no-restart)  DO_RESTART=0 ;;
      --status)      WANT_STATUS=1 ;;
      --demo)        WANT_DEMO=1 ;;
      --dry-run)     DRY_RUN=1 ;;
      --force)       FORCE=1 ;;
      --yes|-y)      YES=1 ;;
      --uninstall)   UNINSTALL=1 ;;
      -h|--help)     usage ;;
      *)             die "opcion desconocida: $1 (usa --help)" ;;
    esac
    shift
  done
}

# ===========================================================================
# fase 1: comprobacion del sistema operativo
# ===========================================================================
check_os() {
  local report="${1:-0}" tokens compatible=0

  if [ "$(uname -s)" != "Linux" ]; then
    OS_OK=0
    if [ "$report" = "1" ] || [ "$FORCE" = "1" ]; then
      warn "SO no compatible: $(uname -s) (se necesita Linux)"
    else
      err "Sistema operativo no compatible: $(uname -s)"
      err "Compatible: Linux con Debian/Ubuntu, Fedora/ostree (Bazzite) u openSUSE"
      exit 2
    fi
    return 0
  fi

  if [ ! -r /etc/os-release ]; then
    OS_OK=0
    if [ "$report" = "1" ] || [ "$FORCE" = "1" ]; then
      warn "no se pudo leer /etc/os-release"
    else
      err "Sistema operativo no compatible: no se puede leer /etc/os-release"
      exit 2
    fi
    return 0
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  OS_ID="${ID:-}"
  OS_LIKE="${ID_LIKE:-}"
  OS_NAME="${PRETTY_NAME:-$OS_ID}"
  OS_VERSION="${VERSION_ID:-}"
  tokens=" ${OS_ID} ${OS_LIKE} "

  case "$tokens" in
    *" debian "*|*" ubuntu "*|*" linuxmint "*|*" lmde "*|*" pop "*|*" elementary "*|*" zorin "*|*" kali "*|*" raspbian "*|*" deepin "*)
      OS_FAMILY="debian"; compatible=1 ;;
    *" fedora "*|*" bazzite "*|*" nobara "*|*" rhel "*|*" centos "*|*" rocky "*|*" almalinux "*)
      OS_FAMILY="fedora"; compatible=1 ;;
    *" arch "*|*" archlinux "*|*" manjaro "*|*" endeavouros "*|*" cachyos "*)
      OS_FAMILY="arch"; compatible=1 ;;
    *" opensuse "*|*" suse "*|*" sles "*|*" sle "*|*" tumbleweed "*)
      OS_FAMILY="suse"; compatible=1 ;;
  esac
  if [ "$OS_ID" = "bazzite" ]; then
    OS_FAMILY="fedora"
    compatible=1
  fi

  if [ -e /run/ostree-booted ]; then IS_IMMUTABLE=1; fi
  if command -v rpm-ostree >/dev/null 2>&1; then IS_IMMUTABLE=1; fi

  if command -v apt-get >/dev/null 2>&1 && [ "$IS_IMMUTABLE" = "0" ]; then
    PKG_MGR="apt"
  elif [ "$IS_IMMUTABLE" = "1" ] && command -v rpm-ostree >/dev/null 2>&1; then
    PKG_MGR="rpm-ostree"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR="dnf"
  elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR="pacman"
  elif command -v zypper >/dev/null 2>&1; then
    PKG_MGR="zypper"
  fi

  if [ "$compatible" = "1" ]; then
    OS_OK=1
    if [ "$report" = "1" ]; then
      printf '%s  ok%s SO: %s (familia %s, gestor %s%s)\n' "$C_GRN" "$C_RST" \
        "$OS_NAME" "$OS_FAMILY" "$PKG_MGR" \
        "$([ "$IS_IMMUTABLE" = "1" ] && echo ', inmutable')"
    else
      ok "SO compatible: $OS_NAME (familia: $OS_FAMILY, gestor: $PKG_MGR$([ "$IS_IMMUTABLE" = "1" ] && echo ', inmutable (rpm-ostree)'))"
    fi
    return 0
  fi

  OS_OK=0
  if [ "$report" = "1" ] || [ "$FORCE" = "1" ]; then
    warn "SO no comprobado/no listado: $OS_NAME (ID=$OS_ID, ID_LIKE=$OS_LIKE)"
    return 0
  fi
  err "Sistema operativo no compatible: $OS_NAME (ID=$OS_ID)"
  err "Compatibles: Debian/Ubuntu (Mint, LMDE, Ubuntu, Pop, elementary, Zorin),"
  err "  Fedora/Bazzite/Silverblue, Arch/Manjaro, openSUSE."
  err "Usa --force para continuar aun asi (modo generico)."
  exit 2
}

# ===========================================================================
# fase 2: comprobacion del explorador de archivos
# ===========================================================================
schema_exists() { gsettings list-schemas 2>/dev/null | grep -qx "$1"; }
has_key() { gsettings list-keys "$1" 2>/dev/null | grep -qx "$2"; }

check_filemanager() {
  local report="${1:-0}" def="" sess="" c

  def="$(xdg-mime query default inode/directory 2>/dev/null || true)"
  sess="${XDG_CURRENT_DESKTOP:-}|${DESKTOP_SESSION:-}|${XDG_SESSION_DESKTOP:-}"

  case "$def" in
    *nemo*)      FM_NEMO=1 ;;
    *nautilus*)  FM_NAUTILUS=1 ;;
    *dolphin*)   FM_DOLPHIN=1 ;;
    *thunar*)    FM_THUNAR=1 ;;
    *caja*)      FM_CAJA=1 ;;
    *pcmanfm*)   FM_PCMANFM=1 ;;
  esac

  case "$sess" in
    *[Cc]innamon*)        FM_NEMO=1 ;;
    *[Gg][Nn]ome*)        FM_NAUTILUS=1 ;;
    *KDE*|*kde*|*Plasma*|*plasma*) FM_DOLPHIN=1 ;;
    *XFCE*|*xfce*)        FM_THUNAR=1 ;;
    *MATE*|*mate*)        FM_CAJA=1 ;;
    *LXQt*|*lxqt*|*LXDE*|*lxde*) FM_PCMANFM=1 ;;
  esac

  for c in nemo nautilus dolphin thunar caja pcmanfm pcmanfm-qt; do
    if command -v "$c" >/dev/null 2>&1; then
      case "$c" in
        nemo)       FM_NEMO=1 ;;
        nautilus)   FM_NAUTILUS=1 ;;
        dolphin)    FM_DOLPHIN=1 ;;
        thunar)     FM_THUNAR=1 ;;
        caja)       FM_CAJA=1 ;;
        pcmanfm*)   FM_PCMANFM=1 ;;
      esac
    fi
  done

  FM_LIST=""
  if [ "$FM_NEMO" = "1" ]; then FM_LIST="$FM_LIST nemo"; fi
  if [ "$FM_NAUTILUS" = "1" ]; then FM_LIST="$FM_LIST nautilus"; fi
  if [ "$FM_DOLPHIN" = "1" ]; then FM_LIST="$FM_LIST dolphin"; fi
  if [ "$FM_THUNAR" = "1" ]; then FM_LIST="$FM_LIST thunar"; fi
  if [ "$FM_CAJA" = "1" ]; then FM_LIST="$FM_LIST caja"; fi
  if [ "$FM_PCMANFM" = "1" ]; then FM_LIST="$FM_LIST pcmanfm"; fi
  FM_LIST="${FM_LIST# }"

  if [ -n "$FM_LIST" ]; then
    FM_OK=1
    if [ "$report" = "1" ]; then
      printf '%s  ok%s explorador: %s (por defecto: %s)\n' "$C_GRN" "$C_RST" \
        "$FM_LIST" "${def:-no detectado}"
    else
      ok "Explorador(es) compatible(s): $FM_LIST (por defecto: ${def:-no detectado})"
    fi
    return 0
  fi

  FM_OK=0
  if [ "$report" = "1" ] || [ "$FORCE" = "1" ]; then
    warn "explorador no detectado (por defecto: ${def:-ninguno}; sesión: ${sess//|/ })"
    return 0
  fi
  err "Explorador de archivos no compatible o no detectado."
  err "Compatible: Nemo, Nautilus, Dolphin, Thunar, Caja, PCManFM(-Qt)."
  err "  xdg-mime (inode/directory): ${def:-ninguno}"
  err "  sesión de escritorio: ${sess//|/ }"
  err "Usa --force para instalar los ficheros estandar y seguir las instrucciones manuales."
  exit 3
}

# ===========================================================================
# fase 3: paquetes opcionales (dependen del explorador y del SO)
# ===========================================================================
pkg_installed() {
  case "$PKG_MGR" in
    apt)        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed" ;;
    dnf|rpm-ostree|zypper) rpm -q "$1" >/dev/null 2>&1 ;;
    pacman)     pacman -Q "$1" >/dev/null 2>&1 ;;
    *)          return 1 ;;
  esac
}

install_pkg() {
  local pkg="$1"
  if [ "$DRY_RUN" = "1" ]; then
    run "instalaria el paquete" "$pkg"
    return 0
  fi
  case "$PKG_MGR" in
    apt)
      run "${SUDO[@]}" apt-get install -y --no-install-recommends "$pkg" ;;
    dnf)
      run "${SUDO[@]}" dnf install -y "$pkg" ;;
    pacman)
      run "${SUDO[@]}" pacman -S --noconfirm --needed "$pkg" ;;
    zypper)
      run "${SUDO[@]}" zypper --non-interactive install "$pkg" ;;
    rpm-ostree)
      if run "${SUDO[@]}" rpm-ostree install --idempotent "$pkg"; then
        NEED_REBOOT=1
        ok "paquete $pkg instalado en la capa ostree (requiere reinicio)"
      else
        warn "no se pudo instalar $pkg con rpm-ostree"
        return 1
      fi
      ;;
    *)
      warn "gestor de paquetes desconocido: instala '$pkg' manualmente"
      return 1 ;;
  esac
}

optional_deps() {
  step "Comprobando dependencias opcionales"

  if [ "$FM_THUNAR" = "1" ]; then
    if pkg_installed tumbler; then
      ok "tumbler (miniaturas de Thunar) instalado"
    elif [ "$DRY_RUN" = "1" ]; then
      printf '%s dry-run%s instalaria el paquete tumbler (gestor: %s)\n' "$C_BLU" "$C_RST" "$PKG_MGR"
    elif confirm "Falta 'tumbler', sin el que Thunar no genera miniaturas. ¿Instalarlo?"; then
      install_pkg tumbler || warn "no se pudo instalar tumbler"
    else
      warn "sin tumbler: Thunar no mostrara miniaturas de .FCStd"
    fi
  fi

  if [ "$FM_DOLPHIN" = "1" ]; then
    if pkg_installed kde-fcstd-thumbnailer; then
      ok "kde-fcstd-thumbnailer (miniatura nativa de Dolphin) instalado"
    elif [ "$DRY_RUN" = "1" ]; then
      printf '%s dry-run%s comprobaria e instalaria kde-fcstd-thumbnailer (gestor: %s)\n' \
        "$C_BLU" "$C_RST" "$PKG_MGR"
      if [ "$PKG_MGR" = "rpm-ostree" ]; then
        printf '%s dry-run%s rpm-ostree install --idempotent kde-fcstd-thumbnailer (luego reinicio)\n' \
          "$C_BLU" "$C_RST"
      fi
    elif confirm "¿Instalar kde-fcstd-thumbnailer (miniaturas nativas de Dolphin)?"; then
      if ! install_pkg kde-fcstd-thumbnailer; then
        warn "paquete no disponible: se usara el thumbnailer estandar de freedesktop"
        if [ "$PKG_MGR" = "rpm-ostree" ]; then
          warn "en Bazzite/Fedora inmutable el paquete puede no existir aun en los repos"
        fi
      fi
    else
      warn "se usara el thumbnailer estandar de freedesktop (Dolphin: Plasma 6.6+)"
    fi
  fi

  if [ "$FM_PCMANFM" = "1" ] && [ "$MODE" = "user" ]; then
    warn "PCManFM: si no ves miniaturas, reinstala con --system (sudo)"
  fi
  return 0
}

# ===========================================================================
# fase 4: obtencion de los ficheros
# ===========================================================================
fetch() {
  local name="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 30 -o "$dest" "$UPSTREAM_RAW/$name" 2>/dev/null && return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 30 -O "$dest" "$UPSTREAM_RAW/$name" 2>/dev/null && return 0
  fi
  return 1
}

PY_SRC=$(cat <<'PYEOF'
#!/usr/bin/python3
"""freecad-thumbnailer.py - genera miniaturas para archivos .FCStd.

Implementa el estandar de thumbnailers de freedesktop.org:
    Exec=freecad-thumbnailer.py -s %s %i %o
Extrae thumbnails/Thumbnail.png del .FCStd (que es un zip); si no existe
usa el icono por defecto de FreeCAD.
"""
import os
import sys
import zipfile

ICON_CANDIDATES = (
    os.path.expanduser("~/.local/share/icons/hicolor/48x48/apps/freecad.png"),
    "/usr/share/icons/hicolor/48x48/apps/freecad.png",
    "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/org.freecad.FreeCAD.png",
    os.path.expanduser(
        "~/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps/org.freecad.FreeCAD.png"
    ),
)
THUMB_NAMES = ("thumbnails/Thumbnail.png", "thumbnails/Thumbnail.jpg")


def parse_args(argv):
    """Devuelve (input_file, output_file) tolerando -s <tam> y -s<tam>."""
    pos = []
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "-s":
            i += 1
        elif arg.startswith("-") :
            pass
        else:
            pos.append(arg)
        i += 1
    if len(pos) < 2:
        return None
    return pos[0], pos[1]


def main():
    parsed = parse_args(sys.argv[1:])
    if parsed is None:
        sys.stderr.write("uso: freecad-thumbnailer.py -s <size> <input> <output>\n")
        return 1
    input_file, output_file = parsed

    if not os.path.isfile(input_file):
        sys.stderr.write("no existe el fichero de entrada\n")
        return 1

    try:
        with zipfile.ZipFile(input_file) as zf:
            names = zf.namelist()
            if "Document.xml" not in names:
                sys.stderr.write("%s no parece un archivo FreeCAD\n" % input_file)
                return 1

            data = None
            for name in THUMB_NAMES:
                if name in names:
                    data = zf.read(name)
                    break

            if data is None:
                for icon in ICON_CANDIDATES:
                    if os.path.isfile(icon):
                        with open(icon, "rb") as fh:
                            data = fh.read()
                        break

            if data is None:
                sys.stderr.write("sin miniatura incrustada ni icono de respaldo\n")
                return 1

            out_dir = os.path.dirname(output_file)
            if out_dir:
                os.makedirs(out_dir, exist_ok=True)
            with open(output_file, "wb") as out:
                out.write(data)
    except zipfile.BadZipFile:
        sys.stderr.write("%s no es un zip valido\n" % input_file)
        return 1
    except Exception as exc:
        sys.stderr.write("error creando la miniatura: %s\n" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
PYEOF
)

MIME_XML_SRC=$(cat <<'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns='http://www.freedesktop.org/standards/shared-mime-info'>
  <mime-type type="application/x-extension-fcstd">
    <comment>FreeCAD document files</comment>
    <glob pattern="*.fcstd"/>
    <generic-icon name="application-x-extension-fcstd"/>
  </mime-type>
</mime-info>
XMLEOF
)

write_thumbnailer_entry() {
  local dest="$1" script="$2"
  cat >"$dest" <<EOF
[Thumbnailer Entry]
TryExec=$script
Exec="$script" -s %s %i %o
MimeType=application/x-extension-fcstd;application/x-freecad;application/x-freecad-document;
EOF
}

# ===========================================================================
# fase 5: modo de instalacion
# ===========================================================================
choose_mode() {
  local quiet="${1:-}"
  if [ "$MODE" = "auto" ]; then
    if [ "$(id -u)" -eq 0 ]; then
      MODE="system"
    elif sudo -n true 2>/dev/null; then
      MODE="system"
    else
      MODE="user"
    fi
  fi

  if [ "$MODE" = "system" ] && [ "$(id -u)" -ne 0 ]; then
    need_cmd sudo
    SUDO=(sudo)
    if [ "$DRY_RUN" != "1" ] && [ ! -t 0 ] && ! sudo -n true 2>/dev/null; then
      die "el modo --system necesita permisos de administrador y no hay terminal para pedir la contrasena (usa --user, o ejecuta el script en una terminal)"
    fi
  fi

  if [ "$MODE" = "system" ]; then
    BIN_DIR="/usr/bin"
    THUMB_DIR="/usr/share/thumbnailers"
    ICON_DIR="/usr/share/icons/hicolor/48x48/apps"
    MIME_PKG_DIR="/usr/share/mime/packages"
    MIME_DB="/usr/share/mime"
  else
    BIN_DIR="$HOME/.local/bin"
    THUMB_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/thumbnailers"
    ICON_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/48x48/apps"
    MIME_PKG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mime/packages"
    MIME_DB="${XDG_DATA_HOME:-$HOME/.local/share}/mime"
  fi

  BIN_PATH="$BIN_DIR/freecad-thumbnailer.py"
  THUMB_ENTRY="$THUMB_DIR/FreeCAD.thumbnailer"
  ICON_PATH="$ICON_DIR/freecad.png"
  MIME_XML="$MIME_PKG_DIR/org.freecadweb.FreeCAD.xml"
  DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
  CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

  if [ "$quiet" = "quiet" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    ok "modo de instalacion: $MODE (dry-run: no se cambiara nada)"
  else
    ok "modo de instalacion: $MODE"
  fi
}

# ===========================================================================
# fase 6: instalacion de ficheros
# ===========================================================================
install_files() {
  step "Instalando ficheros en $MODE"

  run "${SUDO[@]}" mkdir -p "$BIN_DIR" "$THUMB_DIR" "$ICON_DIR" "$MIME_PKG_DIR"

  printf '%s\n' "$PY_SRC" >"$WORKDIR/freecad-thumbnailer.py"
  chmod 0755 "$WORKDIR/freecad-thumbnailer.py"
  run "${SUDO[@]}" cp -f "$WORKDIR/freecad-thumbnailer.py" "$BIN_PATH"
  run "${SUDO[@]}" chmod 0755 "$BIN_PATH"
  if [ "$DRY_RUN" = "1" ] || [ -x "$BIN_PATH" ]; then
    ok "script: $BIN_PATH"
  fi

  write_thumbnailer_entry "$WORKDIR/FreeCAD.thumbnailer" "$BIN_PATH"
  run "${SUDO[@]}" cp -f "$WORKDIR/FreeCAD.thumbnailer" "$THUMB_ENTRY"
  ok "thumbnailer: $THUMB_ENTRY"

  printf '%s\n' "$MIME_XML_SRC" >"$WORKDIR/org.freecadweb.FreeCAD.xml"
  run "${SUDO[@]}" cp -f "$WORKDIR/org.freecadweb.FreeCAD.xml" "$MIME_XML"
  if command -v update-mime-database >/dev/null 2>&1; then
    run "${SUDO[@]}" update-mime-database "$MIME_DB" >/dev/null 2>&1 \
      || warn "update-mime-database fallo"
    ok "tipo MIME registrado en $MIME_XML"
  else
    warn "no hay update-mime-database; el tipo .fcstd debe venir de FreeCAD"
  fi

  if [ ! -f "$ICON_PATH" ] && [ "$DRY_RUN" != "1" ]; then
    if fetch freecad.png "$WORKDIR/freecad.png" \
       && file "$WORKDIR/freecad.png" 2>/dev/null | grep -qi "PNG image"; then
      run "${SUDO[@]}" cp -f "$WORKDIR/freecad.png" "$ICON_PATH"
      ok "icono de respaldo: $ICON_PATH (upstream)"
    else
      local_icon="/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/org.freecad.FreeCAD.png"
      [ -f "$local_icon" ] || local_icon="$HOME/.local/share/flatpak/exports/share/icons/hicolor/48x48/apps/org.freecad.FreeCAD.png"
      if [ -f "$local_icon" ]; then
        run "${SUDO[@]}" cp -f "$local_icon" "$ICON_PATH"
        ok "icono de respaldo: $ICON_PATH (Flatpak FreeCAD)"
      else
        warn "no se pudo instalar el icono de respaldo (solo afecta a .FCStd sin miniatura); descarga uno en $REPO_URL"
      fi
    fi
  elif [ -f "$ICON_PATH" ]; then
    ok "icono de respaldo ya presente: $ICON_PATH"
  fi
}

# ===========================================================================
# fase 7: FreeCAD guarda la miniatura dentro del .FCStd
# ===========================================================================
config_freecad() {
  step "Configurando FreeCAD para que guarde la miniatura en el .FCStd"
  if pgrep -x FreeCAD >/dev/null 2>&1 || pgrep -x freecad >/dev/null 2>&1 \
     || pgrep -f "FreeCAD.*AppImage|freecadcmd" >/dev/null 2>&1; then
    FCTHUMB_WRITE=0
  else
    FCTHUMB_WRITE=1
  fi
  if [ "$DRY_RUN" = "1" ]; then FCTHUMB_WRITE=0; fi
  export FCTHUMB_WRITE FCTHUMB_DRY="$DRY_RUN"
  python3 - <<'PYEOF' || true
import glob
import os
import re
import shutil
import sys

ALLOW_WRITE = os.environ.get("FCTHUMB_WRITE", "1") == "1"
DRY = os.environ.get("FCTHUMB_DRY", "0") == "1"
patterns = [
    os.path.expanduser("~/.config/FreeCAD/**/user.cfg"),
    os.path.expanduser("~/.var/app/org.freecad.FreeCAD/config/FreeCAD/**/user.cfg"),
]
paths = []
for p in patterns:
    paths.extend(glob.glob(p, recursive=True))

if not paths:
    print("  aviso: no se encontro user.cfg de FreeCAD (se configurara al abrirlo)")
    sys.exit(0)


def fix_group(match):
    body = match.group(0)
    if 'Name="SaveThumbnail"' in body:
        return re.sub(
            r'(<FCBool Name="SaveThumbnail" Value=")0(")',
            r"\g<1>1\g<2>",
            body,
        )
    indent = " " * 10
    return body.replace(
        "</FCParamGroup>",
        '%s<FCBool Name="SaveThumbnail" Value="1"/>\n%s</FCParamGroup>' % (indent, indent),
        1,
    )


pending = []
for path in sorted(set(paths)):
    with open(path, encoding="utf-8", errors="surrogateescape") as fh:
        data = fh.read()
    new = re.sub(
        r'<FCParamGroup Name="Document">.*?</FCParamGroup>',
        fix_group,
        data,
        flags=re.S,
    )
    if new == data:
        print("  ok  SaveThumbnail ya activo en %s" % path)
    elif DRY:
        print("  dry-run: se activaria SaveThumbnail=1 en %s" % path)
    elif ALLOW_WRITE:
        shutil.copy2(path, path + ".bak-thumbnailer")
        with open(path, "w", encoding="utf-8", errors="surrogateescape") as fh:
            fh.write(new)
        print("  ok  SaveThumbnail=1 -> %s" % path)
    else:
        pending.append(path)

if pending:
    print(
        "  aviso: FreeCAD esta abierto, cierralo y vuelve a ejecutar el script "
        "para activar el guardado de miniaturas en:\n         %s"
        % "\n         ".join(pending)
    )
    sys.exit(2)
PYEOF
}

# ===========================================================================
# fase 8: habilitar la previsualizacion en cada explorador
# ===========================================================================
state_record() {
  local line
  if [ "$DRY_RUN" = "1" ]; then
    log "dry-run estado no guardado: $*"
    return 0
  fi
  line="$(IFS='|'; echo "$*")"
  mkdir -p "$STATE_DIR"
  grep -qxF "$line" "$STATE_FILE" 2>/dev/null || printf '%s\n' "$line" >>"$STATE_FILE"
}

gset_set() {
  local schema="$1" key="$2" value="$3"
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s dry-run%s gsettings set %s %s %s\n' "$C_BLU" "$C_RST" "$schema" "$key" "$value"
    return 0
  fi
  if gsettings set "$schema" "$key" "$value" 2>/dev/null; then
    ok "$schema $key = $value"
  else
    warn "no se pudo fijar $schema $key"
  fi
}

find_schema_by_keyword() {
  local kw="$1" key="$2" s
  while IFS= read -r s; do
    case "$s" in
      *"$kw"*)
        if has_key "$s" "$key"; then
          printf '%s\n' "$s"
          return 0
        fi
        ;;
    esac
  done < <(gsettings list-schemas 2>/dev/null)
  return 1
}

set_show_thumbnails() {
  local schema="$1" cur lim lim_num
  cur="$(gsettings get "$schema" show-image-thumbnails 2>/dev/null || echo unknown)"
  case "$cur" in
    "'always'"|"'local-only'")
      ok "$schema: show-image-thumbnails=$cur" ;;
    *)
      state_record gsettings "$schema" show-image-thumbnails "$cur"
      gset_set "$schema" show-image-thumbnails "'local-only'"
      ;;
  esac

  if has_key "$schema" thumbnail-limit; then
    lim="$(gsettings get "$schema" thumbnail-limit 2>/dev/null || echo 0)"
    lim_num="${lim#uint64 }"
    if [ "$lim_num" = "0" ]; then
      warn "$schema: thumbnail-limit=0 (nada se miniaturiza); se fija a $THUMB_SIZE_DEFAULT"
      state_record gsettings "$schema" thumbnail-limit "$lim"
      gset_set "$schema" thumbnail-limit "uint64 $THUMB_SIZE_DEFAULT"
    else
      ok "$schema: thumbnail-limit=$lim"
    fi
  fi
}

enable_show_thumbs() {
  local preferred="$1" kw="$2" label="$3" schema=""
  if [ -n "$preferred" ] && schema_exists "$preferred" && has_key "$preferred" show-image-thumbnails; then
    schema="$preferred"
  else
    schema="$(find_schema_by_keyword "$kw" show-image-thumbnails || true)"
  fi
  if [ -z "$schema" ]; then
    warn "no se encontro la clave show-image-thumbnails para $label"
    return 0
  fi
  set_show_thumbnails "$schema"
}

enable_external_thumbnailers() {
  local schema dis new
  for schema in org.cinnamon.desktop.thumbnailers \
                org.gnome.desktop.thumbnailers \
                org.mate.thumbnailers; do
    schema_exists "$schema" || continue
    if [ "$(gsettings get "$schema" disable-all 2>/dev/null)" = "true" ]; then
      state_record gsettings "$schema" disable-all "true"
      gset_set "$schema" disable-all "false"
    else
      ok "$schema: thumbnailers externos habilitados (disable-all=false)"
    fi
    if has_key "$schema" disable; then
      dis="$(gsettings get "$schema" disable 2>/dev/null || echo '[]')"
      case "$dis" in
        *fcstd*|*FCStd*)
          new="$(printf '%s' "$dis" | python3 -c '
import ast, sys
s = sys.stdin.read().strip()
if s.startswith("@as "):
    s = s[4:]
try:
    items = ast.literal_eval(s)
except Exception:
    print("[]")
    raise SystemExit
print(repr([x for x in items if "fcstd" not in str(x).lower()]))
')" || new=""
          if [ -n "$new" ]; then
            state_record gsettings "$schema" disable "$dis"
            gset_set "$schema" disable "$new"
          fi
          ;;
        *)
          ok "$schema: .fcstd no esta bloqueado (disable=$dis)"
          ;;
      esac
    fi
  done
}

enable_thunar() {
  local prop="/misc-thumbnail-mode" cur
  if ! command -v xfconf-query >/dev/null 2>&1; then
    warn "xfconf-query no disponible: no se pudo configurar Thunar"
    return 0
  fi
  cur="$(xfconf-query -c thunar -p "$prop" 2>/dev/null || true)"
  case "$cur" in
    ONLY_LOCAL|ALWAYS)
      ok "Thunar: misc-thumbnail-mode=$cur" ;;
    *)
      state_record xfconf thunar "$prop" "$cur"
      if [ "$DRY_RUN" = "1" ]; then
        printf '%s dry-run%s xfconf-query -c thunar -p %s --create --type string --set ONLY_LOCAL\n' \
          "$C_BLU" "$C_RST" "$prop"
      elif xfconf-query -c thunar -p "$prop" --create --type string --set ONLY_LOCAL 2>/dev/null; then
        ok "Thunar: misc-thumbnail-mode=ONLY_LOCAL"
      else
        warn "no se pudo fijar misc-thumbnail-mode en Thunar"
      fi
      ;;
  esac
}

enable_dolphin() {
  local rc="$HOME/.config/dolphinrc" backup="" ids="" f stem plugin_desktop
  if [ ! -f "$rc" ]; then
    warn "no existe ~/.config/dolphinrc (abre Dolphin una vez y vuelve a ejecutar)"
    return 0
  fi
  if pgrep -x dolphin >/dev/null 2>&1; then
    warn "Dolphin esta abierto: cierralo y vuelve a ejecutar el script para aplicar la vista previa"
    return 0
  fi

  if command -v plasmashell >/dev/null 2>&1; then
    local plv
    plv="$(plasmashell --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || true)"
    if [ -n "$plv" ]; then
      case "$plv" in
        6.[0-5]|5.*|[0-4].*)
          warn "Plasma $plv: el soporte estandar de .thumbnailer llega en Plasma 6.6 (instala kde-fcstd-thumbnailer)" ;;
        *)
          ok "Plasma $plv: admite thumbnailers estandar de freedesktop" ;;
      esac
    fi
  fi

  for f in "$DATA_HOME/thumbnailers"/*.thumbnailer /usr/share/thumbnailers/*.thumbnailer; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
      *[Ff]ree[Cc][Aa][Dd]*|*fcstd*) stem="$(basename "$f" .thumbnailer)"; ids="$ids $stem" ;;
    esac
  done
  ids="$ids fcstdthumbnailer fcstd freecad FreeCAD"

  for plugin_desktop in \
       /usr/share/kf5/kio/thumbnail/fcstdthumbnailer.desktop \
       /usr/share/kio/thumbnail/fcstdthumbnailer.desktop \
       /usr/share/kservices5/fcstdthumbnailer.desktop; do
    [ -f "$plugin_desktop" ] || continue
    stem="$(basename "$plugin_desktop" .desktop)"
    ids="$ids $stem"
  done

  if grep -q '^Plugins=' "$rc"; then
    backup="$rc.bak-thumbnailer"
    if [ ! -f "$backup" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        printf '%s dry-run%s crearia copia de seguridad de %s\n' "$C_BLU" "$C_RST" "$rc"
      else
        cp -f "$rc" "$backup"
        state_record file "$rc" "$backup"
        ok "Dolphin: copia de seguridad en $backup"
      fi
    fi
    local current add="" id
    current="$(grep '^Plugins=' "$rc" | head -1 | cut -d= -f2-)"
    for id in $ids; do
      case ",$current," in
        *",$id,"*) : ;;
        *) add="$add,$id" ;;
      esac
    done
    if [ -n "$add" ]; then
      if [ "$DRY_RUN" = "1" ]; then
        printf '%s dry-run%s anadiri a [PreviewSettings] Plugins de dolphinrc: %s\n' \
          "$C_BLU" "$C_RST" "${add#,}"
      else
        sed -i "s|^Plugins=.*|Plugins=$current$add|" "$rc"
        ok "Dolphin: plugins de vista previa anadidos (${add#,})"
      fi
    else
      ok "Dolphin: el plugin de FreeCAD ya esta en la lista de vista previa"
    fi
  else
    ok "Dolphin: usara la lista de vista previa por defecto (no hay Plugins= en dolphinrc)"
  fi
  return 0
}

enable_thumbnails() {
  step "Habilitando la previsualizacion en el explorador"

  enable_external_thumbnailers || true

  if [ "$FM_NEMO" = "1" ]; then
    enable_show_thumbs "org.nemo.preferences" "nemo" "Nemo"
  fi
  if [ "$FM_NAUTILUS" = "1" ]; then
    enable_show_thumbs "org.gnome.nautilus.preferences" "nautilus" "Nautilus"
  fi
  if [ "$FM_CAJA" = "1" ]; then
    enable_show_thumbs "org.mate.caja.preferences" "caja" "Caja"
  fi
  if [ "$FM_THUNAR" = "1" ]; then
    enable_thunar
  fi
  if [ "$FM_DOLPHIN" = "1" ]; then
    enable_dolphin
  fi
  if [ "$FM_PCMANFM" = "1" ]; then
    ok "PCManFM: usa los thumbnailers estandar ya instalados"
  fi

  if [ "$FM_OK" = "0" ]; then
    warn "ningun explorador configurado: solo se instalaron los ficheros estandar"
  fi
  return 0
}

# ===========================================================================
# fase 9: cache de miniaturas y reinicio
# ===========================================================================
clear_cache() {
  step "Limpiando la cache de miniaturas"
  if [ ! -d "$CACHE_HOME/thumbnails" ]; then
    ok "no habia cache que limpiar"
    return 0
  fi
  run rm -rf "$CACHE_HOME/thumbnails/fail"
  if [ "$FULL_CACHE" = "1" ]; then
    local sub
    for sub in normal large x-large xx-large small; do
      if [ -d "$CACHE_HOME/thumbnails/$sub" ]; then
        run rm -rf "$CACHE_HOME/thumbnails/$sub"
      fi
    done
    ok "cache completa borrada: $CACHE_HOME/thumbnails (se regenerara sola)"
  else
    ok "fallos de miniatura borrados: $CACHE_HOME/thumbnails/fail"
    ok "usa --full-cache si quieres vaciar tambien las miniaturas ya generadas"
  fi
}

restart_filemanagers() {
  local restarted=""
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s dry-run%s no reinicia el explorador (se hace solo si lo decides)\n' "$C_BLU" "$C_RST"
    return 0
  fi
  if [ "$FM_NEMO" = "1" ] && pgrep -x nemo >/dev/null 2>&1; then
    nemo -q 2>/dev/null || true; restarted="$restarted nemo"
  fi
  if [ "$FM_NAUTILUS" = "1" ] && pgrep -x nautilus >/dev/null 2>&1; then
    nautilus -q 2>/dev/null || true; restarted="$restarted nautilus"
  fi
  if [ "$FM_CAJA" = "1" ] && pgrep -x caja >/dev/null 2>&1; then
    caja -q 2>/dev/null || true; restarted="$restarted caja"
  fi
  if [ "$FM_THUNAR" = "1" ] && pgrep -x thunar >/dev/null 2>&1; then
    thunar -q 2>/dev/null || true; restarted="$restarted thunar"
  fi
  if [ -n "$restarted" ]; then
    step "Reiniciando explorador"
    ok "cerrado:$restarted (volvera a abrirse con el escritorio)"
  fi
  if [ "$FM_DOLPHIN" = "1" ] && pgrep -x dolphin >/dev/null 2>&1; then
    warn "Dolphin sigue abierto: cierralo y abre de nuevo para ver los cambios"
  fi
}

# ===========================================================================
# fase 10: verificacion
# ===========================================================================
create_test_fcstd() {
  python3 - "$1" <<'PYEOF'
import base64
import os
import sys
import zipfile

dest = sys.argv[1]
png = None
for cand in (
    os.path.expanduser("~/.local/share/icons/hicolor/48x48/apps/freecad.png"),
    "/usr/share/icons/hicolor/48x48/apps/freecad.png",
    "/var/lib/flatpak/exports/share/icons/hicolor/48x48/apps/org.freecad.FreeCAD.png",
):
    try:
        with open(cand, "rb") as fh:
            png = fh.read()
            break
    except OSError:
        continue
if png is None:
    png = base64.b64decode(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
    )
with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.writestr("Document.xml", "<?xml version='1.0'?><Document/>")
    zf.writestr("thumbnails/Thumbnail.png", png)
PYEOF
}

factory_generate() {
  python3 - "$1" <<'PYEOF'
import os
import sys

try:
    import gi
except Exception as exc:
    print("  aviso: pygobject no disponible (%s)" % exc)
    sys.exit(1)

path = sys.argv[1]
factory_mod = None
for name, ver in (("CinnamonDesktop", "3.0"), ("GNOMEDesktop", "3.0"), ("MateDesktop", "2.0")):
    try:
        gi.require_version(name, ver)
        repo = __import__("gi.repository", fromlist=[name])
        mod = getattr(repo, name)
        if hasattr(mod, "DesktopThumbnailFactory"):
            factory_mod = mod
            break
    except Exception:
        continue

if factory_mod is None:
    print("  aviso: no hay fabrica de miniaturas (CinnamonDesktop/GNOMEDesktop/MateDesktop)")
    sys.exit(1)

from gi.repository import GLib

uri = GLib.filename_to_uri(os.path.abspath(path), None)
mtime = int(os.path.getmtime(path))
mime = "application/x-extension-fcstd"
size = None
for enum_name in ("DesktopThumbnailSize", "ThumbnailSize"):
    enum = getattr(factory_mod, enum_name, None)
    if enum is not None and hasattr(enum, "NORMAL"):
        size = enum.NORMAL
        break
if size is None:
    size = 128
try:
    factory = factory_mod.DesktopThumbnailFactory.new(size)
except TypeError:
    factory = factory_mod.DesktopThumbnailFactory.new(128)
if not factory.can_thumbnail(uri, mime, mtime):
    print("  aviso: la fabrica rechaza %s" % mime)
    sys.exit(1)
try:
    pix = factory.generate_thumbnail(uri, mime)
except Exception as exc:
    print("  aviso: generate_thumbnail fallo: %s" % exc)
    sys.exit(1)
if pix is None:
    print("  aviso: generate_thumbnail devolvio None")
    sys.exit(1)
factory.save_thumbnail(pix, uri, mtime)
print("  ok  miniatura creada por la fabrica del escritorio (%dx%d)"
      % (pix.get_width(), pix.get_height()))
PYEOF
}

verify() {
  step "Verificando"
  local TEST_DIR TEST_FCSTD TEST_OUT mime
  if [ ! -x "$BIN_PATH" ]; then
    err "no existe $BIN_PATH (ejecuta el script sin --test)"
    exit 1
  fi

  TEST_DIR="$(mktemp -d /tmp/fcstd-test.XXXXXX)"
  TEST_FCSTD="$TEST_DIR/prueba.FCStd"
  TEST_OUT="$TEST_DIR/out.png"
  create_test_fcstd "$TEST_FCSTD"

  if "$BIN_PATH" -s 128 "$TEST_FCSTD" "$TEST_OUT" && [ -s "$TEST_OUT" ]; then
    if head -c 8 "$TEST_OUT" | grep -q "PNG"; then
      ok "miniatura generada correctamente (PNG)"
    else
      warn "el fichero de salida no es PNG"
    fi
  else
    err "el script de miniaturas fallo"
    rm -rf "$TEST_DIR"
    exit 1
  fi

  if command -v xdg-mime >/dev/null 2>&1; then
    mime="$(xdg-mime query filetype "$TEST_FCSTD" 2>/dev/null || echo '?')"
    case "$mime" in
      application/x-extension-fcstd|application/x-freecad*) ok "tipo MIME: $mime" ;;
      *) warn "tipo MIME detectado: $mime (se esperaba application/x-extension-fcstd)" ;;
    esac
  fi

  if factory_generate "$TEST_FCSTD"; then
    ok "integracion con el escritorio verificada"
    if [ -d "$CACHE_HOME/thumbnails/fail" ] && [ "$DRY_RUN" != "1" ]; then
      rm -rf "$CACHE_HOME/thumbnails/fail"
    fi
  else
    warn "no se pudo verificar por la fabrica del escritorio (el thumbnailer manual si funciona)"
  fi

  rm -rf "$TEST_DIR"
  return 0
}

# ===========================================================================
# fase 11: demo
# ===========================================================================
make_demo() {
  step "Creando archivo de prueba"
  local dir
  dir="$(xdg-user-dir DESKTOP 2>/dev/null || true)"
  [ -d "$dir" ] || dir="$HOME"
  local demo="$dir/prueba-FreeCAD.FCStd"
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s dry-run%s crearia %s\n' "$C_BLU" "$C_RST" "$demo"
    return 0
  fi
  create_test_fcstd "$demo"
  ok "archivo de prueba: $demo"
  if factory_generate "$demo" >/dev/null 2>&1; then
    ok "miniatura ya generada: veras el icono al abrir el explorador en $dir"
  else
    ok "abre el explorador en $dir para que genere la miniatura"
  fi
}

# ===========================================================================
# fase 12: desinstalacion
# ===========================================================================
remove_installed_files() {
  local p dir removed=0
  for p in \
      "$HOME/.local/bin/freecad-thumbnailer.py" \
      "$DATA_HOME/thumbnailers/FreeCAD.thumbnailer" \
      "$DATA_HOME/mime/packages/org.freecadweb.FreeCAD.xml" \
      "$DATA_HOME/icons/hicolor/48x48/apps/freecad.png" \
      "/usr/bin/freecad-thumbnailer.py" \
      "/usr/share/thumbnailers/FreeCAD.thumbnailer" \
      "/usr/share/mime/packages/org.freecadweb.FreeCAD.xml" \
      "/usr/share/icons/hicolor/48x48/apps/freecad.png"; do
    if [ ! -e "$p" ]; then
      continue
    fi
    if [ "$DRY_RUN" = "1" ]; then
      printf '%s dry-run%s borraria %s\n' "$C_BLU" "$C_RST" "$p"
      continue
    fi
    dir="$(dirname "$p")"
    if [ -w "$dir" ]; then
      if rm -f "$p"; then
        ok "eliminado $p"
        removed=1
      fi
    elif [ "$(id -u)" -ne 0 ] && sudo -n true 2>/dev/null; then
      if sudo rm -f "$p"; then
        ok "eliminado $p"
        removed=1
      fi
    else
      warn "no se pudo borrar $p (requiere sudo: repite el desinstalado como root)"
    fi
  done
  if [ "$removed" = "1" ]; then
    if [ -d "$DATA_HOME/mime" ]; then
      update-mime-database "$DATA_HOME/mime" >/dev/null 2>&1 || true
    fi
    sudo -n update-mime-database /usr/share/mime >/dev/null 2>&1 || true
  fi
  return 0
}

restore_state() {
  [ -f "$STATE_FILE" ] || return 0
  step "Restaurando ajustes previos"
  local typ a b c
  while IFS='|' read -r typ a b c; do
    [ -n "$typ" ] || continue
    case "$typ" in
      gsettings)
        if [ "$DRY_RUN" = "1" ]; then
          printf '%s dry-run%s restauraria %s %s = %s\n' "$C_BLU" "$C_RST" "$a" "$b" "$c"
        elif gsettings set "$a" "$b" "$c" 2>/dev/null; then
          ok "restaurado $a $b=$c"
        else
          warn "no se pudo restaurar $a $b"
        fi
        ;;
      xfconf)
        if [ "$DRY_RUN" = "1" ]; then
          printf '%s dry-run%s restauraria xfconf %s %s\n' "$C_BLU" "$C_RST" "$a" "$b"
        elif [ -n "$c" ]; then
          if xfconf-query -c "$a" -p "$b" --set "$c" >/dev/null 2>&1; then
            ok "restaurado xfconf $b=$c"
          else
            warn "no se pudo restaurar $b"
          fi
        else
          if xfconf-query -c "$a" -p "$b" -r >/dev/null 2>&1; then
            ok "eliminada la propiedad $b"
          fi
        fi
        ;;
      file)
        if [ -f "$b" ]; then
          if cp -f "$b" "$a" 2>/dev/null; then
            ok "restaurado $a"
          else
            warn "no se pudo restaurar $a"
          fi
        fi
        ;;
    esac
  done <"$STATE_FILE"
}

restore_freecad_cfg() {
  local p
  if pgrep -x FreeCAD >/dev/null 2>&1 || pgrep -x freecad >/dev/null 2>&1; then
    warn "FreeCAD esta abierto: no se restaura su configuracion"
    return 0
  fi
  for p in "$HOME/.config/FreeCAD/user.cfg" \
           "$HOME"/.config/FreeCAD/*/user.cfg \
           "$HOME"/.var/app/org.freecad.FreeCAD/config/FreeCAD/*/user.cfg; do
    [ -f "$p.bak-thumbnailer" ] || continue
    if [ "$DRY_RUN" = "1" ]; then
      printf '%s dry-run%s restauraria %s desde %s.bak-thumbnailer\n' \
        "$C_BLU" "$C_RST" "$p" "$p"
    elif cp -f "$p.bak-thumbnailer" "$p"; then
      ok "restaurado $p"
    else
      warn "no se pudo restaurar $p"
    fi
  done
  return 0
}

do_uninstall() {
  step "Desinstalando"
  restore_state
  restore_freecad_cfg
  remove_installed_files
  if [ "$DRY_RUN" = "1" ]; then
    printf '%s dry-run%s no se borra el estado ni la cache de miniaturas\n' "$C_BLU" "$C_RST"
    printf '%s dry-run%s desinstalacion simulada: no se ha cambiado nada\n' "$C_BLU" "$C_RST"
    return 0
  fi
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
  fi
  if [ -d "$CACHE_HOME/thumbnails" ]; then
    rm -rf "$CACHE_HOME/thumbnails/fail" 2>/dev/null || true
  fi
  restart_filemanagers
  ok "desinstalado; vuelve a ejecutar el script sin --uninstall para instalarlo"
}

# ===========================================================================
# fase 13: estado / diagnostico
# ===========================================================================
cmd_status() {
  local def mime script_state entry_state cache_files cache_size status_tmp
  check_os 1
  check_filemanager 1

  if [ -z "${BIN_PATH:-}" ]; then
    choose_mode
  fi

  echo
  printf '%s== Diagnostico (freecad-thumbnailer-setup %s)%s\n' "$C_BLD" "$SCRIPT_VERSION" "$C_RST"
  printf '  SO                  : %s (ID=%s, ID_LIKE=%s) familia=%s gestor=%s%s\n' \
    "${OS_NAME:-?}" "${OS_ID:-?}" "${OS_LIKE:-?}" "${OS_FAMILY:-?}" "$PKG_MGR" \
    "$([ "$IS_IMMUTABLE" = "1" ] && echo ' [inmutable]')"
  printf '  SO version          : %s\n' "${OS_VERSION:-?}"
  printf '  SO compatible       : %s\n' "$([ "$OS_OK" = "1" ] && echo si || echo no)"
  printf '  explorador(es)      : %s\n' "${FM_LIST:-ninguno compatible}"
  def="$(xdg-mime query default inode/directory 2>/dev/null || echo '?')"
  printf '  explorador xdg      : %s\n' "$def"
  printf '  sesión              : %s\n' "${XDG_CURRENT_DESKTOP:-?}"
  printf '  modo de instalacion : %s\n' "$MODE"

  if [ -x "$BIN_PATH" ]; then script_state="instalado ($BIN_PATH)"; else script_state="NO instalado"; fi
  if [ -f "$THUMB_ENTRY" ]; then entry_state="instalado ($THUMB_ENTRY)"; else entry_state="NO instalado"; fi
  printf '  script              : %s\n' "$script_state"
  printf '  thumbnailer         : %s\n' "$entry_state"
  printf '  icono de respaldo   : %s\n' "$([ -f "$ICON_PATH" ] && echo si || echo no)"

  status_tmp="$(mktemp /tmp/fcstatus-mime.XXXXXX 2>/dev/null || echo "/tmp/fcstatus-mime.$$.FCStd")"
  create_test_fcstd "$status_tmp" 2>/dev/null || true
  mime="$(xdg-mime query filetype "$status_tmp" 2>/dev/null || echo '?')"
  printf '  tipo MIME .FCStd    : %s\n' "$mime"
  rm -f "$status_tmp"

  local schema
  for schema in org.cinnamon.desktop.thumbnailers org.gnome.desktop.thumbnailers org.mate.thumbnailers; do
    schema_exists "$schema" || continue
    printf '  %-19s: disable-all=%s disable=%s\n' "$schema" \
      "$(gsettings get "$schema" disable-all 2>/dev/null)" \
      "$(gsettings get "$schema" disable 2>/dev/null)"
  done
  if [ "$FM_NEMO" = "1" ] && schema_exists org.nemo.preferences; then
    printf '  show-image-thumbnails: %s (nemo)\n' "$(gsettings get org.nemo.preferences show-image-thumbnails 2>/dev/null)"
  fi
  if [ "$FM_NAUTILUS" = "1" ] && schema_exists org.gnome.nautilus.preferences; then
    printf '  show-image-thumbnails: %s (nautilus)\n' "$(gsettings get org.gnome.nautilus.preferences show-image-thumbnails 2>/dev/null)"
  fi
  if [ "$FM_CAJA" = "1" ] && schema_exists org.mate.caja.preferences; then
    printf '  show-image-thumbnails: %s (caja)\n' "$(gsettings get org.mate.caja.preferences show-image-thumbnails 2>/dev/null)"
  fi
  if [ "$FM_THUNAR" = "1" ] && command -v xfconf-query >/dev/null 2>&1; then
    printf '  thumbnail-mode       : %s (thunar)\n' \
      "$(xfconf-query -c thunar -p /misc-thumbnail-mode 2>/dev/null || echo 'no definido')"
  fi

  detect_freecad
  printf '  FreeCAD             : %s\n' "$FREECAD_DESC"
  grep -q 'SaveThumbnail" Value="1"' "$HOME/.config/FreeCAD/user.cfg" 2>/dev/null \
    && printf '  SaveThumbnail       : activo (%s)\n' "$HOME/.config/FreeCAD/user.cfg" \
    || printf '  SaveThumbnail       : revisar en FreeCAD (Editar > Preferencias > Documento)\n'

  if [ -d "$CACHE_HOME/thumbnails" ]; then
    cache_files="$(find "$CACHE_HOME/thumbnails" -name '*.png' 2>/dev/null | wc -l || true)"
    cache_size="$(du -sh "$CACHE_HOME/thumbnails" 2>/dev/null | cut -f1 || true)"
    printf '  cache               : %s ficheros, %s\n' "$cache_files" "${cache_size:-?}"
    printf '  fallos en cache     : %s\n' "$(find "$CACHE_HOME/thumbnails/fail" -type f 2>/dev/null | wc -l || true)"
  else
    printf '  cache               : no existe\n'
  fi

  if [ -x "$BIN_PATH" ]; then
    local tdir
    tdir="$(mktemp -d /tmp/fcstatus.XXXXXX)"
    create_test_fcstd "$tdir/t.FCStd"
    if "$BIN_PATH" -s 128 "$tdir/t.FCStd" "$tdir/out.png" 2>/dev/null && [ -s "$tdir/out.png" ]; then
      printf '  prueba thumbnailer  : OK\n'
    else
      printf '  prueba thumbnailer  : FALLO\n'
    fi
    factory_generate "$tdir/t.FCStd" >/dev/null 2>&1 \
      && printf '  fabrica del escrit. : OK\n' \
      || printf '  fabrica del escrit. : no disponible/fallo\n'
    rm -rf "$tdir"
  fi

  printf '  log                 : %s\n' "$LOG_FILE"
  printf '  estado guardado     : %s\n' "$([ -f "$STATE_FILE" ] && echo "$STATE_FILE" || echo 'sin cambios que restaurar')"
  echo
  if [ "$FM_NEMO" = "1" ]; then
    printf '  Nemo: Ver > Vista de iconos; Editar > Preferencias > Previsualizacion = Archivos locales\n'
  fi
  if [ "$FM_DOLPHIN" = "1" ]; then
    printf '  Dolphin: Configurar Dolphin > General > Previsualizaciones > FreeCAD\n'
  fi
  if [ "$FM_THUNAR" = "1" ]; then
    printf '  Thunar: Editar > Preferencias > Mostrar miniaturas\n'
  fi
  echo
  return 0
}

# ===========================================================================
# resumen
# ===========================================================================
summary() {
  echo
  if [ "$DRY_RUN" = "1" ]; then
    printf '%sDry-run finalizado: no se ha cambiado nada.%s\n' "$C_BLD" "$C_RST"
  else
    printf '%sListo.%s\n' "$C_BLD" "$C_RST"
  fi
  cat <<EOF
  SO / gestor          : $OS_NAME / $PKG_MGR$([ "$IS_IMMUTABLE" = "1" ] && echo ' (inmutable)')
  explorador(es)       : ${FM_LIST:-ninguno compatible}
  modo de instalacion  : $MODE
  script               : $BIN_PATH
  thumbnailer          : $THUMB_ENTRY
  tipo MIME            : $MIME_XML
  icono de respaldo    : $ICON_PATH
EOF
  if [ "$NEED_REBOOT" = "1" ]; then
    warn "reinicia el sistema para aplicar los paquetes instalados con rpm-ostree"
  fi
  echo
  printf '%sComo verlo:%s\n' "$C_BLD" "$C_RST"
  if [ "$FM_NEMO" = "1" ]; then
    printf '  Nemo     : Ver > Vista de iconos; Editar > Preferencias > Previsualizacion = Archivos locales\n'
  fi
  if [ "$FM_NAUTILUS" = "1" ]; then
    printf '  Nautilus : Preferencias > Vista previa > Miniaturas = Archivos locales\n'
  fi
  if [ "$FM_DOLPHIN" = "1" ]; then
    printf '  Dolphin  : Configurar Dolphin > General > Previsualizaciones > marcar FreeCAD\n'
  fi
  if [ "$FM_THUNAR" = "1" ]; then
    printf '  Thunar   : Editar > Preferencias > Mostrar miniaturas (ya activado por xfconf)\n'
  fi
  if [ "$FM_CAJA" = "1" ]; then
    printf '  Caja     : Editar > Preferencias > Vista previa > Mostrar miniaturas\n'
  fi
  if [ "$FM_PCMANFM" = "1" ]; then
    printf '  PCManFM  : Preferencias > Mostrar miniaturas\n'
  fi
  cat <<EOF
  FreeCAD  : Editar > Preferencias > General > Documento >
             "Guardar la miniatura en el archivo del proyecto al guardar"
  Si una miniatura vieja no aparece:  rm -rf ~/.cache/thumbnails/fail && <explorador> -q

Comandos utiles:
  $0                     (sin argumentos) abre el panel de estado y el menu
  $0 --status      diagnostico completo
  $0 --demo        crea un .FCStd de prueba en el escritorio
  $0 --dry-run     ver que haria sin cambiar nada
  $0 --uninstall   desinstala y restaura los ajustes previos
EOF
}

# ===========================================================================
# panel de inicio y menu interactivo
# ===========================================================================
detect_freecad() {
  FREECAD_DESC="no detectado"
  FREECAD_OK=0
  if command -v flatpak >/dev/null 2>&1 && flatpak info org.freecad.FreeCAD >/dev/null 2>&1; then
    FREECAD_DESC="flatpak org.freecad.FreeCAD $(flatpak info org.freecad.FreeCAD 2>/dev/null | sed -nE 's/^[[:space:]]*[Vv]ersi[^:]*: *//p' | head -1 || true)"
    FREECAD_OK=1
  elif command -v freecad >/dev/null 2>&1; then
    FREECAD_DESC="freecad ($(command -v freecad))"
    FREECAD_OK=1
  elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -qi freecad; then
    FREECAD_DESC="snap freecad"
    FREECAD_OK=1
  fi
  return 0
}

# cuenta el modulo instalado en el usuario y en el sistema (solo lectura)
module_state() {
  local u_data s_cnt=0 u_cnt=0
  u_data="${XDG_DATA_HOME:-$HOME/.local/share}"

  if [ -x "$HOME/.local/bin/freecad-thumbnailer.py" ]; then u_cnt=$((u_cnt + 1)); fi
  if [ -f "$u_data/thumbnailers/FreeCAD.thumbnailer" ]; then u_cnt=$((u_cnt + 1)); fi
  if [ -f "$u_data/mime/packages/org.freecadweb.FreeCAD.xml" ]; then u_cnt=$((u_cnt + 1)); fi
  if [ -f "$u_data/icons/hicolor/48x48/apps/freecad.png" ]; then u_cnt=$((u_cnt + 1)); fi

  if [ -x "/usr/bin/freecad-thumbnailer.py" ]; then s_cnt=$((s_cnt + 1)); fi
  if [ -f "/usr/share/thumbnailers/FreeCAD.thumbnailer" ]; then s_cnt=$((s_cnt + 1)); fi
  if [ -f "/usr/share/mime/packages/org.freecadweb.FreeCAD.xml" ]; then s_cnt=$((s_cnt + 1)); fi
  if [ -f "/usr/share/icons/hicolor/48x48/apps/freecad.png" ]; then s_cnt=$((s_cnt + 1)); fi

  MOD_OK=0
  MOD_MODE="ninguno"
  MOD_DETAIL="NO instalado (0/4)"
  if [ "$u_cnt" -ge 2 ] || [ "$s_cnt" -ge 2 ]; then
    MOD_OK=1
    if [ "$u_cnt" -ge "$s_cnt" ]; then
      MOD_MODE="user"; MOD_DETAIL="instalado (user, $u_cnt/4)"
    else
      MOD_MODE="system"; MOD_DETAIL="instalado (system, $s_cnt/4)"
    fi
    if [ "$u_cnt" -gt 0 ] && [ "$s_cnt" -gt 0 ] && [ "$u_cnt" -ne "$s_cnt" ]; then
      MOD_DETAIL="instalado (user $u_cnt/4, system $s_cnt/4)"
    fi
  fi
  return 0
}

# estado de la previsualizacion (explorador + FreeCAD)
preview_state() {
  local thumb="" schema="" save=""

  if [ "$FM_NEMO" = "1" ]; then thumb="nemo show-image-thumbnails=$(gsettings get org.nemo.preferences show-image-thumbnails 2>/dev/null || echo '?')"
  elif [ "$FM_NAUTILUS" = "1" ]; then thumb="nautilus show-image-thumbnails=$(gsettings get org.gnome.nautilus.preferences show-image-thumbnails 2>/dev/null || echo '?')"
  elif [ "$FM_CAJA" = "1" ]; then thumb="caja show-image-thumbnails=$(gsettings get org.mate.caja.preferences show-image-thumbnails 2>/dev/null || echo '?')"
  elif [ "$FM_THUNAR" = "1" ]; then thumb="thunar thumbnail-mode=$(xfconf-query -c thunar -p /misc-thumbnail-mode 2>/dev/null || echo 'no definido')"
  elif [ "$FM_DOLPHIN" = "1" ]; then thumb="dolphin previsualizacion FreeCAD"
  elif [ "$FM_PCMANFM" = "1" ]; then thumb="pcmanfm thumbnailers estandar"
  fi
  [ -n "$thumb" ] || thumb="explorador no detectado"

  for schema in org.cinnamon.desktop.thumbnailers org.gnome.desktop.thumbnailers org.mate.thumbnailers; do
    if schema_exists "$schema" && [ "$(gsettings get "$schema" disable-all 2>/dev/null || echo true)" = "true" ]; then
      thumb="$thumb; $schema disable-all=true (thumbnailers externos OFF)"
      break
    fi
  done

  if grep -q 'SaveThumbnail" Value="1"' "$HOME/.config/FreeCAD/user.cfg" 2>/dev/null \
     || grep -q 'SaveThumbnail" Value="1"' "$HOME/.var/app/org.freecad.FreeCAD/config/FreeCAD/user.cfg" 2>/dev/null \
     || grep -q 'SaveThumbnail" Value="1"' "$HOME/.var/app/org.freecad.FreeCAD/config/FreeCAD/v1-1/user.cfg" 2>/dev/null; then
    save="FreeCAD SaveThumbnail=activo"
  else
    save="FreeCAD SaveThumbnail=off"
  fi

  printf '%s; %s' "$thumb" "$save"
  return 0
}

show_panel() {
  local os_txt immu def fc_txt mod_txt
  detect_freecad
  module_state
  check_os 1 >/dev/null
  check_filemanager 1 >/dev/null
  choose_mode quiet

  def="$(xdg-mime query default inode/directory 2>/dev/null || echo '?')"
  immu=""
  if [ "$IS_IMMUTABLE" = "1" ]; then immu=" [inmutable]"; fi
  if [ "$OS_OK" = "1" ]; then os_txt="compatible"; else os_txt="NO compatible"; fi

  fc_txt="$FREECAD_DESC"
  if [ "$FREECAD_OK" = "1" ]; then
    fc_txt="$C_GRN$fc_txt$C_RST"
  else
    fc_txt="$C_YEL$fc_txt (los .FCStd sin miniatura embebida usaran el icono generico)$C_RST"
  fi

  mod_txt="$MOD_DETAIL"
  if [ "$MOD_OK" = "1" ]; then
    mod_txt="$C_GRN$mod_txt$C_RST"
    if [ "$MOD_MODE" != "$MODE" ]; then
      mod_txt="$mod_txt (instalado en modo $MOD_MODE; este modo es $MODE)"
    fi
  else
    mod_txt="$C_YEL$mod_txt$C_RST"
  fi

  echo
  printf '%s== freecad-thumbnailer-setup %s — panel de inicio%s\n' "$C_BLD" "$SCRIPT_VERSION" "$C_RST"
  printf '  %-17s: %s — %s (%s, gestor %s)%s\n' "SO" "${OS_NAME:-?}" "$os_txt" \
    "${OS_FAMILY:-sin familia}" "$PKG_MGR" "$immu"
  printf '  %-17s: %s\n' "FreeCAD" "$fc_txt"
  printf '  %-17s: %s (xdg: %s, sesion: %s)\n' "Explorador(es)" \
    "${FM_LIST:-ninguno compatible}" "$def" "${XDG_CURRENT_DESKTOP:-?}"
  printf '  %-17s: %s\n' "Modulo (MOD)" "$mod_txt"
  printf '  %-17s: %s\n' "Previsualizacion" "$(preview_state)"
  printf '  %-17s: %s\n' "Modo instalacion" "$MODE"
  return 0
}

menu() {
  local ans=""
  MENU_ACTION="quit"
  show_panel
  echo
  printf '  %s1%s Instalar      (ficheros, ajustes de FreeCAD/explorador y verificacion)\n' "$C_BLD" "$C_RST"
  if [ "$MOD_OK" = "1" ]; then
    printf '  %s2%s Desinstalar   (quita el modulo y restaura los ajustes previos)\n' "$C_BLD" "$C_RST"
  else
    printf '  %s2%s Desinstalar   (ahora mismo no hay nada instalado)\n' "$C_BLD" "$C_RST"
  fi
  printf '  %sq%s Salir\n' "$C_BLD" "$C_RST"
  echo

  while true; do
    printf '  %sSeleccion: %s' "$C_YEL" "$C_RST"
    if ! read -r ans; then
      printf '\n'
      log "menu: fin de entrada (EOF)"
      MENU_ACTION="quit"
      return 0
    fi
    case "$ans" in
      1|I|i) MENU_ACTION="install";   log "menu: opcion 1 (instalar)";   return 0 ;;
      2|D|d) MENU_ACTION="uninstall"; log "menu: opcion 2 (desinstalar)"; return 0 ;;
      q|Q)   MENU_ACTION="quit";      log "menu: opcion q (salir)";      return 0 ;;
      *) printf '    opcion no valida: escribe 1, 2 o q\n' ;;
    esac
  done
}

# ===========================================================================
# principal
# ===========================================================================
main() {
  local total_args=$#
  parse_args "$@"
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  log "---- inicio (args: $*) v$SCRIPT_VERSION ----"

  if [ "$WANT_STATUS" = "1" ]; then
    cmd_status
    exit 0
  fi

  # sin argumentos y con terminal: panel de estado + menu interactivo
  if [ "$total_args" -eq 0 ] && [ -t 0 ]; then
    menu
    if [ "$MENU_ACTION" = "quit" ]; then
      log "menu: salir sin cambios"
      printf '\n  %sNada que hacer. Adios.%s\n' "$C_RST" "$C_RST"
      exit 0
    fi
    if [ "$MENU_ACTION" = "uninstall" ]; then
      UNINSTALL=1
    fi
  fi

  step "Comprobando el sistema operativo"
  check_os

  step "Comprobando el explorador de archivos"
  check_filemanager

  if [ "$UNINSTALL" = "1" ]; then
    choose_mode
    do_uninstall
    exit 0
  fi

  if [ "$DO_INSTALL" = "1" ] || [ "$DO_ENABLE" = "1" ] || [ "$DO_TEST" = "1" ] \
     || [ "$WANT_DEMO" = "1" ] || [ "$WANT_STATUS" = "1" ]; then
    need_cmd python3
  fi

  choose_mode

  WORKDIR="$(mktemp -d /tmp/fcthumb.XXXXXX)"
  trap 'rm -rf "$WORKDIR"' EXIT

  if [ "$DO_DEPS" = "1" ]; then optional_deps; fi
  if [ "$DO_INSTALL" = "1" ]; then install_files; fi
  if [ "$DO_CONFIG" = "1" ]; then config_freecad; fi
  if [ "$DO_ENABLE" = "1" ]; then enable_thumbnails; fi
  if [ "$DO_CACHE_CLEAR" = "1" ]; then clear_cache; fi
  if [ "$DO_RESTART" = "1" ]; then restart_filemanagers; fi
  if [ "$DO_TEST" = "1" ]; then verify; fi
  if [ "$WANT_DEMO" = "1" ]; then make_demo; fi

  summary
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
