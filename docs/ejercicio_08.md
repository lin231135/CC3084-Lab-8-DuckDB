# Ejercicio 8: los tres años juntos

## 8.1 y 8.2 Incorporación de 2025 sin descargar de nuevo lo que ya teníamos

Igual que con 2024, incorporar 2025 no requirió cambiar el código de descarga sino ejecutarlo con otro valor del parámetro `--years`.

```bash
docker exec lab8-lab python scripts/download_data.py --years 2024 2025 2026
```

La corrida descargó 24 archivos (12 de amarillos y 12 de verdes de 2025), omitió los 40 que ya existían y eran válidos (los de 2024 y 2026), y no hubo ni redescargas ni fallos. La verificación de completitud dio 12 de 12 meses para 2025 en los dos tipos, y los de 2026 siguieron en 8 de 8. Para comprobar el punto 8.2 ejecutamos el mismo comando una segunda vez, y reportó 0 descargados y 64 archivos existentes. Los Parquet de 2025 suman unos 805 MB, con lo que los tres años ocupan 1,977 MB.

Antes de consultar revisamos el esquema, que es lo que puede romper las consultas, y 2025 es compatible con lo que ya teníamos: ninguna columna cambia de nombre ni de tipo entre los tres años. La única novedad es que `cbd_congestion_fee` aparece en los 12 meses de 2025 (en 2024 no existe y en 2026 ya estaba), lo cual encaja con que ese cargo empezó el 5 de enero de 2025 según el diccionario de la TLC. Con 2025 la tabla suma 121,184,384 viajes, de los cuales 48,722,602 son amarillos y 591,375 verdes de 2025.

## 8.3 Las consultas anteriores siguen funcionando

Ejecutamos con `scripts/ejecutar_sql.py` las 36 consultas de los ejercicios 3, 4 y 5 sobre los tres años juntos (17 más 14 más 5), y ninguna falló. Lo que comprobamos además, y nos parece lo más importante, es que restringidas a 2026 con `--anios 2026` las consultas del ejercicio 4 dan exactamente los mismos resultados que antes de incorporar 2024 y 2025, y las del ejercicio 3 también, con la sola excepción del nombre de una columna que renombramos en el ejercicio 5. O sea que sumar datos no cambió lo ya documentado, y los números de los ejercicios 3 y 4 siguen siendo reproducibles. Los notebooks de esos dos ejercicios fijan `anios = [2026]` por eso. El notebook del ejercicio 5 conserva los resultados que tenía cuando solo había 2024 y 2026, y si se vuelve a ejecutar ahora aparecen también las filas de 2025 en las consultas que leen todos los archivos.

Lo que sí cambió es el tiempo. Sumando las 23 consultas de los ejercicios 3 y 4 de las que teníamos medido el tiempo con dos años, pasamos de 383 segundos a 1,405 segundos con tres, es decir 3.7 veces más tiempo para 1.7 veces más datos (de 71.9 a 121.2 millones de filas).

| Consulta | Dos años (s) | Tres años (s) | Razón |
|---|---|---|---|
| `3_6i_calidad_duplicados` | 42.7 | 124.2 | 2.9x |
| `3_6b_calidad_duracion` | 17.7 | 49.7 | 2.8x |
| `4_1_viajes_por_mes` | 14.8 | 28.2 | 1.9x |
| `4_4_distribucion_distancia_duracion` | 54.4 | 206.4 | 3.8x |
| `4_7_amarillos_vs_verdes` | 48.5 | 529.5 | 10.9x |
| `4_12_rutas_frecuentes` | 30.6 | 64.9 | 2.1x |

La mayoría de las consultas tarda entre 1.9 y 3 veces más, pero dos se salen de la tendencia: la de distribuciones (`4_4`) y sobre todo la de comparación entre amarillos y verdes (`4_7`), que pasó de 48 segundos a casi 9 minutos. Ambas calculan varios percentiles exactos sobre la vista que lee los Parquet, y la segunda calcula cinco medianas a la vez. No aislamos la causa, pero lo que vimos en el ejercicio 6 nos da una pista, que es que los cálculos que guardan todos los valores en memoria se vuelven mucho más lentos cuando el volumen se acerca al límite de memoria que le dimos a DuckDB (2 GB), y es probable que eso explique el salto. Aun así, hay que tomar con cuidado esta comparación, porque los tiempos de dos años y de tres los medimos en sesiones distintas y no podemos descartar que parte de la diferencia venga de la caché del sistema operativo.

