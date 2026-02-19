#!/bin/bash
# ==================================================================================================
#  DP OMNIDB BACKUP SESSION REPORTER
# ==================================================================================================
#  Autor:        Mauricio Mejia
#  Versión:      17022026
#  Dependencias: OmniDB CLI (/opt/omni/bin/omnidb), sudo access
# ==================================================================================================

# --- 1. CONFIGURACIÓN DEL ENTORNO & COLORES ---
set -u

# Definición de colores ANSI
BOLD='\033[1m'
DIM='\033[2m'
UNDERLINE='\033[4m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Iconos
ICON_INFO="ℹ️ "
ICON_SUCCESS="✅"
ICON_WARN="⚠️ "
ICON_ERROR="❌"
ICON_REPORT="📊"
ICON_SAVE="💾"

# --- 2. FUNCIONES DE UTILIDAD ---

function print_banner() {
    clear
    echo -e "${CYAN}"
    echo "================================================================================"
    echo -e "▄ ▄▖ ▄▖▖  ▖▖ ▖▄▖▄ ▄  ▄ ▄▖▄▖▖▖▖▖▄▖ ▄▖▄▖▄▖▄▖▄▖▄▖▖ ▖ ▄▖▄▖▄▖▄▖▄▖▄▖▄▖▄▖"
    echo -e "▌▌▙▌ ▌▌▛▖▞▌▛▖▌▐ ▌▌▙▘ ▙▘▌▌▌ ▙▘▌▌▙▌ ▚ ▙▖▚ ▚ ▐ ▌▌▛▖▌ ▙▘▙▖▙▌▌▌▙▘▐ ▙▖▙▘"
    echo -e "▙▘▌  ▙▌▌▝ ▌▌▝▌▟▖▙▘▙▘ ▙▘▛▌▙▖▌▌▙▌▌  ▄▌▙▖▄▌▄▌▟▖▙▌▌▝▌ ▌▌▙▖▌ ▙▌▌▌▐ ▙▖▌▌"
    echo "================================================================================"
    echo -e "${NC}"
    echo -e "${DIM}  Herramienta para consultar reportes de Backup detallados por Datalist (Job)${NC}"
    echo -e "${DIM}  Sistema: $(uname -s) | Host: $(hostname) | User: $(whoami)${NC}"
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo ""
}

function log_msg() {
    local level=$1
    local msg=$2
    case $level in
        "INFO")    echo -e "${BLUE}[INFO]${NC} $msg" ;;
        "SUCCESS") echo -e "${GREEN}[OK]${NC}   $msg" ;;
        "WARN")    echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        "ERROR")   echo -e "${RED}[ERR]${NC}  $msg" ;;
        *)         echo "$msg" ;;
    esac
}

function check_dependencies() {
    if [[ ! -x "/opt/omni/bin/omnidb" ]]; then
        log_msg "WARN" "Binario 'omnidb' no encontrado en ruta estándar (/opt/omni/bin/)."
    fi
}

function wait_input() {
    echo ""
    echo -n -e "${BOLD}Presione ENTER para continuar...${NC}"
    read -r
}

# --- 3. FLUJO PRINCIPAL ---

print_banner
check_dependencies

echo -e "${WHITE}${BOLD}PASO 1: SELECCIÓN DE DATALIST (BACKUP SPECIFICATION)${NC}"
echo -e "${DIM}Ingrese el nombre exacto de la especificación de backup (Ej: 154_WBACKUPS01_FS_DIA).${NC}"
echo ""

while true; do
    echo -n -e "${BOLD}>> Ingrese Nombre del Datalist:${NC} "
    read -r DATALIST_NAME
    
    # Limpieza básica
    DATALIST_NAME="${DATALIST_NAME%\"}"
    DATALIST_NAME="${DATALIST_NAME#\"}"

    if [[ -n "$DATALIST_NAME" ]]; then
        break
    else
        log_msg "ERROR" "El nombre del datalist no puede estar vacío."
    fi
done

echo ""
echo -e "${WHITE}${BOLD}PASO 2: TIPO DE CONSULTA${NC}"
echo -e "${DIM}Seleccione qué periodo desea consultar.${NC}"
echo ""

echo "  1) Por Rango de Fechas (-since / -until)"
echo "  2) Últimos N Días (-last X)"
echo "  3) Última Sesión (-latest)"
echo ""
echo -n -e "${BOLD}>> Seleccione opción [1-3]:${NC} "
read -r OPTION

