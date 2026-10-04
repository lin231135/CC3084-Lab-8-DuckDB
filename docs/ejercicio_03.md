# Ejercicio 3: consultas directas sobre archivos Parquet

## Cómo está organizado este ejercicio

Todas las consultas están en `sql/ejercicio_03/`, un archivo por consulta, y el notebook `notebooks/ejercicio_03_consultas_parquet.ipynb` las lee desde ahí, muestra el SQL y guarda el resultado de su ejecución, de modo que cada consulta existe en un solo lugar y este documento la referencia por nombre de archivo. Ninguna consulta importa los datos a una tabla, todas leen los Parquet con `read_parquet`, `glob`, `parquet_schema` o `parquet_file_metadata`. Los datos son los 16 archivos de 2026 (enero a agosto, amarillos y verdes) que descargamos en el ejercicio 2, y todos los números de este documento salen de ejecutar esos archivos dentro del contenedor `lab8-lab`.

Una decisión que tomamos desde el principio fue crear una vista llamada `viajes` (`00_vista_viajes.sql`) que une amarillos y verdes con nombres de columna comunes (`pickup`, `dropoff`, y las demás sin cambios). Una vista en DuckDB no copia nada, solo guarda la consulta, así que cada vez que se usa vuelve a leer los Parquet, y por eso nos pareció compatible con la idea del ejercicio de consultar sin importar. La razón para usarla es práctica, porque las consultas de calidad se repetirían con el mismo bloque de unión en cada archivo y si algo cambia, como veremos cuando entre 2024, hay un solo lugar donde corregirlo. Una aclaración importante es que, cuando escribimos este ejercicio, la vista solo existía para 2026; después, al incorporar 2024 en el ejercicio 5, la generalizamos para que lea todos los años de `data/raw` y respete una variable de sesión `anios`, y por eso el notebook de este ejercicio fija `SET VARIABLE anios = [2026]` y los resultados de este documento siguen siendo los de 2026. En esa generalización las reglas de fecha de `3_6a` y `3_7a` pasaron de un rango fijo de 2026 a uno relativo al año del archivo, y la columna `fuera_de_2026_01_a_08` de `3_6a` se llama ahora `fuera_del_anio_del_archivo`, con los mismos valores. Las consultas `3_1` a `3_5` leen directamente la carpeta de 2026 y no cambiaron.

## 3.1 Cantidad de archivos

La consulta `3_1_cantidad_archivos.sql` usa `glob()` sobre `data/raw/*/2026/*.parquet`, que solo lista los nombres y no abre ningún archivo. Encontramos 16 archivos, 8 de taxis amarillos y 8 de verdes, con meses de 2026-01 a 2026-08 en ambos tipos. Esto coincide con lo que reportó el script de descarga, así que no tomamos ninguna decisión nueva a partir de este resultado.

## 3.2 Cantidad de registros

Contamos de dos maneras. La consulta `3_2a_registros_por_tipo_y_mes.sql` hace un `count(*)` leyendo los datos con `filename = true` para agrupar por archivo, y `3_2b_registros_segun_metadata.sql` suma el campo `num_rows` del pie de página de cada Parquet sin leer ninguna fila de datos. Ambas dan lo mismo, 30,040,469 viajes en total, de los cuales 29,703,355 son de amarillos y 337,114 de verdes.

| Mes | Amarillos | Verdes |
|---|---|---|
| 2026-01 | 3,724,889 | 40,272 |
| 2026-02 | 3,399,866 | 37,373 |
| 2026-03 | 3,952,451 | 44,208 |
| 2026-04 | 3,831,240 | 44,238 |
| 2026-05 | 4,090,836 | 44,921 |
| 2026-06 | 3,837,248 | 44,163 |
| 2026-07 | 3,530,109 | 41,252 |
| 2026-08 | 3,336,716 | 40,687 |

Lo que más nos llamó la atención es la diferencia de escala, porque los verdes son apenas el 1.1% de los viajes y eso va a condicionar cómo los comparamos con los amarillos en el ejercicio 4, ya que un conteo absoluto de verdes siempre se va a ver minúsculo y habrá que comparar proporciones. La metadata también nos dio otro dato útil, que cada archivo amarillo tiene 4 grupos de filas y cada verde uno solo (40 en total), algo que retomamos en 3.9. Decidimos usar la consulta de metadata como validación rápida cada vez que se agreguen archivos, porque responde en una fracción del tiempo del conteo completo.

