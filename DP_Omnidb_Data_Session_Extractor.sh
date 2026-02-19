#!/bin/bash
# ==================================================================================================
#  DP OMNIDB DATA SESSION EXTRACTOR
# ==================================================================================================
#  Autor:        Mauricio Mejia
#  Versión:      17022026
#  Dependencias: OmniDB CLI (/opt/omni/bin/omnidb), sudo access
# ==================================================================================================

# --- 1. CONFIGURACIÓN DEL ENTORNO & COLORES ---
# Estricto manejo de variables pero permitiendo fallos controlados en pipes
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
ICON_SEARCH="🔍"
ICON_SAVE="💾"

# --- 2. FUNCIONES DE UTILIDAD ---

# Función para limpiar pantalla y mostrar banner
function print_banner() {
    clear
    echo -e "${CYAN}"
    echo "================================================================================"
    echo -e "▄ ▄▖ ▄▖▖  ▖▖ ▖▄▖▄ ▄  ▄ ▄▖▄▖▄▖ ▄▖▄▖▄▖▄▖▄▖▄▖▖ ▖ ▄▖▖▖▄▖▄▖▄▖▄▖▄▖▄▖▄▖ "
    echo -e "▌▌▙▌ ▌▌▛▖▞▌▛▖▌▐ ▌▌▙▘ ▌▌▌▌▐ ▌▌ ▚ ▙▖▚ ▚ ▐ ▌▌▛▖▌ ▙▖▚▘▐ ▙▘▌▌▌ ▐ ▌▌▙▘ "
    echo -e "▙▘▌  ▙▌▌▝ ▌▌▝▌▟▖▙▘▙▘ ▙▘▛▌▐ ▛▌ ▄▌▙▖▄▌▄▌▟▖▙▌▌▝▌ ▙▖▌▌▐ ▌▌▛▌▙▖▐ ▙▌▌▌ "
    echo "================================================================================"
    echo -e "${NC}"
    echo -e "${DIM}  Herramienta para extracción de metadatos de sesiones Data Protector${NC}"
    echo -e "${DIM}  Sistema: $(uname -s) | Host: $(hostname) | User: $(whoami)${NC}"
    echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
    echo ""
}

# Función de log estandarizado
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

# Verifica dependencias críticas
function check_dependencies() {
    if [[ ! -x "/opt/omni/bin/omnidb" ]]; then
        log_msg "WARN" "Binario 'omnidb' no encontrado en ruta estándar (/opt/omni/bin/)."
        log_msg "WARN" "Asegúrese de ejecutar esto en un Cell Manager o Client con CLI instalada."
        # No salimos forzosamente para permitir pruebas en entornos dev, 
        # pero en producción esto sería crítico.
    fi
}

# --- 3. FLUJO PRINCIPAL ---

print_banner
check_dependencies

echo -e "${WHITE}${BOLD}PASO 1: SELECCIÓN DE ORIGEN DE DATOS${NC}"
echo -e "${DIM}Por favor, indique el archivo conteniendo los SESSION IDs (formato: YYYY/MM/DD-NN).${NC}"
echo ""

# Listar archivos .txt para ayudar
if ls *.txt 1> /dev/null 2>&1; then
    echo -e "${CYAN}Archivos disponibles en directorio actual:${NC}"
    ls -1 *.txt | head -5 | sed "s/^/  📄 /"
    echo ""
fi

# Loop de validación de archivo input
while true; do
    echo -n -e "${BOLD}>> Ingrese ruta del archivo de sesiones:${NC} "
    read -r FILE_INPUT
    
    # Limpieza de comillas (común al copiar path en Windows/Linux GUI)
    FILE_INPUT="${FILE_INPUT%\"}"
    FILE_INPUT="${FILE_INPUT#\"}"
    FILE_INPUT="${FILE_INPUT%\'}"
    FILE_INPUT="${FILE_INPUT#\'}"

    if [[ -f "$FILE_INPUT" ]]; then
        # Verificar que no esté vacío
        if [[ ! -s "$FILE_INPUT" ]]; then
            log_msg "ERROR" "El archivo existe pero está vacío."
        else
            TOTAL_LINES=$(grep -cve '^\s*$' "$FILE_INPUT")
            log_msg "SUCCESS" "Archivo cargado: $FILE_INPUT ($TOTAL_LINES sesiones detectadas)"
            break
        fi
    else
        log_msg "ERROR" "Archivo no encontrado. Verifique la ruta e intente nuevamente."
    fi
done

echo ""
echo -e "${WHITE}${BOLD}PASO 2: DEFINICIÓN DE FILTROS DE EXTRACCIÓN${NC}"
echo -e "${DIM}Este script extraerá información específica del reporte de cada sesión.${NC}"
echo -e "${DIM}Ejemplos: 'Media', 'Error', '/oracle/data', 'Completed', 'Mount request'${NC}"
echo ""

echo -n -e "${BOLD}>> Ingrese patrón de búsqueda (String/Regex):${NC} "
read -r SEARCH_PATTERN

if [[ -z "$SEARCH_PATTERN" ]]; then
    log_msg "WARN" "No se ingresó filtro. Se extraerá TO_DO el reporte (puede ser muy extenso)."
    SEARCH_PATTERN="." # Match all
fi

echo ""
echo -e "${WHITE}${BOLD}PASO 3: CONFIGURACIÓN DE SALIDA${NC}"
echo -n -e "${BOLD}>> Directorio de destino [Enter para actual]:${NC} "
read -r OUT_DIR_INPUT
OUT_DIR="${OUT_DIR_INPUT:-.}"

# Crear directorio si no existe
if [[ ! -d "$OUT_DIR" ]]; then
    mkdir -p "$OUT_DIR"
    log_msg "INFO" "Directorio creado: $OUT_DIR"