CMD_OPTIONS=""
REPORT_SUFFIX=""

case $OPTION in
    1)
        echo ""
        echo -e "${CYAN}--- Rango de Fechas (Formato: YY/MM/DD) ---${NC}"
        echo -n "Ingrese Fecha Inicio (-since) [Ej: 25/01/01]: "
        read -r DATE_SINCE
        echo -n "Ingrese Fecha Fin    (-until) [Ej: 25/01/14]: "
        read -r DATE_UNTIL
        
        if [[ -z "$DATE_SINCE" ]]; then
            log_msg "ERROR" "Fecha de inicio requerida."
            exit 1
        fi
        
        # Construir comando
        CMD_OPTIONS="-since $DATE_SINCE"
        if [[ -n "$DATE_UNTIL" ]]; then
            CMD_OPTIONS="$CMD_OPTIONS -until $DATE_UNTIL"
        fi
        REPORT_SUFFIX="Range_${DATE_SINCE//\//}"
        ;;
    2)
        echo ""
        echo -e "${CYAN}--- Últimos Días ---${NC}"
        echo -n "Ingrese número de días [Ej: 2]: "
        read -r DAYS_NUM
        
        if [[ -z "$DAYS_NUM" || ! "$DAYS_NUM" =~ ^[0-9]+$ ]]; then
             log_msg "ERROR" "Debe ingresar un número válido."
             exit 1
        fi
        
        CMD_OPTIONS="-last $DAYS_NUM"
        REPORT_SUFFIX="Last${DAYS_NUM}Days"
        ;;
    3)
        echo ""
        echo -e "${CYAN}--- Última Sesión Ejecutada ---${NC}"
        CMD_OPTIONS="-latest"
        REPORT_SUFFIX="Latest"
        ;;
    *)
        log_msg "ERROR" "Opción inválida."
        exit 1
        ;;
esac

echo ""
echo -e "${WHITE}${BOLD}PASO 3: CONFIGURACIÓN DE SALIDA${NC}"
echo -n -e "${BOLD}>> Directorio de destino [Enter para actual]:${NC} "
read -r OUT_DIR_INPUT
OUT_DIR="${OUT_DIR_INPUT:-.}"

if [[ ! -d "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# Limpieza de nombre archivo
CLEAN_DATALIST=$(echo "$DATALIST_NAME" | tr -cd '[:alnum:]_.-')
OUTPUT_FILE="${OUT_DIR}/BackupReport_${CLEAN_DATALIST}_${REPORT_SUFFIX}_${TIMESTAMP}.log"
ERROR_FILE="${OUT_DIR}/BackupError_${TIMESTAMP}.err"

# --- 4. EJECUCIÓN ---

echo ""
echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
echo -e " ${BOLD}EJECUTANDO CONSULTA...${NC}"
echo -e "  • Datalist: ${YELLOW}$DATALIST_NAME${NC}"
echo -e "  • Opciones: ${YELLOW}$CMD_OPTIONS${NC}"
echo -e "  • Salida:   ${GREEN}$OUTPUT_FILE${NC}"
echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
echo ""

# Comando Final
# omnidb -session -datalist "NAME" -type backup -detail [OPTIONS]
COMMAND="sudo /opt/omni/bin/omnidb -session -datalist \"$DATALIST_NAME\" -type backup -detail $CMD_OPTIONS"

echo "================================================================================" > "$OUTPUT_FILE"
echo " DP BACKUP SESSION REPORT" >> "$OUTPUT_FILE"
echo " Generated: $(date)" >> "$OUTPUT_FILE"
echo " Command:   $COMMAND" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Ejecutar
if eval "$COMMAND" >> "$OUTPUT_FILE" 2>> "$ERROR_FILE"; then
    log_msg "SUCCESS" "Consulta ejecutada correctamente."
else
    log_msg "ERROR" "Ocurrió un error al ejecutar omnidb. Revise el log de errores."
fi

# --- 5. FIN ---
echo ""
echo -e "${BOLD}Archivos generados:${NC}"
echo -e "  $ICON_SAVE Reporte:  ${WHITE}$OUTPUT_FILE${NC}"

if [[ -s "$ERROR_FILE" ]]; then
    echo -e "  $ICON_WARN Errores:  ${RED}$ERROR_FILE${NC}"
else
    rm -f "$ERROR_FILE"
fi

echo ""
