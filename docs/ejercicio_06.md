# Ejercicio 6: Parquet contra tabla materializada en DuckDB

## Qué comparamos y cómo lo organizamos

Comparamos dos formas de responder la misma pregunta con DuckDB, leer directamente los archivos Parquet de `data/raw` o leer una tabla que cargamos antes en una base `.duckdb`, y para que la comparación fuera válida nos propusimos que todo lo demás fuera idéntico. Todo el procedimiento está en `scripts/benchmark_parquet_vs_tabla.py`, las consultas medidas en `sql/ejercicio_06/` y los resultados en `docs/benchmark_resultados.csv`, que el propio script genera, de modo que cualquiera puede repetir la medición con el mismo comando.

Lo más importante para que la comparación fuera justa es que las dos estrategias parten de la misma definición de datos. El archivo `sql/ejercicio_06/00_normalizar_viajes.sql` une amarillos y verdes con nombres de columna comunes (las fechas pasan de `tpep_`/`lpep_` a `pickup`/`dropoff`), agrega `tipo`, `anio_archivo` y `mes_archivo` a partir del nombre del archivo, y se usa de las dos maneras: como vista sobre los Parquet de un volumen concreto en la estrategia de Parquet, y como la consulta que llena la tabla en la otra. Las consultas del benchmark son idénticas para las dos estrategias y solo leen una fuente llamada `src`, que en un caso es esa vista y en el otro es la tabla filtrada a los mismos meses. Además el script compara el resultado de cada consulta entre estrategias con una huella, y en las 42 combinaciones de volumen y consulta los resultados coinciden, así que no estamos comparando tiempos de consultas que responden cosas distintas.

Esa comprobación nos sirvió en una ocasión. En la consulta de suma de una columna, con tres años de datos (121 millones de filas), las dos estrategias daban `3,389,627,631.05` y `3,389,627,630.97`, una diferencia de 0.08 dólares sobre 3,390 millones. No era un error de datos sino que la suma de decimales en paralelo no es asociativa, y el orden en que se juntan los resultados parciales cambia el último decimal. Cambiamos la consulta para que sume centavos enteros, que sí es exacto sin importar el orden, y desde entonces coinciden. Es un detalle que no se nota con un mes de datos y que aparece cuando el volumen crece.

## 6.1 y 6.2 Consulta directa y tabla materializada

Para la estrategia de Parquet no hay nada que preparar, DuckDB lee los archivos del volumen que se esté midiendo. Para la tabla, el script crea `data/processed/taxis.duckdb` con una tabla `viajes` cuyo esquema se infiere de todos los archivos con `union_by_name`, y después inserta los datos mes por mes con `INSERT ... BY NAME`, en orden de año y mes. Elegimos insertar por mes por dos razones, que la carga es incremental (cuando bajamos 2025 solo se insertaron los 12 meses que faltaban, sin rehacer lo existente) y que los datos quedan ordenados por mes dentro de la tabla, lo que en principio le permite a DuckDB saltarse bloques enteros cuando se filtra por mes, aunque no medimos cuánto aporta eso. La base también incluye una tabla `zonas` con el catálogo de zonas de la TLC, que usa el tablero del ejercicio 7.

Estos son los números de la carga.

| Medida | Valor |
|---|---|
| Viajes en la tabla | 121,184,384 |
| Meses cargados | 32 (2024 y 2025 completos, y enero a agosto de 2026) |
| Primera carga (20 meses, 2024 y 2026) | 111.6 s, entre 4.1 y 11.8 s por mes |
| Carga incremental de 2025 (12 meses) | 96.7 s, entre 6.6 y 10.0 s por mes |
| Tamaño del archivo `.duckdb` | 3,377 MB |
| Tamaño de los Parquet de origen | 1,977 MB |

Lo que nos llamó la atención es que la tabla materializada pesa 1.7 veces más que los Parquet de donde sale, o sea que materializar no solo cuesta tiempo de carga sino también espacio en disco, y habría que contarlo como un costo más de esa estrategia. Como veremos más abajo, ese tamaño terminó importando mucho. No investigamos por qué la compresión de DuckDB resulta menor que la de estos Parquet, así que no podemos dar una explicación.

## 6.3 Consultas representativas

Elegimos siete consultas que cubren los tipos de trabajo que hicimos en el análisis exploratorio: una agregación simple, agregaciones con columnas derivadas y con muchos grupos, una pesada en memoria, dos filtros selectivos y una lectura de una sola columna. Cada una está en su propio archivo.

