# Sistema de Estadísticas Precomputadas

Este sistema mejora la eficiencia de consulta y visualización de estadísticas mediante un enfoque de precomputación incremental. En lugar de calcular estadísticas en tiempo real (lo que puede ser ineficiente con grandes volúmenes de datos), almacenamos y actualizamos progresivamente las estadísticas en una colección dedicada.

## Beneficios

- **Consultas más rápidas**: Las estadísticas se sirven instantáneamente sin necesidad de procesar toda la colección PersonaAR.
- **Menor carga en el servidor**: Reduce significativamente el uso de CPU y memoria al mostrar estadísticas.
- **Mejor experiencia de usuario**: Tiempos de respuesta consistentes independientemente del volumen de datos.
- **Escalabilidad**: El sistema funcionará eficientemente incluso con millones de registros.

## Funcionamiento

El sistema implementa tres estrategias complementarias:

1. **Actualizaciones incrementales**: Cada vez que se inserta un nuevo registro en PersonaAR, se actualizan automáticamente todas las estadísticas relacionadas.
2. **Actualizaciones programadas**: Tareas periódicas verifican y actualizan las estadísticas (diaria, semanal y mensualmente).
3. **Comprobación de integridad**: Una tarea programada verifica regularmente que todos los documentos de estadísticas existan y sean consistentes.

## Estructura de Datos

La colección `Estadisticas` contiene documentos individuales para cada tipo de estadística:

- `peak_hours`: Horas pico por día de la semana
- `least_busy_hours`: Horas menos concurridas por día
- `most_busy_day`: Día más concurrido de la semana
- `least_busy_day`: Día menos concurrido de la semana
- `most_visited_category`: Categoría más visitada (diaria/semanal/mensual/histórica)
- `least_visited_category`: Categoría menos visitada (diaria/semanal/mensual/histórica)
- `historical_categories`: Categorías más y menos visitadas históricamente
- `emotion_percentage_by_category`: Porcentaje de emociones por categoría
- `most_frequent_emotions`: Emociones más frecuentes
- `age_distribution`: Distribución por edades
- `gender_distribution`: Distribución por género
- `emotion_comparison`: Comparación de emociones positivas y negativas
- `preferred_category_by_gender`: Categorías preferidas por género
- `top_successful_categories`: Categorías que generan más emociones positivas
- `emotional_differences_by_category`: Emociones predominantes por género y categoría
- `age_gender_distribution_by_category`: Combinaciones de género y edad por categoría

## Inicialización con Datos Históricos

Para cargar los datos históricos en el sistema de estadísticas, ejecute el script de inicialización:

```bash
cd /ruta/a/Trabajo-de-Grado
python -m backend.scripts.initialize_stats_from_history
```

Este script procesa todos los registros existentes en PersonaAR y actualiza las estadísticas como si se hubieran insertado incrementalmente. Solo debe ejecutarse una vez.

## Verificación del Sistema

Puede verificar que el sistema funciona correctamente consultando cualquier endpoint de estadísticas:

```
GET /api/statistics/peak-hours/
GET /api/statistics/most-visited/
GET /api/statistics/age-distribution/
```

Si ha inicializado correctamente, los datos de estadísticas reflejarán todo el historial de PersonaAR.

## Mantenimiento

El sistema de actualización programada se ejecuta automáticamente:

- **Diariamente** (medianoche): Actualiza contadores diarios y datos consolidados.
- **Semanalmente** (domingo 1:00): Procesa estadísticas semanales.
- **Mensualmente** (día 1 a las 2:00): Actualiza estadísticas mensuales.
- **Comprobación de integridad** (3:00 diariamente): Verifica y repara documentos de estadísticas si es necesario.

No se requiere mantenimiento manual una vez inicializado correctamente.

## Solución de problemas

Si las estadísticas parecen inconsistentes:

1. Verifique que la colección `Estadisticas` contenga todos los documentos esperados:
   ```python
   db.Estadisticas.find().count()  # Debería ser 15
   ```

2. Reinicie la inicialización si es necesario:
   ```bash
   # Primero, elimine todos los documentos de estadísticas
   # CUIDADO: Esto borrará todas las estadísticas existentes
   # db.Estadisticas.deleteMany({})
   
   # Luego, ejecute el script de inicialización
   python -m backend.scripts.initialize_stats_from_history
   ```

3. Verifique los logs del servidor para detectar posibles errores en las actualizaciones incrementales. 