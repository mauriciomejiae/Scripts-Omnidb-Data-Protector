import re
import os
import sys
import time
from datetime import datetime
from PyPDF2 import PdfReader

# --- Configuración Visual ---
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def clear_screen():
    os.system('cls' if os.name == 'nt' else 'clear')

def print_banner():
    clear_screen()
    print(Colors.OKCYAN + "=" * 80 + Colors.ENDC)
    print(Colors.BOLD + "      DP IDB GUI SESSION EXTRACTOR".center(80) + Colors.ENDC)
    print(Colors.OKCYAN + "=" * 80 + Colors.ENDC)
    print(f"{Colors.HEADER}  Autor:   Mauricio Mejia{Colors.ENDC}")
    print(f"{Colors.HEADER}  Versión: 17/02/2026 - TXT Export Mode{Colors.ENDC}")
    print(Colors.OKCYAN + "-" * 80 + Colors.ENDC)
    print("")

def get_valid_pdf_path():
    """Solicita al usuario la ruta del archivo PDF con validaciones."""
    while True:
        raw_input = input(f"{Colors.BOLD} >> Ingrese la ruta completa del archivo PDF:{Colors.ENDC} ").strip()
        
        # Manejo de comillas si el usuario copia como ruta
        path = raw_input.replace('"', '').replace("'", "")
        
        if not path:
            print(f" {Colors.FAIL}[!] Error: La ruta no puede estar vacía.{Colors.ENDC}")
            continue
            
        if not os.path.exists(path):
            print(f" {Colors.FAIL}[!] Error: El archivo no existe. Verifique la ruta.{Colors.ENDC}")
            continue
            
        if not path.lower().endswith('.pdf'):
            print(f" {Colors.FAIL}[!] Error: El archivo debe tener extensión .pdf{Colors.ENDC}")
            continue
            
        return path

def generate_output_path(pdf_path):
    """Genera la ruta de salida basada en el nombre del PDF y la fecha actual."""
    directory = os.path.dirname(pdf_path)
    filename = os.path.basename(pdf_path)
    name_without_ext = os.path.splitext(filename)[0]
    current_date = datetime.now().strftime("%Y-%m-%d")
    
    # Nuevo formato: [NombrePDF]_[Fecha].txt
    new_filename = f"{name_without_ext}_{current_date}.txt"
    return os.path.join(directory, new_filename)

def parse_session_date(session_id):
    """Parsea 2025/10/12-44 -> (datetime(2025,10,12), 44)"""
    try:
        date_part, num_part = session_id.rsplit("-", 1)
        dt = datetime.strptime(date_part, "%Y/%m/%d")
        return (dt, int(num_part))
    except ValueError:
        return (datetime.min, 0) # Fallback seguro

def main():
    print_banner()
    
    try:
        # 1. Obtener ruta del PDF
        pdf_path = get_valid_pdf_path()
        output_path = generate_output_path(pdf_path)
        
        print(f"\n {Colors.OKBLUE}[INFO] Procesando archivo:{Colors.ENDC} {os.path.basename(pdf_path)}")
        print(f" {Colors.OKBLUE}[INFO] Archivo de salida:{Colors.ENDC} {os.path.basename(output_path)}")
        print(f"\n {Colors.WARNING}Iniciando extracción...{Colors.ENDC}")
        time.sleep(1) # Pequeña pausa para UX

        # --- 1. Extraer texto del PDF ---
        reader = PdfReader(pdf_path)
        full_text = ""
        total_pages = len(reader.pages)
        
        print(f" {Colors.OKGREEN}[✓] PDF cargado ({total_pages} páginas){Colors.ENDC}")

        for i, page in enumerate(reader.pages, 1):
            full_text += page.extract_text() + "\n"
            # Barra de progreso simple
            sys.stdout.write(f"\r    Leyendo pág {i}/{total_pages}...")
            sys.stdout.flush()
        print("") # Nueva línea tras progreso

        # --- 2. Extraer los Name (session IDs) con su status ---
        # Formato: 2025/10/31-276 Completed Backup ...
        pattern = r"(\d{4}/\d{2}/\d{2}-\d+)\s+(Completed(?:/Failures)?|Failed|In Progress|Queuing|Aborted)\s+"
        matches = re.findall(pattern, full_text)
        
        # Deduplicar manteniendo el primer status encontrado
        seen = {}
        for session_id, status in matches:
            if session_id not in seen:
                seen[session_id] = status
        
        sessions = list(seen.items())
        sessions.sort(key=lambda x: parse_session_date(x[0]))
        
        count = len(sessions)
        print(f" {Colors.OKGREEN}[✓] Sesiones identificadas: {count}{Colors.ENDC}")
        
        if count == 0:
            print(f"\n {Colors.FAIL}[!] No se encontraron sesiones válidas en el PDF.{Colors.ENDC}")
            return

        # --- 3. Generar archivo TXT ---
        print(f" {Colors.WARNING}Generando archivo TXT (Solo ID de Sesión)...{Colors.ENDC}")
        
        try:
            with open(output_path, 'w', encoding='utf-8') as f:
                for session_id, status in sessions:
                    f.write(f"{session_id}\n")
        except Exception as e:
            print(f"\n {Colors.FAIL}[!] Error al escribir el archivo: {e}{Colors.ENDC}")
            return
        
        print(f"\n {Colors.OKGREEN}{Colors.BOLD}¡PROCESO COMPLETADO CON ÉXITO!{Colors.ENDC}")
        print(f" {Colors.OKCYAN}Archivo generado:{Colors.ENDC} {output_path}")
        
        # Preview final
        print(f"\n {Colors.HEADER}--- Preview del contenido (Primeras 5 líneas) ---{Colors.ENDC}")
        for i, (sid, status) in enumerate(sessions[:5], 1):
             print(f"  {Colors.BOLD}{i}.{Colors.ENDC} {sid}")
        
        input(f"\n{Colors.WARNING}Presione ENTER para salir...{Colors.ENDC}")

    except Exception as e:
        print(f"\n\n {Colors.FAIL}[CRITICAL ERROR] Ocurrió un error inesperado:{Colors.ENDC}")
        print(f" {str(e)}")
        input(f"\nPresione ENTER para cerrar...")

if __name__ == "__main__":
    try:
        # Asegurar encoding correcto para Windows si es necesario
        if sys.platform == 'win32':
             os.system('color')
        main()
    except KeyboardInterrupt:
        print(f"\n\n {Colors.WARNING}[!] Operación cancelada por el usuario.{Colors.ENDC}")
        sys.exit(0)
