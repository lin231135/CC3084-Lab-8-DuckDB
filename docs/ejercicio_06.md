# Ejercicio 6: Parquet contra tabla materializada en DuckDB

## Qué comparamos y cómo lo organizamos

Comparamos dos formas de responder la misma pregunta con DuckDB, leer directamente los archivos Parquet de `data/raw` o leer una tabla que cargamos antes en una base `.duckdb`, y para que la comparación fuera válida nos propusimos que todo lo demás fuera idéntico. Todo el procedimiento está en `scripts/benchmark_parquet_vs_tabla.py`, las consultas medidas en `sql/ejercicio_06/` y los resultados en `docs/benchmark_resultados.csv`, que el propio script genera, de modo que cualquiera puede repetir la medición con el mismo comando.

Lo más importante para que la comparación fuera justa es que las dos estrategias parten de la misma definición de datos. El archivo `sql/ejercicio_06/00_normalizar_viajes.sql` une amarillos y verdes con nombres de columna comunes (las fechas pasan de `tpep_`/`lpep_` a `pickup`/`dropoff`), agrega `tipo`, `anio_archivo` y `mes_archivo` a partir del nombre del archivo, y se usa de las dos maneras: como vista sobre los Parquet de un volumen concreto en la estrategia de Parquet, y como la consulta que llena la tabla en la otra. Las consultas del benchmark son idénticas para las dos estrategias y solo leen una fuente llamada `src`, que en un caso es esa vista y en el otro es la tabla filtrada a los mismos meses. Además el script compara el resultado de cada consulta entre estrategias con una huella, y en las 35 combinaciones de volumen y consulta los resultados coincidieron, así que no estamos comparando tiempos de consultas que responden cosas distintas.

## 6.1 y 6.2 Consulta directa y tabla materializada

Para la estrategia de Parquet no hay nada que preparar, DuckDB lee los archivos del volumen que se esté midiendo. Para la tabla, el script crea `data/processed/taxis.duckdb` con una tabla `viajes` cuyo esquema se infiere de todos los archivos con `union_by_name`, y después inserta los datos mes por mes con `INSERT ... BY NAME`, en orden de año y mes. Elegimos insertar por mes por dos razones, que la carga es incremental (cuando bajemos 2025 solo se insertan los meses que faltan, sin rehacer lo existente) y que los datos quedan ordenados por mes dentro de la tabla, lo que en principio le permite a DuckDB saltarse bloques enteros cuando se filtra por mes, aunque no medimos cuánto aporta eso. La base también incluye una tabla `zonas` con el catálogo de zonas de la TLC, que usa el tablero del ejercicio 7.

Estos son los números de la carga, medidos en una reconstrucción completa de la tabla.

| Medida | Valor |
|---|---|
| Viajes en la tabla | 71,870,407 |
| Meses cargados | 20 (2024 completo y enero a agosto de 2026) |
| Tiempo de carga | 111.6 s (entre 4.1 y 11.8 s por mes) |
| Tamaño del archivo `.duckdb` | 2,022.8 MB |
| Tamaño de los Parquet de origen | 1,171.7 MB |

Lo que nos llamó la atención es que la tabla materializada pesa 1.7 veces más que los Parquet de donde sale, o sea que materializar no solo cuesta tiempo de carga sino también espacio en disco, y habría que contarlo como un costo más de esa estrategia. No investigamos por qué la compresión de DuckDB resulta menor que la de estos Parquet, así que no podemos dar una explicación.

## 6.3 Consultas representativas

Elegimos siete consultas que cubren los tipos de trabajo que hicimos en el análisis exploratorio: una agregación simple, agregaciones con columnas derivadas y con muchos grupos, una pesada en memoria, dos filtros selectivos y una lectura de una sola columna. Cada una está en su propio archivo.

| Archivo | Qué mide |
|---|---|
| `6_1_conteo_por_tipo_y_mes.sql` | Conteo agrupado por tipo y mes, con muy pocas columnas |
| `6_2_viajes_por_hora.sql` | Agregación con una columna derivada (`hour(pickup)`) y un promedio |
| `6_3_top_zonas_origen.sql` | Agregación con 265 grupos, ordenamiento y `LIMIT` |
| `6_4_mediana_distancia_y_duracion.sql` | Percentiles exactos, que guardan todos los valores en memoria |
| `6_5_filtro_selectivo.sql` | Filtro sobre dos columnas (tarjeta y más de 10 millas) |
| `6_6_suma_una_columna.sql` | Suma de una sola columna de unas veinte |
| `6_7_zona_especifica.sql` | Filtro de igualdad muy selectivo (zona 132, el aeropuerto JFK) |

## 6.4 y 6.5 Cómo medimos