## 3.3 y 3.4 Columnas y tipos de datos

La consulta `3_3_y_3_4_columnas_y_tipos.sql` pone lado a lado los esquemas de amarillos y verdes. Veinte columnas están en ambos tipos con el mismo tipo de dato (contando las dos de fecha, que se llaman `tpep_` en amarillos y `lpep_` en verdes), y hay tres que no coinciden: `Airport_fee` existe solo en amarillos, y `ehail_fee` y `trip_type` solo en verdes. Los tipos principales son los mismos en los dos conjuntos.

| Columna | Tipo | Observación |
|---|---|---|
| `tpep_pickup_datetime`, `tpep_dropoff_datetime` (`lpep_` en verdes) | TIMESTAMP | nombre distinto según el tipo |
| `VendorID`, `PULocationID`, `DOLocationID` | INTEGER | |
| `passenger_count`, `RatecodeID`, `payment_type`, `trip_type` | BIGINT | admiten nulos |
| `trip_distance`, `fare_amount`, `extra`, `mta_tax`, `tip_amount`, `tolls_amount`, `improvement_surcharge`, `total_amount`, `congestion_surcharge`, `cbd_congestion_fee`, `Airport_fee`, `ehail_fee` | DOUBLE | |
| `store_and_fwd_flag`, `request_source` | VARCHAR | |

La consulta `3_4b_columnas_por_archivo.sql` revisa si el esquema cambia entre meses, y encontramos que sí cambia: `request_source` aparece únicamente en 3 de los 8 archivos de cada tipo, a partir de 2026-06. Esa es la razón de fondo por la que usamos `union_by_name = true` en todas las lecturas, porque sin esa opción DuckDB toma el esquema del primer archivo y esa columna se perdería o provocaría un error al combinar meses. En los meses anteriores a junio su valor queda nulo. Además, `cbd_congestion_fee` es el cargo de la zona de congestión que según el diccionario de la TLC empezó el 5 de enero de 2025, así que no esperamos encontrarlo con valores en 2024, y lo revisaremos al incorporar ese año. Nos deja pensando que si el esquema ya cambió dentro de un mismo año, es bastante probable que al sumar 2024 y 2025 aparezcan más cambios, incluso de tipo, y por eso dejamos el aviso para el ejercicio 5.

## 3.5 Muestra de registros

Las consultas `3_5a_muestra_yellow.sql` y `3_5b_muestra_green.sql` filtran por una clase de hash de la fecha, las zonas y el total, en lugar de usar un muestreo aleatorio, para que la muestra sea idéntica en cada ejecución y cualquiera que corra el notebook vea las mismas filas. Obtuvimos 8 viajes amarillos y 6 verdes. La muestra amarilla incluye un caso que ya anticipaba el problema más grande de los datos, el viaje del 2026-05-20 con `passenger_count`, `RatecodeID` y `store_and_fwd_flag` nulos, `payment_type = 0` y distancia 0, y la verde incluye uno de `VendorID = 6` con nulos parecidos. También aparece un viaje amarillo de 0.20 millas con tarifa de 105 dólares y `RatecodeID = 5` (tarifa negociada), que es un recordatorio de que la tarifa no siempre guarda relación con la distancia. Decidimos que en el ejercicio 4 trataremos esos viajes con nulos como una categoría aparte y no como errores sin más, por lo que explicamos en 3.6.

## 3.6 Problemas de calidad de datos

Resumimos primero lo encontrado y luego lo discutimos. Los porcentajes son sobre el total de viajes de cada tipo.

| Problema | Amarillos | Verdes | Consulta |
|---|---|---|---|
| Pickup fuera del año del archivo (2026) | 17 (mínimo 2001-01-01) | 14 (mínimo 2008-12-31) | `3_6a_calidad_fechas.sql` |
| Pickup fuera del mes del archivo | 146 | 98 | `3_6a_calidad_fechas.sql` |
| Bajada antes de la subida | 10 | 5 | `3_6b_calidad_duracion.sql` |
| Duración cero | 371,673 (1.25%) | 229 (0.07%) | `3_6b_calidad_duracion.sql` |
| Duración mayor a 6 horas | 7,315 | 1,104 | `3_6b_calidad_duracion.sql` |
| Distancia cero | 952,231 (3.2%) | 12,212 (3.6%) | `3_6c_calidad_distancia.sql` |
| Distancia mayor a 1000 millas | 615 (máximo 328,522) | 66 (máximo 179,831) | `3_6c_calidad_distancia.sql` |
| Tarifa negativa | 157,364 | 999 | `3_6d_calidad_montos.sql` |
| Total negativo | 161,835 (0.54%) | 1,023 (0.30%) | `3_6d_calidad_montos.sql` |
| Total mayor a 500 dólares | 791 (máximo 7,053.50) | 21 | `3_6d_calidad_montos.sql` |
| Pasajeros nulos | 7,716,688 (26.0%) | 48,775 (14.5%) | `3_6f_calidad_nulos.sql` |
| Pasajeros en 0 | 91,359 | 4,527 | `3_6f_calidad_nulos.sql` |
| Posibles filas duplicadas | 32,790 | 0 | `3_6i_calidad_duplicados.sql` |

