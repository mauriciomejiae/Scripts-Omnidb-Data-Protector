#!/bin/bash
# ==================================================================================================
#  DP OMNIDB MEDIA SESSION EXTRACTOR
# ==================================================================================================
#  Autor:        Mauricio Mejia
#  Versión:      17022026
#  Dependencias: OmniDB CLI (/opt/omni/bin/omnidb), sudo access
# ==================================================================================================

# --- 1. CONFIGURACIÓN DEL ENTORNO & COLORES ---
set -u

# Definición de colores ANSI profesionales
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
ICON_TAPE="📼"
ICON_SAVE="💾"

# --- 2. FUNCIONES DE UTILIDAD ---

function print_banner() {
    clear
    echo -e "${CYAN}"
    echo "================================================================================"
    echo -e "▄ ▄▖ ▄▖▖  ▖▖ ▖▄▖▄ ▄  ▖  ▖▄▖▄ ▄▖▄▖ ▄▖▄▖▄▖▄▖▄▖▄▖▖ ▖ ▄▖▖▖▄▖▄▖▄▖▄▖▄▖▄▖▄▖";
    echo -e "▌▌▙▌ ▌▌▛▖▞▌▛▖▌▐ ▌▌▙▘ ▛▖▞▌▙▖▌▌▐ ▌▌ ▚ ▙▖▚ ▚ ▐ ▌▌▛▖▌ ▙▖▚▘▐ ▙▘▌▌▌ ▐ ▌▌▙▘";
    echo -e "▙▘▌  ▙▌▌▝ ▌▌▝▌▟▖▙▘▙▘ ▌▝ ▌▙▖▙▘▟▖▛▌ ▄▌▙▖▄▌▄▌▟▖▙▌▌▝▌ ▙▖▌▌▐ ▌▌▛▌▙▖▐ ▙▌▌▌";
    echo "================================================================================"
    echo -e "${NC}"
    echo -e "${DIM}  Herramienta para extracción de Medios (Tapes/Disks) utilizados por sesión${NC}"
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
        log_msg "WARN" "Este script requiere CLI de Data Protector para funcionar."
    fi
}

# --- 3. FLUJO PRINCIPAL ---

print_banner
check_dependencies

echo -e "${WHITE}${BOLD}PASO 1: SELECCIÓN DE ORIGEN DE DATOS${NC}"
echo -e "${DIM}Indique el archivo TXT con los SESSION IDs (formato: YYYY/MM/DD-NN).${NC}"
echo ""

if ls *.txt 1> /dev/null 2>&1; then
    echo -e "${CYAN}Archivos disponibles:${NC}"
    ls -1 *.txt | head -5 | sed "s/^/  📄 /"
    echo ""
fi

while true; do
    echo -n -e "${BOLD}>> Ingrese ruta del archivo de sesiones:${NC} "
    read -r FILE_INPUT
    
    # Limpieza de comillas
    FILE_INPUT="${FILE_INPUT%\"}"
    FILE_INPUT="${FILE_INPUT#\"}"
    FILE_INPUT="${FILE_INPUT%\'}"
    FILE_INPUT="${FILE_INPUT#\'}"

    if [[ -f "$FILE_INPUT" ]]; then
        if [[ ! -s "$FILE_INPUT" ]]; then
            log_msg "ERROR" "El archivo existe pero está vacío."
        else
            TOTAL_LINES=$(grep -cve '^\s*$' "$FILE_INPUT")
            log_msg "SUCCESS" "Archivo cargado: $FILE_INPUT ($TOTAL_LINES sesiones detectadas)"
            break
        fi
    else
        log_msg "ERROR" "Archivo no encontrado. Intente nuevamente."
    fi
done

echo ""
echo -e "${WHITE}${BOLD}PASO 2: FILTRO OPCIONAL DE MEDIOS${NC}"
echo -e "${DIM}Puede filtrar por Label específico o ID si lo desea.${NC}"
echo -e "${DIM}Dejar vacío para extraer TODOS los medios de las sesiones.${NC}"
echo ""

echo -n -e "${BOLD}>> Filtro de búsqueda [Enter para TODO]:${NC} "
read -r SEARCH_PATTERN

if [[ -z "$SEARCH_PATTERN" ]]; then
    SEARCH_PATTERN="." # Regex match all
    DISPLAY_FILTER="TODOS (Extract Full Media List)"
else
    DISPLAY_FILTER="$SEARCH_PATTERN"
fi

echo ""
echo -e "${WHITE}${BOLD}PASO 3: CONFIGURACIÓN DE SALIDA${NC}"
echo -n -e "${BOLD}>> Directorio de destino [Enter para actual]:${NC} "
read -r OUT_DIR_INPUT
OUT_DIR="${OUT_DIR_INPUT:-.}"

