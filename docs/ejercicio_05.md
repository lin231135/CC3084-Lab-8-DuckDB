# Ejercicio 5: incorporación de los datos de 2024

## 5.1 a 5.4 Descarga de 2024

El script de descarga que dejamos en el ejercicio 2 ya estaba parametrizado por años, así que para incorporar 2024 no hubo que cambiar su lógica sino ejecutarlo con `--years 2024 2026`. Esa fue una decisión de diseño que tomamos desde el principio, y la ventaja se vio acá, porque el único cambio de código de este ejercicio en el script fue agregar la descarga de la tabla de zonas de la TLC (`data/raw/zonas/taxi_zone_lookup.csv`, 12 KiB), que necesitábamos para nombrar las zonas en el análisis del ejercicio 4. Esa descarga sigue el mismo criterio que las demás, o sea que no se repite si el archivo ya existe y no está vacío.

```bash
docker exec lab8-lab python scripts/download_data.py --years 2024 2026
```

La corrida descargó 24 archivos (12 de amarillos y 12 de verdes de 2024), omitió los 16 de 2026 porque ya existían y eran válidos, y reportó 8 meses no publicados (septiembre a diciembre de 2026, en ambos tipos) y 0 fallidos. Al final la verificación de completitud dio 12 de 12 para amarillos y verdes de 2024 y 8 de 8 para los de 2026. Después ejecutamos el mismo comando una segunda vez para cumplir el punto 5.3 y reportó 0 descargados y 40 archivos que ya existían. Los archivos de 2026 siguieron intactos, que es lo que pide 5.2, ya que el script nunca borra ni reescribe un archivo que pasa la validación. Con 2024 la carpeta `data/raw` ocupa unos 1.2 GB.

## 5.5 Verificación de los archivos nuevos

La consulta `5_1_archivos_y_registros_por_anio.sql` lee solo el pie de página de los Parquet y cuenta archivos y viajes por tipo y año.

| Tipo | Año | Archivos | Meses | Viajes |
|---|---|---|---|---|
| yellow | 2024 | 12 | 2024-01 a 2024-12 | 41,169,720 |
| yellow | 2026 | 8 | 2026-01 a 2026-08 | 29,703,355 |
| green | 2024 | 12 | 2024-01 a 2024-12 | 660,218 |
| green | 2026 | 8 | 2026-01 a 2026-08 | 337,114 |

Los números de 2026 coinciden con los del ejercicio 2, así que incorporar 2024 no alteró lo que ya teníamos, y 2024 aporta 41.8 millones de viajes más, con lo que el total pasa de 30.0 a 71.9 millones.

## 5.6 Consulta conjunta de 2024 y 2026

La consulta `5_2_registros_por_mes_y_anio.sql` es una sola sentencia sobre todos los archivos que pone los meses de cada año lado a lado, y es la prueba directa de que ahora podemos consultar los dos años juntos. Estos son los viajes por mes (por fecha de recogida) de los amarillos.

| Mes | 2024 | 2026 |
|---|---|---|
| Ene | 2,964,617 | 3,724,894 |
| Feb | 3,007,533 | 3,399,866 |
| Mar | 3,582,611 | 3,952,443 |
| Abr | 3,514,295 | 3,831,256 |
| May | 3,723,843 | 4,090,824 |
| Jun | 3,539,170 | 3,837,239 |
| Jul | 3,076,876 | 3,530,077 |
| Ago | 2,979,192 | 3,336,739 |
| Sep a Dic | 3,633,025 a 3,833,780 | no publicado |

Los meses de septiembre a diciembre de 2024 existen y los de 2026 no, así que los totales anuales de 2024 y 2026 no son comparables sin más. Para eso la consulta `5_4_comparacion_por_anio.sql` compara solo enero a agosto de cada año, sobre los viajes que pasan las reglas de limpieza.

| Tipo | Año | Viajes ene a ago | Viajes por día | Mediana millas | Mediana min | Mediana total | Total promedio |
|---|---|---|---|---|---|---|---|
| yellow | 2024 | 25,492,918 | 104,479 | 1.80 | 12.7 | 21.00 | 28.22 |
| yellow | 2026 | 28,146,188 | 115,828 | 1.94 | 14.2 | 23.58 | 30.18 |
| green | 2024 | 412,714 | 1,691 | 1.98 | 12.0 | 19.15 | 23.78 |
| green | 2026 | 319,257 | 1,314 | 2.16 | 13.4 | 20.52 | 25.42 |

