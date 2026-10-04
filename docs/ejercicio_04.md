# Ejercicio 4: análisis exploratorio con DuckDB

## Cómo trabajamos y qué datos usamos

Este análisis se hizo sobre los 16 archivos de 2026 (enero a agosto, amarillos y verdes), que eran los únicos datos disponibles en ese momento del laboratorio, y las consultas están en `sql/ejercicio_04/`, una por archivo, con el notebook `notebooks/ejercicio_04_analisis_exploratorio.ipynb` leyéndolas desde ahí. Las consultas leen los Parquet directamente a través de la vista `viajes` del ejercicio 3 y de dos vistas nuevas que definimos en `00_vistas_apoyo.sql`: `zonas`, que nombra las 265 zonas de la TLC a partir de su tabla pública de zonas (la descarga ahora el script), y `viajes_limpios`, que aplica las reglas de limpieza que evaluamos en la consulta 3.7a, o sea fecha dentro del año del archivo, duración entre 1 minuto y 6 horas, distancia mayor a 0 y hasta 100 millas, y total mayor a 0. Eso deja 28,146,188 viajes amarillos y 319,257 verdes.

Tomamos esa decisión de limpiar por defecto porque en el ejercicio 3 vimos que cerca del 5% de los viajes tienen valores imposibles, y los promedios sobre ellos no significan nada, pero hay una excepción importante: en la pregunta de pagos usamos todos los viajes, porque los totales negativos y el tipo de pago 0 son justamente lo que queremos entender y la limpieza los borra. Una cosa práctica que nos tocó resolver es que los percentiles exactos sobre 28 millones de filas agotaron la memoria del contenedor (unos 5 GB compartidos con Metabase) cuando pedíamos cada percentil en una llamada separada, porque cada llamada guarda su propia copia de los valores. La solución fue pedir los percentiles como una lista en una sola llamada y limitar DuckDB a 4 hilos y 2 GB, que es lo que hace por defecto `scripts/ejecutar_sql.py`.

## 4.1 Preguntas planteadas y por qué

Partimos de lo que nos dejó pensando el ejercicio 3: unos nulos que afectan a una cuarta parte de los amarillos, montos negativos que son reversiones, y dos servicios (amarillos y verdes) de escala completamente distinta. De ahí salieron doce preguntas agrupadas en los seis ejes que pide el enunciado. Para el comportamiento temporal preguntamos cómo evoluciona el volumen por mes (P1), a qué horas se concentra la demanda (P2) y qué día de la semana tiene más viajes (P3). Para las características de los viajes preguntamos cómo se distribuyen distancia, duración y velocidad (P4), cuántos pasajeros viajan (P5), de qué zonas salen más viajes (P6) y cuáles son las rutas más frecuentes (P7). La diferencia entre amarillos y verdes la atacamos de frente en P8, y además atraviesa P2, P3, P5 y P6. Las variables de pago las cubrimos con cómo pagan los pasajeros (P9) y qué tan frecuentes son los recargos (P10), y para la distribución de valores y atípicos usamos P11, sobre el total pagado, y P12, sobre incoherencias entre variables.

## 4.2 a 4.4 Consultas, resultados y explicación

### P1. Volumen por mes (`4_1_viajes_por_mes.sql`)

Pusimos el volumen por día y no solo el total mensual, porque febrero tiene 28 días y los otros 30 o 31, y comparar totales castigaría a febrero sin que signifique nada.

| Tipo | Ene | Feb | Mar | Abr | May | Jun | Jul | Ago |
|---|---|---|---|---|---|---|---|---|
| yellow, viajes por día | 113,093 | 114,328 | 121,015 | 122,119 | 125,824 | 121,150 | 107,593 | 101,731 |
| green, viajes por día | 1,235 | 1,263 | 1,356 | 1,397 | 1,373 | 1,398 | 1,254 | 1,235 |

Los amarillos suben de enero a mayo, de 113 mil a casi 126 mil viajes diarios, y después caen hasta 101,731 en agosto, que es el mes más bajo de los ocho, así que el volumen no es plano y tiene una forma de campana con el máximo en mayo. Los verdes siguen una forma parecida pero más suave, con el máximo en junio. Lo que nos parece interesante es que la caída de julio y agosto coincide en los dos tipos, lo que sugiere un efecto de temporada (vacaciones de verano) y no algo propio de un servicio, aunque con un solo año no podemos separarlo de otras causas, y por eso este patrón lo retomamos en el ejercicio 8 cuando haya tres años para comparar.