| Archivo | Qué mide |
|---|---|
| `6_1_conteo_por_tipo_y_mes.sql` | Conteo agrupado por tipo y mes, con muy pocas columnas |
| `6_2_viajes_por_hora.sql` | Agregación con una columna derivada (`hour(pickup)`) y un promedio |
| `6_3_top_zonas_origen.sql` | Agregación con 265 grupos, ordenamiento y `LIMIT` |
| `6_4_mediana_distancia_y_duracion.sql` | Percentiles exactos, que guardan todos los valores en memoria |
| `6_5_filtro_selectivo.sql` | Filtro sobre dos columnas (tarjeta y más de 10 millas) |
| `6_6_suma_una_columna.sql` | Suma de una sola columna de unas veinte, en centavos enteros |
| `6_7_zona_especifica.sql` | Filtro de igualdad muy selectivo (zona 132, el aeropuerto JFK) |

## 6.4 y 6.5 Cómo medimos

Cada combinación de consulta, estrategia y volumen se ejecuta una vez de calentamiento, que no cuenta pero se guarda como primera ejecución, y luego cinco veces medidas con `time.perf_counter`, y reportamos la mediana, que es menos sensible que el promedio a una repetición que salga lenta por algo ajeno. La desviación estándar típica fue de entre el 6% y el 7% de la mediana, y la mayor variabilidad relativa (36%) la tuvo la consulta de medianas sobre la tabla con tres años, justo el caso donde la memoria no alcanza, como se explica en 6.9. Para cada estrategia se abre una conexión nueva, de modo que ninguna arrastra memoria de la otra.

El entorno fue DuckDB 1.5.5 con 4 hilos y un límite de 2 GB de memoria, dentro del contenedor `lab8-lab`, en una máquina de 8 núcleos con una máquina virtual de Docker de unos 5 GB, y con el contenedor de Metabase detenido para que no compitiera por CPU y memoria. Los Parquet y la base están en la misma carpeta montada desde Windows, así que las dos estrategias leen del mismo tipo de disco. Hay un límite que conviene tener presente: los archivos quedan en la caché del sistema operativo después del calentamiento, por lo que nuestras medianas representan lecturas con los datos ya cerca, no el caso de un disco frío.

## 6.6 y 6.7 Resultados con distintas cantidades de datos

Medimos seis volúmenes, que son uno y tres meses, los ocho meses de 2026, los doce de 2024, los veinte de 2024 y 2026 juntos, y los treinta y dos de los tres años. Los cinco primeros los medimos antes de tener 2025 y el sexto al incorporarlo en el ejercicio 8, y para que fueran comparables volvimos a medir los seis juntos en la misma sesión con el mismo script.

| Volumen | Meses | Viajes | Parquet (MB) |
|---|---|---|---|
| 1 mes | 1 | 3,377,403 | 57 |
| 3 meses | 3 | 10,830,175 | 180 |
| 8 meses (2026) | 8 | 30,040,469 | 496 |
| 12 meses (2024) | 12 | 41,829,938 | 676 |
| 20 meses (2024 y 2026) | 20 | 71,870,407 | 1,172 |
| 32 meses (2024 a 2026) | 32 | 121,184,384 | 1,977 |

La tabla siguiente muestra la mediana de cinco ejecuciones, en segundos, con el formato Parquet / tabla y entre paréntesis cuántas veces más tarda Parquet que la tabla. Un valor menor que 1 significa que Parquet fue más rápido.