Con los mismos ocho meses, los amarillos de 2026 tienen 10.4% más viajes que los de 2024, mientras que los verdes tienen 22.6% menos, y en los dos tipos los viajes de 2026 son un poco más largos, más demorados y más caros. Este contraste nos llamó la atención, porque no es una caída o un aumento general sino que cada servicio se mueve en una dirección distinta, y lo dejamos como pregunta para el ejercicio 8, donde habrá tres años para ver si es una tendencia o un salto.

## 5.7 ¿Las consultas anteriores necesitaban cambios?

Una parte sí. Para saber cuáles, primero guardamos los resultados de las 31 consultas de los ejercicios 3 y 4 antes de tocar nada, después hicimos los cambios necesarios y volvimos a ejecutarlas restringidas a 2026 con la opción `--anios 2026` de `scripts/ejecutar_sql.py`, que compara cada resultado con el guardado.

| Consultas | Lo que pasaba con 2024 en disco | Cambio |
|---|---|---|
| `3_1` a `3_5` (conteos, esquema, muestra) | Leen directamente `.../2026/*.parquet`, así que siguen respondiendo sobre 2026 y no ven 2024 | Ninguno. Las dejamos como la fotografía de 2026 y agregamos `5_1`, `5_2` y `5_3` con la versión por año |
| Vista `viajes` (`00_vista_viajes.sql`) | Tenía `2026` escrito en la ruta de lectura | Ahora lee `yellow/*/` y `green/*/`, saca el año del nombre del archivo en la columna `anio_archivo` y respeta la variable `anios` |
| `3_6a`, `3_7a` y la vista `viajes_limpios` | Tenían el rango de fechas fijo en enero a agosto de 2026 | El rango ahora es relativo al año del archivo, con `make_date(anio_archivo, 1, 1)`. La columna `fuera_de_2026_01_a_08` de `3_6a` se llama ahora `fuera_del_anio_del_archivo` |
| `3_6b` a `3_6i` y `4_1` a `4_12` | Leen a través de las vistas, así que se adaptan solas | Ninguno |

El cambio de las reglas de fecha era imprescindible, y no solo cosmético, porque con el rango fijo en 2026 casi todos los viajes de 2024 quedaban marcados como fuera de rango: de los 41,169,720 viajes amarillos de 2024, solo 2 pasaban la regla vieja, y de los 660,218 verdes, ninguno. Cualquier indicador calculado sobre `viajes_limpios` habría descartado todo 2024 sin avisar ni fallar, que es el tipo de error más peligroso porque la consulta corre y devuelve números que parecen razonables. Lo detectamos antes de que pasara porque estábamos buscando justamente qué constantes de 2026 había en el código.

La prueba de que los cambios no alteraron nada fue que las 31 consultas, restringidas a 2026, dieron los mismos resultados que antes, con una sola diferencia que es el nombre de la columna renombrada en `3_6a`, cuyos valores comprobamos aparte y son idénticos (14 viajes verdes y 17 amarillos fuera del año). Después ejecutamos las mismas 31 consultas sin restringir el año, o sea sobre 2024 y 2026 juntos, y ninguna falló. El tiempo creció de forma aproximadamente proporcional al volumen (por ejemplo `4_4`, la de percentiles, pasó de unos 22 segundos a unos 54), lo cual nos da una idea de cómo escala leer Parquet directamente y es justo lo que compararemos contra una tabla materializada en el ejercicio 6.

Para restringir el año sin editar ninguna consulta usamos una variable de sesión de DuckDB, que las vistas leen con `getvariable('anios')`.

```sql
SET VARIABLE anios = [2026];        -- solo 2026
SET VARIABLE anios = [2024, 2026];  -- 2024 y 2026
RESET VARIABLE anios;               -- todos los años que haya en data/raw
```

Los notebooks de los ejercicios 3 y 4 fijan `anios = [2026]` para que sigan reproduciendo los números documentados, y el del ejercicio 5 usa todos los años. En la última sección del notebook del ejercicio 5 comprobamos que la misma consulta de conteo devuelve 30,040,469 viajes con `[2026]`, 41,829,938 con `[2024]` y ambos años con `[2024, 2026]`.