## 8.4 Indicadores y tablero con los tres años

Los indicadores del ejercicio 7 no tienen ningún año escrito, así que para pasarlos a tres años bastó completar la tabla con `scripts/benchmark_parquet_vs_tabla.py`, que insertó solo los 12 meses de 2025 en 96.7 segundos sin tocar lo existente, volver a ejecutar `scripts/montar_tablero_metabase.py` y regenerar las gráficas. Las 17 preguntas del tablero se ejecutaron en Metabase sin error, y las cifras generales pasaron a 115,042,065 viajes útiles, 3,294.5 millones de dólares de ingreso, un total mediano de 21.9 dólares y 67.3% de pagos con tarjeta.

Algo que nos pasó al actualizar y que nos pareció importante es que con tres años las preguntas de Metabase se volvieron más lentas, hasta 25.7 segundos la más pesada, y la conexión de DuckDB en Metabase tenía solo 1 GB de memoria. Aplicando lo que aprendimos en el ejercicio 6, subimos ese límite a 3 GB (el script ya lo hace) y la misma pregunta bajó a 15.3 segundos, y en general los tiempos bajaron de entre 0.3 y 25.7 s a entre 0.2 y 15.3 s. Son una sola ejecución de cada una, así que lo tomamos como orientación y no como una medición. Al cambiar la memoria hubo que reiniciar Metabase, porque DuckDB no deja abrir el mismo archivo con una configuración distinta mientras haya una conexión abierta.

## 8.5 Evolución de los indicadores en el tiempo

Para comparar años con la misma ventana usamos enero a agosto de cada año, porque 2026 solo llega hasta ahí. Estas son las tres consultas por año (`8_1a`, `8_1b` y `8_1c`).

| Tipo | Año | Viajes por día | Tarifa flexible (%) | Tarjeta (%) | Efectivo (%) | Con cargo de congestión (%) | Descartados (%) |
|---|---|---|---|---|---|---|---|
| yellow | 2024 | 104,479 | 9.5 | 74.1 | 13.9 | sin dato | 3.39 |
| yellow | 2025 | 122,239 | 23.3 | 63.8 | 9.8 | 73.1 | 5.87 |
| yellow | 2026 | 115,828 | 26.0 | 63.8 | 9.1 | 72.5 | 5.24 |
| green | 2024 | 1,691 | 3.9 | 67.9 | 27.2 | sin dato | 6.93 |
| green | 2025 | 1,521 | 7.0 | 69.4 | 22.6 | 10.0 | 7.12 |
| green | 2026 | 1,314 | 14.5 | 65.3 | 19.6 | 8.6 | 5.29 |

| Tipo | Año | Tarifa mediana | Total mediano | Distancia mediana (millas) | Duración mediana (min) | Velocidad mediana (mph) | Propina mediana (% de la tarifa) |
|---|---|---|---|---|---|---|---|
| yellow | 2024 | 13.50 | 21.00 | 1.80 | 12.73 | 9.52 | 25.93 |
| yellow | 2025 | 13.50 | 21.08 | 1.90 | 13.15 | 9.70 | 26.69 |
| yellow | 2026 | 15.60 | 23.58 | 1.94 | 14.15 | 9.28 | 26.41 |
| green | 2024 | 13.50 | 19.15 | 1.98 | 11.95 | 10.37 | 23.49 |
| green | 2025 | 13.50 | 19.85 | 2.04 | 12.50 | 10.29 | 23.49 |
| green | 2026 | 13.50 | 20.52 | 2.16 | 13.42 | 10.04 | 23.63 |

Con años completos también podemos mirar los totales sin recortar meses. De 2024 a 2025 los viajes amarillos pasaron de 41,169,720 a 48,722,602 (18.3% más) y los verdes de 660,218 a 591,375 (10.4% menos).

