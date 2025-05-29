# Sincronización con BigQuery

Este sistema permite sincronizar datos de la colección MongoDB `Persona_AR` a una tabla de BigQuery de forma progresiva y automática.

## Configuración

### Requisitos

- Google Cloud SDK instalado
- Credenciales de Google Cloud configuradas
- Tabla BigQuery creada con el esquema adecuado
- Dependencias de Python instaladas:
  ```
  pip install google-cloud-bigquery
  ```

### Archivo de credenciales

El sistema está configurado para usar el archivo de credenciales ubicado en:
```
/Users/jesusmachta/Desktop/Tesis/innovacion-402319-7a57ae5eb246.json
```

### Tabla de BigQuery

La tabla está configurada como:
```
app-turnos-farmacia.StoresDataChat.StoresDataChat
```

## Scripts disponibles

### 1. Sincronización inicial

Para realizar la primera sincronización completa, ejecuta:

```bash
cd /ruta/al/proyecto
python -m backend.scripts.initial_bigquery_sync
```

Este script:
1. Inicializa la colección de control en MongoDB
2. Reinicia el estado de sincronización
3. Ejecuta una sincronización completa de todos los documentos

### 2. Sincronización periódica

Para ejecutar una sincronización incremental (sólo nuevos documentos):

```bash
cd /ruta/al/proyecto
python -m backend.scripts.cron_sync_to_bigquery
```

Este script puede configurarse para ejecutarse automáticamente con cron:

```
# Ejecutar cada hora
0 * * * * cd /ruta/al/proyecto && /ruta/al/entorno/python -m backend.scripts.cron_sync_to_bigquery >> /ruta/logs/sync_bigquery.log 2>&1
```

### 3. Sincronización manual

Para reiniciar el estado y forzar una sincronización completa:

```bash
cd /ruta/al/proyecto
python -m backend.scripts.sync_to_bigquery --reset --full
```

Para ejecutar una sincronización incremental con un tamaño de lote específico:

```bash
cd /ruta/al/proyecto
python -m backend.scripts.sync_to_bigquery --batch 200
```

## Endpoints de API

Se han creado tres endpoints para controlar la sincronización:

1. **Sincronización incremental**
   ```
   POST /sync/bigquery
   ```

2. **Sincronización completa**
   ```
   POST /sync/bigquery/full
   ```

3. **Reiniciar estado de sincronización**
   ```
   POST /sync/bigquery/reset
   ```

## Monitoreo

El sistema registra información detallada sobre el proceso de sincronización en los logs. Para ver los logs en tiempo real durante una sincronización:

```bash
tail -f /ruta/logs/sync_bigquery.log
```

## Esquema de datos

La sincronización mapea los campos de MongoDB a BigQuery de la siguiente manera:

| MongoDB (Persona_AR) | BigQuery |
|----------------------|----------|
| id                   | id (INTEGER) |
| date                 | date (DATE) |
| time                 | time (STRING) |
| id_camara            | id_camara (INTEGER) |
| categoria_producto   | categoria_producto (STRING) |
| empresa              | empresa (STRING) |
| gender               | gender (STRING) |
| age_range.low        | age_range_low (INTEGER) |
| age_range.high       | age_range_high (INTEGER) |
| emotions             | emotions (STRING) |
| -                    | sync_timestamp (TIMESTAMP) |

## Solución de problemas

Si encuentras problemas con la sincronización:

1. Verifica que el archivo de credenciales existe y tiene los permisos correctos
2. Asegúrate de que la tabla de BigQuery existe con el esquema correcto
3. Revisa los logs para identificar errores específicos
4. Si la sincronización se interrumpe, puedes reiniciarla sin problemas; el sistema continuará desde el último punto exitoso

Para reiniciar completamente el proceso de sincronización:

```bash
cd /ruta/al/proyecto
python -m backend.scripts.initialize_bigquery_sync
python -m backend.scripts.sync_to_bigquery --reset --full
``` 