if [[ ! -d "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
    log_msg "INFO" "Directorio creado: $OUT_DIR"
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${OUT_DIR}/Media_Extract_${TIMESTAMP}.log"
ERROR_FILE="${OUT_DIR}/Media_Errors_${TIMESTAMP}.err"

echo ""
echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
echo -e " ${BOLD}RESUMEN DE OPERACIÓN:${NC}"
echo -e "  • Origen:   ${FILE_INPUT}"
echo -e "  • Filtro:   ${YELLOW}${DISPLAY_FILTER}${NC}"
echo -e "  • Salida:   ${GREEN}${OUTPUT_FILE}${NC}"
echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
echo ""
echo -n -e "${BOLD}Presione ENTER para iniciar extracción de medios...${NC}"
read -r

# --- 4. PROCESAMIENTO BATCH ---

echo "================================================================================" > "$OUTPUT_FILE"
echo " DP MEDIA SESSION REPORT" >> "$OUTPUT_FILE"
echo " Generated: $(date)" >> "$OUTPUT_FILE"
echo " Source:    $FILE_INPUT" >> "$OUTPUT_FILE"
echo " Filter:    $DISPLAY_FILTER" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Format: Session ID | Medium Label | Medium ID | Free Blocks" >> "$OUTPUT_FILE"
echo "--------------------------------------------------------------------------------" >> "$OUTPUT_FILE"

CURRENT=0
SUCCESS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)

echo ""
while IFS= read -r SESSION_ID || [[ -n "$SESSION_ID" ]]; do
    [[ -z "$SESSION_ID" || "$SESSION_ID" =~ ^# ]] && continue

    ((CURRENT++))

    # Barra de Progreso Profesional
    PERCENT=$((CURRENT * 100 / TOTAL_LINES))
    BAR_WIDTH=40
    FILLED=$((PERCENT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))
    
    BAR_FILLED=$(printf "%${FILLED}s" | tr ' ' '█')
    BAR_EMPTY=$(printf "%${EMPTY}s" | tr ' ' '░')
    
    printf "\r${BLUE}[INFO]${NC} [${GREEN}%s%s${NC}] ${BOLD}%3d%%${NC} | Analizando: ${YELLOW}%-20s${NC}\033[K" "$BAR_FILLED" "$BAR_EMPTY" "$PERCENT" "$SESSION_ID"

    # Ejecutar OMNIDB MEDIA
    if OUTPUT=$(sudo /opt/omni/bin/omnidb -session "$SESSION_ID" -media 2>> "$ERROR_FILE"); then
        # La salida de -media tiene headers, los quitamos usando tail/grep para tomar solo datos
        # Ejemplo de linea de datos: [VN2371L6] VN2371L6 ...
        
        # Filtramos lineas que contienen datos (ignoramos headers ======== y titulos)
        CLEAN_OUTPUT=$(echo "$OUTPUT" | grep -v "Medium Label" | grep -v "========")
        
        # Aplicar filtro de usuario si existe
        if [[ "$SEARCH_PATTERN" != "." ]]; then
            CLEAN_OUTPUT=$(echo "$CLEAN_OUTPUT" | grep -i "$SEARCH_PATTERN")
        fi

        if [[ -n "$CLEAN_OUTPUT" ]]; then
            echo ">>> SESSION: $SESSION_ID" >> "$OUTPUT_FILE"
            echo "$CLEAN_OUTPUT" >> "$OUTPUT_FILE"
            echo "----------------------------------------" >> "$OUTPUT_FILE"
        fi
        ((SUCCESS_COUNT++))
    else
        echo "$SESSION_ID: Fallo al consultar medios" >> "$ERROR_FILE"
        ((FAIL_COUNT++))
    fi

done < "$FILE_INPUT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# --- 5. RESULTADOS FINALES ---

echo -e "\n\n${CYAN}================================================================================${NC}"
echo -e " ${BOLD}PROCESO FINALIZADO${NC} ${DIM}(${DURATION} segundos)${NC}"
echo -e "${CYAN}================================================================================${NC}"

echo -e "  $ICON_SUCCESS Sesiones:    ${GREEN}$SUCCESS_COUNT${NC}"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "  $ICON_ERROR Fallidas:    ${RED}$FAIL_COUNT${NC} (Ver log)"
fi

if [[ ! -s "$ERROR_FILE" ]]; then rm -f "$ERROR_FILE"; fi

echo ""
echo -e "${BOLD}Archivos generados:${NC}"
echo -e "  $ICON_SAVE Reporte:  ${WHITE}$OUTPUT_FILE${NC}"
echo ""
log_msg "INFO" "Extracción de medios completada."
echo ""