## 8.6 Cambios y patrones al mirar 2024, 2025 y 2026 juntos

El primer patrón es que 2025 fue el año fuerte de los amarillos y 2026 no sigue esa línea. Entre enero y agosto los viajes por día pasaron de 104,479 en 2024 a 122,239 en 2025 (17.0% más) y bajaron a 115,828 en 2026 (5.2% menos que en 2025). La consulta `8_2` lo confirma mes a mes: cada mes de 2025 tuvo entre 10% y 22% más viajes por día que el mismo mes de 2024, y en 2026, de febrero a agosto, cada mes tuvo entre 2.7% y 10.0% menos que el mismo mes de 2025 (enero de 2026 es la excepción, con 5.8% más, pero el enero de 2025 había sido muy bajo, con 106,882 viajes por día contra 121,840 en febrero). Con solo 2024 y 2026 habíamos concluido que los amarillos crecían un 10%, y con los tres años vemos que esa lectura escondía un máximo en 2025. Los verdes van en dirección contraria y de forma sostenida: 1,691, 1,521 y 1,314 viajes por día, o sea 10.1% menos en 2025 y otro 13.6% menos en 2026, y su participación entre los viajes totales cae de 1.8% en enero de 2024 a 1.1% en enero de 2026.

El segundo patrón es la tarifa flexible, y aquí corregimos algo que habíamos escrito en el ejercicio 7 con dos años. Dijimos que el crecimiento no había sido gradual, y con 2025 vemos que sí lo fue durante todo ese año. En amarillos pasó de 4.7% en enero de 2024 a 15.5% en enero de 2025 y a 28.1% en junio de 2025, y desde entonces se queda en una banda alta, entre 20.9% y 30.1% hasta agosto de 2026, así que la mayor parte del crecimiento ocurrió entre 2024 y mediados de 2025 y después se estabiliza. Lo que más nos llamó la atención es que la proporción de pagos con tarjeta fue exactamente la misma en 2025 y 2026 (63.8% de los viajes amarillos de enero a agosto), o sea que todo lo que cambió fue a costa de otras categorías en 2024 a 2025, cuando la tarjeta bajó de 74.1% a 63.8% y el efectivo de 13.9% a 9.8%. En verdes pasa algo parecido pero más tardío: 3.9%, 7.0% y 14.5%, con el salto principal en el segundo semestre de 2025.

El tercer patrón es un escalón de precios en diciembre de 2025 que solo se ve en los amarillos. El total mediano de los amarillos de enero a agosto fue de 21.00 dólares en 2024 y 21.08 en 2025, prácticamente igual, y subió a 23.58 en 2026, y mes a mes la variación contra el mismo mes del año anterior fue de entre -1.3% y 3.3% hasta noviembre de 2025 y saltó a 11.9% en diciembre, con entre 8.6% y 18.1% en todos los meses de 2026. La tarifa del taxímetro explica el salto y no los recargos: la mediana por milla pasó de unos 7.1 dólares en octubre y noviembre de 2025 a 7.85 en diciembre y siguió entre 7.5 y 7.9 en 2026, mientras que los recargos promedio de los pagos con tarjeta se mantuvieron entre 5.3 y 5.5 dólares. Esto coincide con un cambio en la tarifa de los taxis, pero los datos no dicen cuál fue el motivo, así que no podemos afirmarlo. Los verdes no tienen ese escalón, su total mediano sube de forma gradual (19.15, 19.85 y 20.52) y la variación interanual va de 1.3% a 5.6% en 2025 y se enfría hasta -0.4% en agosto de 2026.

El cuarto patrón es el cargo de congestión, que arranca de inmediato. Aparece en enero de 2025, con 66.1% de los viajes amarillos (el cargo empezó el 5 de enero, así que enero tiene menos días con cargo), y desde febrero de 2025 se mantiene alrededor de 74% durante todo el año, baja a 71% a comienzos de 2026 y vuelve a subir hasta 77.3% en julio y agosto, con una caída puntual en mayo de 2026 (66.8%) que no sabemos explicar. En verdes se cobra a entre 7% y 11% de los viajes. El monto promedio cuando se cobra es siempre 0.75 dólares, aunque entre febrero y septiembre de 2025 hubo meses con un máximo de 1.25 o 1.50 dólares en algunos viajes, que después desaparecen, y no conocemos la razón.