### P2. Demanda por hora (`4_2_demanda_por_hora.sql` y `4_2b_horas_pico.sql`)

La curva completa está en el notebook, con una gráfica de la proporción de viajes de cada tipo por hora, separando entre semana y fin de semana. Las tres horas más pesadas de cada combinación son estas.

| Tipo | Tipo de día | Hora 1 (% de viajes) | Hora 2 | Hora 3 |
|---|---|---|---|---|
| yellow | entre semana | 18 h (6.61%) | 21 h (6.51%) | 17 h (6.38%) |
| yellow | fin de semana | 18 h (6.21%) | 17 h (5.96%) | 0 h (5.85%) |
| green | entre semana | 17 h (8.06%) | 16 h (7.63%) | 18 h (7.36%) |
| green | fin de semana | 18 h (7.34%) | 16 h (7.30%) | 15 h (7.23%) |

Los amarillos entre semana tienen un segundo pico a las 21 h, que los verdes no tienen, y los amarillos de fin de semana tienen a medianoche una de sus tres horas más fuertes, algo que no pasa con los verdes. Nos parece que eso apunta a que los amarillos atienden más vida nocturna y los verdes son un servicio más de tarde, con su máximo entre las 15 y las 18 h tanto en días de semana como en fin de semana, y la curva verde está más concentrada en esas horas, porque su hora más fuerte pesa 8.06% de los viajes entre semana contra 6.61% en los amarillos.

### P3. Día de la semana (`4_3_dia_de_semana.sql`)

| Tipo | Lun | Mar | Mié | Jue | Vie | Sáb | Dom |
|---|---|---|---|---|---|---|---|
| yellow, viajes por fecha | 95,561 | 112,842 | 120,267 | 127,047 | 120,272 | 128,250 | 106,598 |
| green, viajes por fecha | 1,304 | 1,423 | 1,477 | 1,511 | 1,368 | 1,090 | 1,031 |

Esta fue la comparación que más nos sorprendió, porque los dos tipos se comportan al revés en el fin de semana: los amarillos tienen el sábado como su día más fuerte (128,250 viajes por fecha) y el lunes como el más débil (95,561), mientras que los verdes tienen el jueves como el más fuerte y caen cerca de 30% el sábado y el domingo. Creemos que esto es lo que diferencia a los dos servicios, con los verdes comportándose como transporte cotidiano de los barrios, que baja cuando la gente no va a trabajar, y los amarillos como un servicio que también vive de la salida de fin de semana y de la vida nocturna.

### P4. Distancia, duración y velocidad (`4_4_distribucion_distancia_duracion.sql`)

| Tipo | Variable | Promedio | P10 | Mediana | P90 | P99 | Máximo |
|---|---|---|---|---|---|---|---|
| yellow | distancia (millas) | 3.53 | 0.70 | 1.94 | 8.70 | 19.57 | 100.00 |
| green | distancia (millas) | 3.38 | 0.89 | 2.16 | 7.55 | 17.76 | 94.10 |
| yellow | duración (min) | 17.74 | 5.45 | 14.15 | 33.50 | 71.35 | 360.00 |
| green | duración (min) | 17.42 | 5.88 | 13.42 | 32.78 | 75.15 | 359.33 |
| yellow | velocidad (mph) | 10.88 | 4.99 | 9.28 | 18.99 | 34.12 | 2,852.57 |
| green | velocidad (mph) | 11.37 | 6.29 | 10.04 | 18.14 | 31.15 | 1,904.52 |

El promedio de distancia de los amarillos (3.53 millas) está bastante por encima de su mediana (1.94), un 82% más, y eso es la huella de una cola larga de viajes al aeropuerto y a las afueras, así que para describir un viaje típico usamos la mediana, que es menos de 2 millas y unos 14 minutos. Una velocidad mediana de 9.28 mph nos parece coherente con el tráfico de Manhattan. Lo que sí delata un problema de datos es la velocidad máxima, de 2,852 mph, que sobrevivió a las reglas de limpieza y que retomamos en P12, y también notamos que la mediana de distancia de los verdes es mayor que la de los amarillos (2.16 contra 1.94), algo que nos parece razonable porque los verdes salen de zonas menos densas, donde los destinos quedan más lejos.