| Consulta | 1 mes | 3 meses | 8 meses (2026) | 12 meses (2024) | 20 meses (2024 y 2026) | 32 meses (2024 a 2026) |
|---|---|---|---|---|---|---|
| `6_1_conteo_por_tipo_y_mes` | 0.059 / 0.089 (0.7x) | 0.141 / 0.210 (0.7x) | 0.370 / 0.525 (0.7x) | 0.429 / 0.755 (0.6x) | 0.715 / 0.998 (0.7x) | 0.955 / 1.567 (0.6x) |
| `6_2_viajes_por_hora` | 0.378 / 0.124 (3.0x) | 0.859 / 0.277 (3.1x) | 2.487 / 0.784 (3.2x) | 2.898 / 1.033 (2.8x) | 4.706 / 1.439 (3.3x) | 5.997 / 2.212 (2.7x) |
| `6_3_top_zonas_origen` | 0.174 / 0.037 (4.7x) | 0.378 / 0.126 (3.0x) | 1.318 / 0.398 (3.3x) | 1.345 / 0.522 (2.6x) | 2.349 / 0.702 (3.3x) | 2.859 / 1.204 (2.4x) |
| `6_4_mediana_distancia_y_duracion` | 0.867 / 0.607 (1.4x) | 2.278 / 1.681 (1.4x) | 7.054 / 4.658 (1.5x) | 9.714 / 6.714 (1.4x) | 13.980 / 10.136 (1.4x) | 27.772 / 37.074 (0.7x) |
| `6_5_filtro_selectivo` | 0.136 / 0.031 (4.4x) | 0.398 / 0.134 (3.0x) | 1.214 / 0.332 (3.7x) | 1.524 / 0.540 (2.8x) | 2.181 / 0.531 (4.1x) | 3.492 / 0.932 (3.7x) |
| `6_6_suma_una_columna` | 0.116 / 0.026 (4.5x) | 0.259 / 0.131 (2.0x) | 0.703 / 0.377 (1.9x) | 0.840 / 0.517 (1.6x) | 1.747 / 0.899 (1.9x) | 2.536 / 1.568 (1.6x) |
| `6_7_zona_especifica` | 0.115 / 0.022 (5.2x) | 0.328 / 0.092 (3.6x) | 1.085 / 0.162 (6.7x) | 0.994 / 0.281 (3.5x) | 1.569 / 0.414 (3.8x) | 2.623 / 2.697 (1.0x) |

Sumando las siete consultas, una ronda completa con Parquet tarda 1.84 s en un mes, 27.25 s en veinte meses y 46.23 s en treinta y dos, y con la tabla 0.94 s, 15.12 s y 47.25 s. Los tiempos individuales completos, con mínimo, máximo, desviación y la primera ejecución, están en `docs/benchmark_resultados.csv`.

## 6.8 Consultas utilizadas

Son las siete de `sql/ejercicio_06/` descritas en 6.3, más `00_normalizar_viajes.sql`, que define las columnas comunes. El procedimiento completo está en el script y se reproduce con los comandos de la sección de benchmarks del README.

## 6.9 Análisis de las diferencias

Hasta veinte meses de datos la tabla fue más rápida en seis de las siete consultas, entre 1.4 y 6.7 veces según la consulta, y la excepción es la primera, donde ganó Parquet de forma consistente, con tiempos que son entre 0.6 y 0.7 veces los de la tabla. Esa excepción la entendimos mirando el plan de ejecución de `EXPLAIN ANALYZE`. En `6_1` el tipo de taxi y el mes salen del nombre del archivo, y el plan de Parquet muestra que lo único que proyecta es la columna `filename`, o sea que cuenta las filas de cada archivo sin decodificar ningún dato, mientras que la tabla sí tiene que leer sus columnas `tipo` y `mes_archivo`. Es un caso donde la estructura de archivos por mes le regala información al Parquet, y no deberíamos tomarlo como que Parquet sea más rápido en general.

Para las consultas que sí leen datos la ventaja de la tabla es clara pero modesta, de 1.6 a 6.7 veces, y hay un patrón que se repite, que es que la ventaja es mayor cuando la consulta toca pocas columnas o filtra mucho (`6_5`, `6_6`, `6_7`) y menor cuando el cálculo domina. En `6_4`, la de las medianas, la diferencia es de apenas 1.4 a 1.5 veces porque la mayor parte del tiempo se va en calcular percentiles exactos sobre decenas de millones de valores, algo que cuesta lo mismo se lea de donde se lea, y eso nos dice que materializar no acelera lo que es costoso por el cálculo y no por la lectura. En el volumen de un mes la ventaja es más grande en proporción (de 4.4 a 5.2 veces en `6_3`, `6_5`, `6_6` y `6_7`), y lo atribuimos a que con tan pocos datos pesa más el costo fijo de abrir los archivos y planificar la lectura de Parquet, aunque con una sola medición por volumen no podemos separar esa causa de otras.

Lo que más nos sorprendió está en la última columna. Con los treinta y dos meses la ventaja de la tabla desaparece: la suma de las siete consultas da 46.23 s con Parquet y 47.25 s con la tabla, y dos consultas se invierten o se empatan, la de medianas (`6_4`), donde la tabla tarda 37.1 s contra 27.8 s de Parquet, y la de zona específica (`6_7`), con 2.70 s contra 2.62 s. Entre veinte y treinta y dos meses los datos crecen 1.7 veces, y el tiempo total con Parquet crece también 1.7 veces (27.25 a 46.23 s), o sea que sigue siendo lineal, pero con la tabla crece 3.1 veces (15.12 a 47.25 s). Nuestra hipótesis era que la tabla, que ahora pesa 3.4 GB, ya no cabía en los 2 GB de memoria que le dimos a DuckDB, de modo que cada consulta tenía que volver a leer del disco bloques que no lograba mantener en memoria, mientras que Parquet se apoya en la caché del sistema operativo y solo lee las columnas que necesita.