Cada combinación de consulta, estrategia y volumen se ejecuta una vez de calentamiento, que no cuenta pero se guarda como primera ejecución, y luego cinco veces medidas con `time.perf_counter`, y reportamos la mediana, que es menos sensible que el promedio a una repetición que salga lenta por algo ajeno. La desviación estándar típica fue de entre el 8% y el 9% de la mediana, y la mayor variabilidad relativa la tuvo una medición de 0.1 segundos, donde cualquier diferencia pequeña pesa mucho. Para cada estrategia se abre una conexión nueva, de modo que ninguna arrastra memoria de la otra.

El entorno fue DuckDB 1.5.5 con 4 hilos y un límite de 2 GB de memoria, dentro del contenedor `lab8-lab`, en una máquina de 8 núcleos con una máquina virtual de Docker de unos 5 GB, y con el contenedor de Metabase detenido para que no compitiera por CPU y memoria. Los Parquet y la base están en la misma carpeta montada desde Windows, así que las dos estrategias leen del mismo tipo de disco. Hay un límite que conviene tener presente: los archivos quedan en la caché del sistema operativo después del calentamiento, por lo que nuestras medianas representan lecturas con los datos ya cerca, no el caso de un disco frío.

## 6.6 y 6.7 Resultados con distintas cantidades de datos

Medimos cinco volúmenes, que son uno y tres meses, los ocho meses de 2026, los doce de 2024 y los veinte de 2024 y 2026 juntos. Todavía no tenemos 2025, por lo que el volumen de tres años completos se agregará en el ejercicio 8, con el mismo script.

| Volumen | Meses | Viajes | Parquet (MB) |
|---|---|---|---|
| 1 mes | 1 | 3,377,403 | 57 |
| 3 meses | 3 | 10,830,175 | 180 |
| 8 meses (2026) | 8 | 30,040,469 | 496 |
| 12 meses (2024) | 12 | 41,829,938 | 676 |
| 20 meses (2024 y 2026) | 20 | 71,870,407 | 1,172 |

La tabla siguiente muestra la mediana de cinco ejecuciones, en segundos, con el formato Parquet / tabla y entre paréntesis cuántas veces más tarda Parquet que la tabla. Un valor menor que 1 significa que Parquet fue más rápido.

| Consulta | 1 mes | 3 meses | 8 meses (2026) | 12 meses (2024) | 20 meses (2024 y 2026) |
|---|---|---|---|---|---|
| `6_1_conteo_por_tipo_y_mes` | 0.036 / 0.069 (0.5x) | 0.090 / 0.166 (0.5x) | 0.315 / 0.416 (0.8x) | 0.333 / 0.593 (0.6x) | 0.579 / 0.973 (0.6x) |
| `6_2_viajes_por_hora` | 0.228 / 0.092 (2.5x) | 0.613 / 0.225 (2.7x) | 1.669 / 0.625 (2.7x) | 2.211 / 0.905 (2.4x) | 3.913 / 1.359 (2.9x) |
| `6_3_top_zonas_origen` | 0.102 / 0.021 (4.9x) | 0.267 / 0.094 (2.8x) | 0.794 / 0.294 (2.7x) | 1.070 / 0.469 (2.3x) | 1.812 / 0.724 (2.5x) |
| `6_4_mediana_distancia_y_duracion` | 0.618 / 0.469 (1.3x) | 1.980 / 1.351 (1.5x) | 6.087 / 4.020 (1.5x) | 8.349 / 6.889 (1.2x) | 14.669 / 12.007 (1.2x) |
| `6_5_filtro_selectivo` | 0.112 / 0.019 (5.9x) | 0.261 / 0.087 (3.0x) | 0.906 / 0.195 (4.6x) | 1.313 / 0.502 (2.6x) | 2.055 / 0.630 (3.3x) |
| `6_6_suma_una_columna` | 0.078 / 0.012 (6.5x) | 0.179 / 0.082 (2.2x) | 0.741 / 0.223 (3.3x) | 0.675 / 0.326 (2.1x) | 1.195 / 0.554 (2.2x) |
| `6_7_zona_especifica` | 0.087 / 0.013 (6.7x) | 0.212 / 0.071 (3.0x) | 0.720 / 0.133 (5.4x) | 0.870 / 0.228 (3.8x) | 1.632 / 0.347 (4.7x) |

Sumando las siete consultas, una ronda completa con Parquet tarda 1.26 s en un mes y 25.86 s en veinte meses, y con la tabla 0.70 s y 16.59 s. Los tiempos individuales completos, con mínimo, máximo, desviación y la primera ejecución, están en `docs/benchmark_resultados.csv`.

## 6.8 Consultas utilizadas

Son las siete de `sql/ejercicio_06/` descritas en 6.3, más `00_normalizar_viajes.sql`, que define las columnas comunes. El procedimiento completo está en el script y se reproduce con los comandos de la sección de benchmarks del README.