Un último punto de esta revisión fue el esquema. La consulta `5_3_esquema_por_anio.sql` mostró que las columnas `cbd_congestion_fee` y `request_source` no existen en 2024, y que ninguna columna cambia de tipo entre años, por lo que `union_by_name = true` rellena con nulo lo que falta y no hubo que convertir tipos. Ese cargo de congestión empezó el 5 de enero de 2025 según el diccionario de datos de la TLC, así que su ausencia en 2024 no es un problema de calidad sino un hecho del negocio, y significa que las comparaciones de recargos entre 2024 y 2026 tienen que tener en cuenta que el cargo no existía.

## 5.8 Consultas utilizadas para validar la incorporación de 2024

Todas están en `sql/ejercicio_05/` y el notebook `notebooks/ejercicio_05_incorporacion_2024.ipynb` las ejecuta y guarda el resultado.

| Archivo | Qué valida |
|---|---|
| `5_1_archivos_y_registros_por_anio.sql` | Cantidad de archivos, meses y viajes por tipo y año, leyendo solo la metadata |
| `5_2_registros_por_mes_y_anio.sql` | Una sola consulta sobre 2024 y 2026 con los meses alineados por año |
| `5_3_esquema_por_anio.sql` | Columnas que no están en todos los archivos y cambios de tipo entre años |
| `5_4_comparacion_por_anio.sql` | Indicadores de análisis por año, con los mismos meses de cada año |
| `5_5_calidad_por_anio.sql` | Las mediciones de calidad del ejercicio 3, repetidas por año |

La última merece un comentario porque dice algo que no esperábamos. Los problemas de calidad que encontramos en 2026 no son estables sino que empeoran en algunos casos, y mejoran en otros, con respecto a 2024.

| Tipo | Año | % pasajeros nulos | % distancia cero | % total negativo | Pickup fuera del año |
|---|---|---|---|---|---|
| yellow | 2024 | 9.9 | 1.89 | 1.48 | 56 |
| yellow | 2026 | 26.0 | 3.21 | 0.54 | 17 |
| green | 2024 | 3.7 | 5.24 | 0.33 | 20 |
| green | 2026 | 14.5 | 3.62 | 0.30 | 14 |

Los nulos de pasajeros pasaron de 9.9% a 26.0% en amarillos y de 3.7% a 14.5% en verdes, lo cual refuerza nuestra interpretación del ejercicio 3 de que se trata de viajes de tarifa flexible, una operación que según los datos creció mucho entre los dos años, y los totales negativos van en dirección contraria, de 1.48% a 0.54% en amarillos. Esto nos deja claro que una regla de limpieza calibrada con un solo año puede no servir para otro, y que conviene medir los problemas de calidad por año y no solo en total.

## 5.9 Qué características del diseño permiten incorporar archivos nuevos sin rehacer el flujo

Lo que más nos ayudó es que ningún paso del flujo conoce la lista de archivos. El script de descarga le pregunta al servidor qué meses existen y valida lo que ya hay, así que el mismo comando sirve para 2024, 2025 o los meses nuevos de 2026, y las consultas leen con globs (`yellow/*/*.parquet`) y no con listas de archivos, de modo que un archivo nuevo entra solo con dejarlo en la carpeta correspondiente. El año y el mes se sacan del nombre del archivo y no de una tabla aparte que haya que mantener.

La segunda pieza es que las consultas no se leen directamente del Parquet sino a través de dos vistas, `viajes` y `viajes_limpios`, que concentran en un solo lugar la unión de amarillos y verdes, los nombres comunes y las reglas de limpieza. Cuando 2024 expuso un problema (el rango de fechas fijo), bastó corregirlo en las vistas y en dos consultas, y las otras 22 consultas que pasan por las vistas se arreglaron solas. La tercera es `union_by_name = true`, que hace que columnas que aparecen o desaparecen entre años o meses (como `cbd_congestion_fee` y `request_source`) no rompan la lectura. Por último, el filtro de años por la variable `anios` permite repetir cualquier análisis sobre el subconjunto que se quiera sin editar SQL, y el ejecutor `scripts/ejecutar_sql.py` con su opción de comparar resultados nos permite comprobar en minutos que un cambio no alteró lo ya documentado. Lo que sigue siendo manual, y que nos gustaría automatizar, es decidir qué comparaciones tienen sentido cuando los años no tienen los mismos meses.
