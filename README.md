# Scripts Omnidb Data Protector

Colección de utilidades para la administración, auditoría y extracción de metadatos de sesiones de backup en entornos **Open Text Data Protector (OmniDB)**.

---

## 📂 Contenido del Repositorio

### Scripts de Extracción (Bash/Linux)

Herramientas CLI para ejecución directa en Cell Managers o clientes con acceso a `omnidb`.

| Archivo                                    | Descripción                                                                                                           | Uso Principal        |
| :----------------------------------------- | :-------------------------------------------------------------------------------------------------------------------- | :------------------- |
| **`DP_Omnidb_Data_Session_Extractor.sh`**  | Extractor universal de metadatos. Procesa listas de sesiones para obtener archivelogs, estadísticas, errores y rutas. | Auditoría, Debugging |
| **`DP_Omnidb_Media_Session_Extractor.sh`** | Reporte de uso de medios. Identifica qué cintas o dispositivos de disco lógico se utilizaron por sesión.              | Gestión de Medios    |
| **`DP_Omnidb_Backup_Session_Reporter.sh`** | Generador de reportes por especificación de backup (Datalist/Job). Permite filtrado por fechas.                       | Reporting, SLA       |

### Utilidades de Soporte (Python)

| Archivo                               | Descripción                                                                                                                                                |
| :------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`DP_IDB_GUI_Session_Extractor.py`** | **Pre-procesador.** Convierte reportes PDF exportados desde la GUI de Data Protector en listas de IDs de sesión (`.txt`) procesables por los scripts Bash. |

---

## 🚀 Flujo de Trabajo Sugerido

### 1. Generación de Origen de Datos

Desde la GUI de Data Protector (Contexto _Internal Database_), exporte la vista de sesiones deseada a **PDF** usando _File -> Print -> Microsoft Print to PDF_.

### 2. Procesamiento de IDs

Utilice la herramienta Python para limpiar el reporte PDF y extraer los IDs únicos:

```bash
python DP_IDB_GUI_Session_Extractor.py
# El script solicitará la ruta del PDF y generará un archivo 'Lista_Sesiones_*.txt'
```

### 3. Ejecución de Tareas en Servidor

Transfiera los scripts `.sh` y la lista generada al servidor Data Protector.

**Ejemplo de Extracción General:**

```bash
chmod +x DP_Omnidb_Data_Session_Extractor.sh
./DP_Omnidb_Data_Session_Extractor.sh
# Siga las instrucciones en pantalla para seleccionar su lista de sesiones
```

---

## 📋 Requisitos del Sistema

- **OS:** Linux (RHEL/CentOS) para scripts Bash.
- **Software:** Open Text Data Protector (OmniDB CLI accesible).
- **Python:** 3.x+ (para utilidades de PC).
- **Access:** Privilegios suficientes para ejecutar comandos `omnidb`.