fi

# Generar nombre de archivo único
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
# Sanitizar patrón para filename
CLEAN_PATTERN=$(echo "$SEARCH_PATTERN" | tr -cd '[:alnum:]_.-' | cut -c 1-20)
if [[ -z "$CLEAN_PATTERN" ]]; then CLEAN_PATTERN="FullReport"; fi

OUTPUT_FILE="${OUT_DIR}/DP_Extract_${CLEAN_PATTERN}_${TIMESTAMP}.log"
ERROR_FILE="${OUT_DIR}/DP_Errors_${TIMESTAMP}.err"

echo ""
echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
echo -e " ${BOLD}RESUMEN DE OPERACIÓN:${NC}"
echo -e "  • Origen:   ${FILE_INPUT}"
echo -e "  • Filtro:   ${YELLOW}'${SEARCH_PATTERN}'${NC}"
echo -e "  • Salida:   ${GREEN}${OUTPUT_FILE}${NC}"
echo -e "${CYAN}--------------------------------------------------------------------------------${NC}"
echo ""
echo -n -e "${BOLD}Presione ENTER para iniciar el procesamiento...${NC}"
read -r

# --- 4. PROCESAMIENTO BATCH ---

# Inicializar archivos
echo "================================================================================" > "$OUTPUT_FILE"
echo " DP DATA EXTRACTION REPORT" >> "$OUTPUT_FILE"
echo " Generated: $(date)" >> "$OUTPUT_FILE"
echo " Source:    $FILE_INPUT" >> "$OUTPUT_FILE"
echo " Filter:    $SEARCH_PATTERN" >> "$OUTPUT_FILE"
echo "================================================================================" >> "$OUTPUT_FILE"

CURRENT=0
SUCCESS_COUNT=0
FAIL_COUNT=0
START_TIME=$(date +%s)

echo ""
# Leer archivo línea por línea
while IFS= read -r SESSION_ID || [[ -n "$SESSION_ID" ]]; do
    # Ignorar líneas vacías o comentarios
    [[ -z "$SESSION_ID" || "$SESSION_ID" =~ ^# ]] && continue

    ((CURRENT++))

    # --- Barra de Progreso Profesional ---
    # --- Barra de Progreso Profesional ---
    PERCENT=$((CURRENT * 100 / TOTAL_LINES))
    BAR_WIDTH=40
    FILLED=$((PERCENT * BAR_WIDTH / 100))
    EMPTY=$((BAR_WIDTH - FILLED))
    
    # Construcción eficiente de la barra
    BAR_FILLED=$(printf "%${FILLED}s" | tr ' ' '█')
    BAR_EMPTY=$(printf "%${EMPTY}s" | tr ' ' '░')
    
    # Imprimir estado: [BARRA] N% | Procesando: SESSION_ID
    # \033[K limpia el resto de la línea para evitar residuos visuales
    printf "\r${BLUE}[INFO]${NC} [${GREEN}%s%s${NC}] ${BOLD}%3d%%${NC} | Analizando: ${YELLOW}%-20s${NC}\033[K" "$BAR_FILLED" "$BAR_EMPTY" "$PERCENT" "$SESSION_ID"

    # --- Ejecutar OMNIDB ---
    # Header por sesión en el log
    echo "" >> "$OUTPUT_FILE"
    echo ">>> SESSION: $SESSION_ID" >> "$OUTPUT_FILE"
    echo "----------------------------------------" >> "$OUTPUT_FILE"

    # Capturar salida. Usamos grep para filtrar. 
    # Nota: omnidb requiere privilegios usualmente. Si el script corre como root, sudo no es necesario, 
    # pero lo dejamos para compatibilidad estándar.
    
    if OUTPUT=$(sudo /opt/omni/bin/omnidb -session "$SESSION_ID" -report 2>> "$ERROR_FILE"); then
        # Filtrar resultado
        MATCHES=$(echo "$OUTPUT" | grep -i "$SEARCH_PATTERN")
        
        if [[ -n "$MATCHES" ]]; then
            echo "$MATCHES" >> "$OUTPUT_FILE"
        else
            echo "(Sin coincidencias para el filtro)" >> "$OUTPUT_FILE"
        fi
        ((SUCCESS_COUNT++))
    else
        echo "ERROR: Falló ejecución de omnidb" >> "$OUTPUT_FILE"
        echo "$SESSION_ID: Fallo de ejecución CLI" >> "$ERROR_FILE"
        ((FAIL_COUNT++))
    fi

done < "$FILE_INPUT"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# --- 5. RESULTADOS FINALES ---

echo -e "\n\n${CYAN}================================================================================${NC}"
echo -e " ${BOLD}PROCESO FINALIZADO${NC} ${DIM}(${DURATION} segundos)${NC}"
echo -e "${CYAN}================================================================================${NC}"

echo -e "  $ICON_SUCCESS Procesadas:  ${GREEN}$SUCCESS_COUNT${NC}"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "  $ICON_ERROR Fallidas:    ${RED}$FAIL_COUNT${NC} (Ver log de errores)"
else
    # Eliminar archivo de errores si está vacío
    if [[ ! -s "$ERROR_FILE" ]]; then rm -f "$ERROR_FILE"; fi
fi

echo ""
echo -e "${BOLD}Archivos generados:${NC}"
echo -e "  $ICON_SAVE Reporte:  ${WHITE}$OUTPUT_FILE${NC}"
if [[ -f "$ERROR_FILE" ]]; then
    echo -e "  $ICON_WARN Errores:  ${RED}$ERROR_FILE${NC}"
fi

echo ""
log_msg "INFO" "Operación completada. Hasta luego."
echo ""