### P5. Pasajeros (`4_5_pasajeros.sql`)

| Pasajeros | Amarillos (%) | Verdes (%) |
|---|---|---|
| 1 | 82.30 | 82.88 |
| 2 | 12.29 | 9.94 |
| 3 | 2.77 | 1.11 |
| 4 | 1.81 | 0.77 |
| 5 | 0.26 | 2.23 |
| 6 | 0.16 | 1.54 |
| 0 | 0.41 | 1.51 |

Calculamos los porcentajes solo sobre los viajes que sí tienen número de pasajeros, que excluye el 26% de amarillos y el 14.5% de verdes con nulos, y en eso hay que ser cuidadosos porque esos nulos no son aleatorios (son los viajes de tarifa flexible que vimos en el ejercicio 3). Más de 8 de cada 10 viajes son de una sola persona en ambos tipos. La diferencia está en las colas, porque los verdes tienen 3.8% de viajes con 5 o 6 pasajeros contra 0.4% en amarillos, que nos parece un rasgo de cómo se usan, con más viajes familiares o en grupo en los barrios, aunque es una conjetura porque los datos no dicen por qué.

### P6. Zonas y barrios de origen (`4_6a_zonas_origen_top.sql` y `4_6b_barrio_origen.sql`)

| Posición | Amarillos | % | Verdes | % |
|---|---|---|---|---|
| 1 | Upper East Side South | 4.44 | East Harlem North | 27.19 |
| 2 | Midtown Center | 4.16 | East Harlem South | 13.06 |
| 3 | JFK Airport | 3.95 | Forest Hills | 4.88 |
| 4 | Upper East Side North | 3.95 | Central Park | 4.06 |
| 5 | Penn Station/Madison Sq West | 3.08 | Morningside Heights | 3.89 |

| Barrio | Amarillos (%) | Verdes (%) |
|---|---|---|
| Manhattan | 86.74 | 59.86 |
| Queens | 8.75 | 21.81 |
| Brooklyn | 3.60 | 15.72 |
| Bronx | 0.77 | 2.46 |

Este es el contraste geográfico más fuerte que encontramos. Los amarillos están repartidos, con la primera zona pesando apenas 4.44% del total, mientras que en los verdes dos zonas contiguas de East Harlem concentran el 40.25% de todos los viajes (27.19% más 13.06%). A nivel de barrio, 86.7% de los amarillos sale de Manhattan contra 59.9% de los verdes, que tienen una presencia mucho mayor en Queens y Brooklyn. Que JFK sea la tercera zona de los amarillos con 1.1 millones de viajes confirma que los aeropuertos pesan bastante en ese servicio.

### P7. Rutas más frecuentes (`4_12_rutas_frecuentes.sql`)

La ruta más frecuente de los amarillos es de Upper East Side South a Upper East Side North, con 180,487 viajes y una mediana de 1.00 milla y 15.48 dólares, y las cinco primeras son todas locales, de menos de dos millas. En verdes pasa lo mismo a menor escala, con East Harlem North a East Harlem South como primera (13,915 viajes, mediana 1.38 millas). Nos llamó la atención que los viajes más repetidos no son los largos sino los cortos dentro del mismo vecindario, lo cual encaja con la mediana de distancia de menos de 2 millas de P4, y que en ambas listas aparecen también viajes con el mismo origen y destino.

### P8. Amarillos contra verdes (`4_7_amarillos_vs_verdes.sql`)

| Medida | Amarillos | Verdes |
|---|---|---|
| Viajes limpios | 28,146,188 | 319,257 |
| Mediana de distancia (millas) | 1.94 | 2.16 |
| Mediana de duración (min) | 14.2 | 13.4 |
| Mediana de tarifa del taxímetro | 15.60 | 13.50 |
| Mediana del total pagado | 23.58 | 20.52 |
| Pagos con tarjeta (%) | 65.4 | 65.7 |
| Viajes con propina entre los de tarjeta (%) | 91.1 | 91.7 |
| Mediana de propina sobre la tarifa (%) | 26.4 | 23.6 |