Los valores de fecha son los más fáciles de descartar, porque un viaje de 2001 o de 2008 en un archivo de 2026 solo puede ser un error del dispositivo, y son muy pocos. Los 146 y 98 viajes que caen en un mes distinto al de su archivo son de otra naturaleza, ya que casi todos son del mes vecino (por ejemplo viajes de 2026-08 dentro del archivo de 2026-07) y parecen viajes que se registraron tarde, por lo que no los consideramos un error grave pero sí una advertencia de que el mes del archivo no equivale exactamente al mes del viaje, y para análisis temporales conviene agrupar por la fecha de recogida y no por el nombre del archivo.

Las distancias y duraciones tienen el mismo patrón, una masa de valores plausibles y una cola absurda. La mediana de duración (de los viajes con duración positiva) es de 14.1 minutos en amarillos y 13.1 en verdes, y el percentil 99 de 71.4 y 82.3 minutos, pero hay viajes de más de 24 horas (263 amarillos) y distancias de más de 300 mil millas, que es mayor a la distancia de la Tierra a la Luna, lo cual sólo se explica por un error del taxímetro. Estos casos son pocos en proporción, pero afectan mucho a promedios y a máximos, y por eso nos parece que para medidas de tendencia central hay que usar la mediana o filtrar.

Los montos negativos fueron lo que más nos hizo dudar si eran errores, así que escribimos la consulta `3_6e_calidad_montos_negativos_por_pago.sql` para ver a qué tipo de pago pertenecen. Resulta que no son errores aleatorios: el 42.1% de los viajes amarillos con `payment_type = 4` (disputa) y el 18.1% de los de `payment_type = 3` (sin cargo) tienen total negativo, frente a 0.0% en tarjeta y 1.5% en efectivo, y en verdes pasa algo parecido (37.2% en disputas y 33.4% en sin cargo). Entendemos que son reversiones o ajustes contables y no datos mal capturados, así que para análisis de ingresos por viaje no deben mezclarse con los viajes normales, aunque para estudiar los pagos sí tienen sentido por sí mismos.

El hallazgo que más pesa en los datos es el de los nulos. En amarillos, 7,716,688 viajes tienen nulos a la vez en `passenger_count`, `RatecodeID` y `store_and_fwd_flag`, y `payment_type` igual a 0, y la consulta `3_6f_calidad_nulos.sql` confirma que son exactamente las mismas filas (la columna `todos_nulos_juntos` coincide con cada conteo individual). En verdes pasa lo mismo con 48,775 viajes, con la diferencia de que ahí `payment_type` viene nulo y no 0. El diccionario de datos de la TLC dice que `payment_type = 0` corresponde a un viaje de tarifa flexible (Flex Fare), así que creemos que no son datos corruptos sino viajes de otro tipo de operación que no capturan esos campos. No es un problema de un mes puntual, porque `3_6g_calidad_nulos_por_mes.sql` muestra que el porcentaje de amarillos con pasajeros nulos va de 20.9% (abril) a 30.1% (febrero) y el de verdes de 12.8% a 15.6%, sin ningún mes que se salga. Esto nos parece lo más importante del ejercicio, porque más de una cuarta parte de los amarillos no tiene número de pasajeros, y cualquier promedio de pasajeros que no lo considere estaría calculado sobre tres cuartas partes de los viajes sin avisarlo.

Los pasajeros en 0 (91,359 amarillos) y los de más de 6 (28 amarillos y 99 verdes) los tomamos como errores de captura menores, y por lo mismo no los eliminamos todavía. Los posibles duplicados (32,790 filas amarillas repetidas según siete columnas que identifican un viaje) son apenas el 0.11%, y los dejamos así porque no podemos asegurar que sean duplicados reales, ya que dos viajes distintos podrían coincidir en todas esas columnas; la consulta solo da una cota.