Para comprobarlo en lugar de suponerlo, repetimos tres consultas con el volumen de treinta y dos meses subiendo el límite de memoria a 4 GB. Los resultados están en `docs/benchmark_memoria_4gb.csv`.

| Consulta (32 meses) | Parquet, 2 GB | Tabla, 2 GB | Parquet, 4 GB | Tabla, 4 GB |
|---|---|---|---|---|
| `6_3_top_zonas_origen` | 2.859 | 1.204 | 2.754 | 1.199 |
| `6_4_mediana_distancia_y_duracion` | 27.772 | 37.074 | 29.281 | 22.331 |
| `6_7_zona_especifica` | 2.623 | 2.697 | 2.887 | 0.664 |

Con más memoria la tabla recupera su ventaja en `6_7` (de 2.70 a 0.66 s, ya 4.3 veces más rápida que Parquet) y en `6_4` (de 37.1 a 22.3 s, ahora 1.3 veces más rápida), mientras que Parquet casi no cambia (entre 4% y 10%, que es del orden de la variación entre corridas), lo cual respalda nuestra hipótesis. En `6_3` no pasó nada con la memoria, así que el efecto no alcanza a todas las consultas y no sabemos por qué esa se salva, quizá porque solo necesita leer una columna. Lo que sacamos en limpio es que el beneficio de materializar depende de que la tabla quepa en la memoria disponible para DuckDB, y que cuando no cabe se puede perder por completo, algo que no se ve con volúmenes pequeños.

Un último hallazgo es el de la primera ejecución. En el volumen de treinta y dos meses, la primera ejecución de la tabla fue entre 1.5 y 3.6 veces más lenta que su mediana, porque todavía tiene que traer los bloques del disco a la memoria de DuckDB, mientras que la de Parquet fue como mucho 1.35 veces más lenta. O sea que la ventaja de la tabla aparece sobre todo cuando se repiten consultas sobre los mismos datos, y casi no existe en una consulta que se corre una sola vez.

## 6.10 Cuándo usar cada estrategia

La tabla materializada nos parece conveniente cuando los mismos datos se consultan muchas veces y la tabla cabe holgadamente en la memoria asignada a DuckDB, como en el tablero de Metabase, donde cada vez que se abre la página se ejecutan 17 consultas, o durante una sesión larga de análisis. Con nuestras medidas, una ronda de las siete consultas sobre veinte meses ahorra unos 12.1 s respecto a Parquet, y la carga costó 111.6 s, o sea que se amortiza después de unas 9 rondas, sin contar el espacio extra en disco. También conviene cuando se necesita una base que un programa externo pueda abrir en un solo archivo, que es el caso de Metabase, cuyo driver de DuckDB se conecta a un `.duckdb`. Lo que aprendimos con los treinta y dos meses es que esa conveniencia tiene un techo: con la memoria que teníamos, la tabla de 3.4 GB dejó de ser mejor que Parquet, así que habría que subir la memoria o particionar los datos antes de seguir creciendo.

Consultar directamente el Parquet nos parece mejor para exploración puntual o para consultas que se corren una vez, porque no hay carga previa ni espacio duplicado, y como la primera ejecución con la tabla casi no gana, no tiene sentido pagar la carga por una sola consulta. También es mejor cuando los datos siguen llegando, porque basta dejar el archivo nuevo en la carpeta para que el glob lo incluya, mientras que la tabla hay que mantenerla al día (nuestro script lo hace insertando solo los meses que faltan, pero es un paso más que puede olvidarse). Y cuando las consultas dependen de la estructura de archivos, como contar por mes de archivo, Parquet puede ganar sin esfuerzo, como vimos en `6_1`. Su rendimiento además es más predecible, porque creció de forma lineal con el volumen en todo el rango que medimos. En un caso como el nuestro, con datos que llegan por mes y se analizan de dos formas distintas, nos quedaríamos con los dos: Parquet como fuente de verdad y para explorar, y la tabla como copia derivada para lo que se consulta con frecuencia, siempre que se le dé memoria suficiente.