Lo que nos deja pensando es que los amarillos recorren una distancia mediana menor que los verdes (1.94 contra 2.16 millas) y aun así su tarifa mediana es más alta (15.60 contra 13.50 dólares) y su total también (23.58 contra 20.52). Nuestra hipótesis es que el taxímetro de Manhattan cobra más por milla en tráfico lento y que los amarillos pagan más recargos, algo que respaldan los datos de P10, pero con estas consultas no podemos separar cuánto viene de cada causa. En cuanto a hábitos de pago los dos tipos son casi idénticos: dos de cada tres viajes son con tarjeta y más del 91% de esos deja propina, aunque la propina mediana es un poco mayor en amarillos (26.4% de la tarifa contra 23.6%).

### P9. Pagos (`4_8_pagos.sql`)

Esta consulta usa todos los viajes y no solo los limpios.

| Tipo | Método | Viajes | % del tipo | Total promedio | Propina promedio | % con propina |
|---|---|---|---|---|---|---|
| yellow | tarjeta | 18,941,008 | 63.77 | 30.18 | 4.28 | 91.1 |
| yellow | Flex Fare (0) | 7,716,688 | 25.98 | 32.57 | 0.40 | 8.1 |
| yellow | efectivo | 2,708,031 | 9.12 | 25.17 | 0.00 | 0.0 |
| yellow | disputa | 239,488 | 0.81 | 3.47 | 0.00 | 0.0 |
| green | tarjeta | 219,980 | 65.25 | 25.84 | 3.84 | 90.4 |
| green | efectivo | 65,921 | 19.55 | 21.25 | 0.00 | 0.0 |
| green | nulo (Flex Fare) | 48,775 | 14.47 | 30.67 | 0.79 | 16.1 |

Efectivo muestra propina cero en el 100% de los viajes, y eso no significa que nadie deje propina en efectivo sino que el taxímetro no la registra, así que cualquier análisis de propinas tiene que restringirse a tarjeta, como hicimos en P8. Lo que más pesa es el Flex Fare, que es más del 25% de los amarillos y tiene un total promedio más alto que el de tarjeta (32.57 contra 30.18) con una propina casi inexistente, lo cual nos hace pensar que es otro tipo de operación donde la propina se maneja fuera del taxímetro.

### P10. Recargos (`4_9_recargos.sql`)

El cargo de congestión de Manhattan (`cbd_congestion_fee`) siempre es de 0.75 dólares cuando se cobra, y lo que cambia es en qué proporción de viajes aparece. En amarillos va de 71.0% de los viajes en enero a 77.3% en julio y agosto, con una caída puntual en mayo (66.8%), y en verdes es mucho menor, entre 7.1% y 9.8%. El recargo de aeropuerto (`Airport_fee`, solo en amarillos) está entre 5.9% y 7.3% de los viajes y tiende a subir hacia agosto, y el recargo de congestión clásico (`congestion_surcharge`) está entre 63% y 71% de los amarillos y entre 26% y 30% de los verdes. El detalle por mes está en el notebook. Lo que notamos es que alrededor de siete de cada diez viajes amarillos pagan el cargo del centro, contra menos de uno de cada diez en verdes, lo que creemos que explica parte de por qué su total es más alto aunque recorran menos, y que ese cargo se vuelve más frecuente con el tiempo, algo a mirar con los tres años en el ejercicio 8.

### P11. Distribución del total y valores atípicos (`4_10_distribucion_monto_atipicos.sql`)

| Tipo | Q1 | Mediana | Q3 | P99 | Límite atípico | Viajes atípicos (%) | Ingreso de los atípicos (%) | Promedio | Máximo |
|---|---|---|---|---|---|---|---|---|---|
| yellow | 17.53 | 23.58 | 34.45 | 104.76 | 59.83 | 8.47 | 24.18 | 30.18 | 1,065.72 |
| green | 15.19 | 20.52 | 29.70 | 94.75 | 51.47 | 6.53 | 19.21 | 25.42 | 668.80 |