El quinto patrón es el ritmo del tráfico. Después de introducido el cargo, la velocidad mediana de los amarillos subió de 9.52 mph en 2024 a 9.70 en 2025 (1.9% más), y en 2026 bajó a 9.28, por debajo incluso de 2024. Es una lectura distinta a la que teníamos con dos años, cuando solo veíamos que 2026 era más lento que 2024, y ahora vemos que hubo una mejora en 2025 que se perdió. Además los viajes se alargan en el tiempo más de lo que se alargan en distancia: la duración mediana de los amarillos pasa de 12.73 a 13.15 y a 14.15 minutos (11.1% más en dos años) mientras que la distancia pasa de 1.80 a 1.90 y a 1.94 millas (7.8% más). Los verdes son más simples, con una velocidad que baja cada año (10.37, 10.29 y 10.04).

Hay otros cambios más pequeños que vale la pena anotar. La propina mediana con tarjeta es estable (25.9%, 26.7% y 26.4% de la tarifa en amarillos, y 23.5% en verdes en los tres años). La proporción de viajes amarillos que salen de un aeropuerto baja de 7.92% a 6.75% y a 6.48%, y la de verdes es casi nula, de 0.05% a 0.03%. Y los viajes que no pasan las reglas de calidad en amarillos suben de 3.39% a 5.87% de 2024 a 2025 y bajan a 5.24% en 2026, mientras que en verdes van de 6.93% a 7.12% y a 5.29%, lo que confirma que la calidad no se mueve de manera pareja y que conviene medirla por año.

## Qué corregimos de lo que habíamos escrito con dos años

Al tener 2025 encontramos cuatro lecturas del ejercicio 7 que eran incompletas o equivocadas, y las corregimos en ese documento. La primera es que la tarifa flexible no creció de golpe entre 2024 y 2026 sino de forma gradual durante 2025. La segunda es que el salto del total mediano de los amarillos, que atribuíamos a un salto entre años, ocurre en diciembre de 2025 y viene de la tarifa del taxímetro. La tercera es que el crecimiento de 10% de los amarillos entre 2024 y 2026 escondía un máximo en 2025. Y la cuarta es que la velocidad no empeoró de forma continua, sino que mejoró en 2025. Nos parece una buena razón para no sacar conclusiones de tendencia con dos puntos.

## 8.7 Consultas utilizadas

Las consultas nuevas están en `sql/ejercicio_08/` y el notebook `notebooks/ejercicio_08_tres_anios.ipynb` las ejecuta sobre la base `data/processed/taxis.duckdb` y guarda los resultados. Se pueden ejecutar también con `python scripts/ejecutar_sql.py sql/ejercicio_08 --base data/processed/taxis.duckdb`.

| Archivo | Qué responde |
|---|---|
| `8_1a_volumen_y_pagos_por_anio.sql` | Viajes por día, tarifa flexible, tarjeta, efectivo, cargo de congestión y calidad por año |
| `8_1b_precios_por_anio.sql` | Medianas de tarifa, total y distancia por año |
| `8_1c_ritmo_por_anio.sql` | Medianas de duración, velocidad y propina por año |
| `8_2_variacion_interanual.sql` | Variación de viajes y total mediano contra el mismo mes del año anterior |
| `8_3_cargo_congestion.sql` | Cargo de congestión mes a mes desde 2025 |
| `8_4_tarifa_flexible_mensual.sql` | Proporción de tarifa flexible mes a mes en los tres años |
| `8_5_aeropuertos_por_anio.sql` | Viajes desde aeropuertos y recargo de aeropuerto por año |

Las medianas se reparten en dos consultas de tres medianas cada una (`8_1b` y `8_1c`) porque cada mediana exacta guarda sus propios valores en memoria, y creemos que seis juntas sobre 100 millones de filas no caben en 2 GB, el mismo límite que vimos en el ejercicio 6, aunque no lo probamos con estas consultas.