Por último, la consulta `3_6h_calidad_request_source.sql` muestra que `request_source` empieza en junio y que, aunque es nula en la mayoría de los viajes (por ejemplo 2,415,867 de 3,336,716 amarillos en agosto), toma valores como `HV0003`, `HV0005`, `A`, `EH0004`, `CC` y `EH0010`. Esta columna no aparece en el diccionario de datos de la TLC que revisamos, así que no sabemos con certeza qué significa cada código, y preferimos no interpretarla en el análisis. Lo que sí podemos decir es que cambia el esquema a mitad de año, y que `HV0005` aparece en amarillos recién en agosto.

## 3.7 Consultas necesarias y reglas de limpieza

Aparte de las consultas anteriores, que ya son todas directas sobre los archivos, la consulta `3_7a_viajes_utilizables.sql` evalúa unas reglas de limpieza candidatas para saber cuánto descartarían: pickup entre enero y agosto de 2026, duración entre 1 minuto y 6 horas, distancia mayor a 0 y hasta 100 millas, y total mayor a 0.

| Tipo | Viajes | Utilizables | Descartados | % descartado |
|---|---|---|---|---|
| yellow | 29,703,355 | 28,146,188 | 1,557,167 | 5.24% |
| green | 337,114 | 319,257 | 17,857 | 5.30% |

En ambos tipos se pierde poco más del 5%, y las reglas que más descartan son las de distancia (953,454 amarillos con distancia fuera de rango, casi todos con distancia cero) y duración (688,477), mientras que la de fecha casi no afecta (17 amarillos y 14 verdes). Que el porcentaje sea casi igual en los dos tipos nos hace pensar que las reglas están atrapando el mismo tipo de ruido y no algo propio de un solo servicio. Con esto tomamos tres decisiones para el análisis exploratorio. Primero, los análisis de distancia, duración y tarifa los haremos con estos filtros, citando siempre cuántas filas se descartaron. Segundo, los viajes con nulos de pasajeros y `payment_type` 0 o nulo no se eliminarán de los análisis generales, solo se excluirán de las medidas que dependen de esas columnas. Tercero, los montos negativos se analizarán por separado dentro del tema de pagos y se excluyen de los promedios de tarifa.

## 3.9 Qué significa consultar directamente un archivo Parquet

Consultar directamente un archivo Parquet significa que DuckDB lee el archivo en el momento de la consulta, sin que antes se haya cargado ninguno de sus datos a una tabla, y lo que hace en lugar de copiar todo es leer lo que necesita. Parquet guarda los datos por columnas y no por filas, y al final de cada archivo deja un pie de página con el esquema, el número de filas y estadísticas por grupo de filas, entonces una consulta que solo pide dos columnas de las veintitantas que tiene el archivo solamente lee esas dos, y una que solo cuenta filas ni siquiera necesita leer los datos, como vimos en `3_2b`, donde el total sale únicamente de la metadata. Además, DuckDB puede usar las estadísticas de mínimos y máximos de cada grupo para saltarse los que no cumplen un filtro, y puede leer en paralelo los grupos de filas, que en nuestros amarillos son cuatro por archivo.

Cuando el volumen es grande esta estrategia nos pareció útil por varias razones. No hay un paso de importación que repetir cada vez que llega un archivo nuevo, y basta con dejar el archivo en la carpeta para que el glob lo incluya, que es justamente lo que necesita un proceso donde los datos crecen cada mes. Tampoco se duplica el almacenamiento, porque los 496 MB de Parquet son la única copia, y la lectura selectiva evita cargar en memoria los 30 millones de filas, que con la herramienta equivocada no cabrían cómodas. También nos sirvió para explorar, ya que pudimos contar archivos, filas y columnas en décimas de segundo antes de decidir qué analizar. Lo que todavía nos queda por medir es el costo, porque cada consulta que lee columnas completas vuelve a leer y descomprimir los archivos desde disco, y en esta exploración vimos que una consulta que recorre todo el archivo, como la muestra amarilla, tardó unos 9 segundos frente a las décimas de segundo de las que solo usan la metadata. Esa comparación, hecha con más cuidado y contra una tabla materializada, es justo lo que haremos en el ejercicio 6.