## 6.9 Análisis de las diferencias

En seis de las siete consultas la tabla fue más rápida en todos los volúmenes, entre 1.2 y 6.7 veces según la consulta, y la excepción es la primera, donde ganó Parquet de forma consistente, con tiempos que son entre 0.5 y 0.8 veces los de la tabla. Esa excepción la entendimos mirando el plan de ejecución de `EXPLAIN ANALYZE`. En `6_1` el tipo de taxi y el mes salen del nombre del archivo, y el plan de Parquet muestra que lo único que proyecta es la columna `filename`, o sea que cuenta las filas de cada archivo sin decodificar ningún dato, mientras que la tabla sí tiene que leer sus columnas `tipo` y `mes_archivo`. Es un caso donde la estructura de archivos por mes le regala información al Parquet, y no deberíamos tomarlo como que Parquet sea más rápido en general.

Para las consultas que sí leen datos la ventaja de la tabla es clara pero modesta, de 2 a 5 veces, y hay un patrón que se repite, que es que la ventaja es mayor cuando la consulta toca pocas columnas o filtra mucho (`6_5`, `6_6`, `6_7`) y menor cuando el cálculo domina. En `6_4`, la de las medianas, la diferencia es de apenas 1.2 a 1.5 veces porque la mayor parte del tiempo se va en calcular percentiles exactos sobre decenas de millones de valores, algo que cuesta lo mismo se lea de donde se lea, y eso nos dice que materializar no acelera lo que es costoso por el cálculo y no por la lectura. En el volumen de un mes, la ventaja es más grande en proporción (de 4.9 a 6.7 veces en `6_3`, `6_5`, `6_6` y `6_7`), y lo atribuimos a que con tan pocos datos pesa más el costo fijo de abrir los archivos y planificar la lectura de Parquet, aunque con una sola medición por volumen no podemos separar esa causa de otras. A partir de tres meses la razón de las consultas que no son de percentiles se mueve en una banda de aproximadamente 2 a 5 veces.

Sobre cómo escalan los tiempos, ambas estrategias crecen de forma casi lineal con el volumen: de uno a veinte meses los datos crecen unas 21 veces y la suma de las siete consultas crece 20 veces en Parquet (1.26 a 25.86 s) y 24 veces en la tabla (0.70 a 16.59 s). No vimos ningún punto donde alguna de las dos estrategias se volviera impracticable en este rango de datos, que es lo que esperábamos porque los 72 millones de filas caben cómodos en un procesamiento por columnas en una sola máquina.

Un último hallazgo es el de la primera ejecución. En el volumen de veinte meses, la primera ejecución de la tabla fue entre 1.4 y 4.6 veces más lenta que su mediana en seis de las siete consultas, porque todavía tiene que traer los bloques del disco a la memoria de DuckDB, mientras que la de Parquet fue como mucho 1.3 veces más lenta. En la consulta `6_7`, por ejemplo, la primera ejecución con Parquet tardó 1.81 s y con la tabla 1.59 s, casi lo mismo, y la mediana de las siguientes fue de 1.63 y 0.35 s. O sea que la ventaja de la tabla aparece sobre todo cuando se repiten consultas sobre los mismos datos, y casi no existe en una consulta que se corre una sola vez.

## 6.10 Cuándo usar cada estrategia

La tabla materializada nos parece conveniente cuando los mismos datos se consultan muchas veces, como en el tablero de Metabase, donde cada vez que se abre la página se ejecutan 17 consultas, o durante una sesión larga de análisis. Con nuestras medidas, una ronda de las siete consultas sobre veinte meses ahorra unos 9.3 s respecto a Parquet, y la carga costó 111.6 s, o sea que se amortiza después de unas 12 rondas, sin contar el espacio extra en disco. También conviene cuando se necesita una base que un programa externo pueda abrir en un solo archivo, que es el caso de Metabase, cuyo driver de DuckDB se conecta a un `.duckdb`.

Consultar directamente el Parquet nos parece mejor para exploración puntual o para consultas que se corren una vez, porque no hay carga previa ni espacio duplicado, y como la primera ejecución con la tabla casi no gana, no tiene sentido pagar la carga por una sola consulta. También es mejor cuando los datos siguen llegando, porque basta dejar el archivo nuevo en la carpeta para que el glob lo incluya, mientras que la tabla hay que mantenerla al día (nuestro script lo hace insertando solo los meses que faltan, pero es un paso más que puede olvidarse). Y cuando las consultas dependen de la estructura de archivos, como contar por mes de archivo, Parquet puede ganar sin esfuerzo, como vimos en `6_1`. En un caso como el nuestro, con datos que llegan por mes y se analizan de dos formas distintas, nos quedaríamos con los dos: Parquet como fuente de verdad y para explorar, y la tabla como copia derivada para lo que se consulta con frecuencia.