Con la regla del rango intercuartil, 8.47% de los viajes amarillos supera los 59.83 dólares y aun así aporta el 24.18% de todo el ingreso, es decir que casi uno de cada cuatro dólares viene de uno de cada doce viajes, y en verdes la relación es parecida (6.53% de los viajes y 19.21% del ingreso). Creemos que esos viajes caros no son errores sino sobre todo viajes largos o a aeropuertos, aunque no lo verificamos zona por zona, y son lo que le da la cola a la distribución, por lo que el promedio (30.18) queda 6.6 dólares por encima de la mediana (23.58). A diferencia de los casos de P12, aquí no los descartamos, pero sí decidimos reportar la mediana junto al promedio.

### P12. Incoherencias entre variables (`4_11_inconsistencias_velocidad_y_tarifa.sql`)

| Tipo | Viajes | Velocidad mayor a 80 mph | Velocidad menor a 1 mph | Tarifa mayor a 50 dólares por milla | Propina mayor que la tarifa | Propina mayor a 100 |
|---|---|---|---|---|---|---|
| yellow | 28,146,188 | 4,228 | 171,849 | 233,063 | 27,626 | 83 |
| green | 319,257 | 90 | 725 | 1,416 | 523 | 23 |

Estas son filas que ya pasaron las reglas de limpieza y siguen siendo sospechosas. La más clara es la velocidad, porque hay 4,228 viajes amarillos a más de 80 mph, con un máximo de 2,852 mph, que por sí solos son una fracción mínima (0.015%) pero muestran que filtrar distancia y duración por separado no basta. En el otro extremo hay 171,849 viajes (0.61%) a menos de 1 mph, que probablemente son viajes con el taxímetro corriendo en una espera o una detención larga. Hay también 233,063 viajes amarillos con tarifa de más de 50 dólares por milla, que se explican en parte por viajes muy cortos donde el cargo mínimo domina, y 27,626 con propina mayor a la tarifa, que no necesariamente son errores. Decidimos no sumar más reglas de limpieza al análisis por estos casos, porque cada una es menos del 1% y no cambia las medianas, pero los dejamos documentados para tener cuidado con promedios y máximos.

## 4.5 Hallazgos relevantes

El primero es que los taxis amarillos y verdes no son versiones grandes y pequeñas del mismo servicio sino dos servicios distintos. Los verdes tienen el 40% de sus viajes en dos zonas contiguas de East Harlem, su día más fuerte es el jueves y caen cerca de 30% el fin de semana, mientras que los amarillos se reparten por todo Manhattan y tienen su día más fuerte el sábado. Comparar solo promedios generales entre los dos oculta eso, por lo que en el resto del laboratorio vamos a comparar por separado y en proporciones.

El segundo es que una cuarta parte de los amarillos (25.98%) y el 14.47% de los verdes son viajes de tarifa flexible, sin número de pasajeros y con propina casi inexistente, que se comportan distinto al resto en todo lo que miden. Cualquier indicador de pasajeros, propinas o tipo de pago que ignore esa categoría estaría describiendo apenas tres cuartas partes de los viajes sin avisarlo, y por eso en el tablero del ejercicio 7 la tratamos como una categoría explícita.

El tercero es que el ingreso depende mucho de una cola de viajes caros, con 8.47% de los viajes amarillos generando 24.18% del ingreso, y que el cargo de congestión del centro está creciendo, de 71.0% a 77.3% de los viajes entre enero y agosto. Esto significa que el total pagado por viaje no se puede explicar solo con distancia y duración, y que cualquier comparación entre años tendrá que considerar que los recargos cambian con el tiempo.

## Qué decidimos a partir de estos resultados

Para los indicadores de los ejercicios siguientes vamos a usar medianas junto a promedios, vamos a separar siempre amarillos y verdes y a comparar en proporciones, vamos a tratar el Flex Fare como categoría propia, y vamos a restringir los análisis de propina a pagos con tarjeta. Los resultados de este ejercicio corresponden a 2026, y cuando se incorporó 2024 en el ejercicio 5 comprobamos que estas catorce consultas dan exactamente los mismos resultados al restringirlas a ese año, como se explica en `docs/ejercicio_05.md`.
