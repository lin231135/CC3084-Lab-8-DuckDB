# Ejercicio 2: sistema de descarga de datos

## Análisis del script original

Antes de tocar nada leímos `scripts/download_data.py` completo y corrimos `--help`, y lo que más nos llamó la atención es que el script del docente ya resolvía bastante bien la parte difícil, porque no supone qué meses existen sino que le pregunta al servidor con una petición HEAD a la URL de cada archivo, descarga sobre un archivo temporal con sufijo `.part` y solo lo renombra al terminar, y reintenta tres veces antes de rendirse. Lo que sí vimos como limitaciones, y por eso lo modificamos, fueron cuatro cosas. La primera es que el año estaba fijo en una constante (`ANIO = 2026`), así que no había forma de pedir 2024 o 2025 sin editar el código. La segunda es que cualquier error de la petición HEAD, incluso una caída de red, se interpretaba como "mes no publicado", de modo que un problema de conexión podía hacerle creer al script que ya había terminado cuando en realidad no había descargado nada. La tercera es que un archivo existente se daba por bueno con solo tener tamaño mayor a cero, entonces uno truncado por cualquier otra vía (una copia a medias, un disco lleno) nunca se detectaba. La cuarta es que no había ninguna verificación de completitud al final, o sea que el script decía "listo" sin comprobar que lo descargado se pudiera leer.

## Qué cambiamos

Parametrizamos el script con `--years`, que acepta uno o varios años (por defecto sigue siendo 2026), y lo dejamos así desde ahora para no tener que volver a modificarlo cuando incorporemos 2024 y 2025 en los ejercicios 5 y 8. Para distinguir bien los casos, la consulta al servidor ahora trata un 403 o un 404 como "aún no publicado" (la TLC responde 403 para los meses que no existen en CloudFront, lo comprobamos a mano con `curl -I`) y cualquier otro error lo reporta como fallo, sin confundirlo con un mes inexistente.

La validación de archivos fue el cambio de fondo. Un archivo local solo se considera bueno si su tamaño coincide exactamente con el `Content-Length` que publica el servidor y además el pie de página Parquet se puede leer con `pyarrow`, que es lo que de verdad indica que el archivo no está truncado. Si no cumple, el script lo vuelve a descargar, y si cumple no lo toca. La misma validación se aplica al archivo recién descargado antes de renombrarlo desde `.part`, por lo que un `.parquet` en `data/raw` nunca debería estar incompleto. También agregamos `--verify-only`, que revisa todo contra el servidor sin descargar nada y devuelve código de salida distinto de cero si falta algo, algo que nos pareció útil para comprobar el estado sin riesgo de gastar ancho de banda.

## 2.7 Cómo sabemos que la descarga está completa

Lo que consideramos completo es que, para cada tipo de taxi y cada año, la cantidad de meses que el servidor tiene publicados sea igual a la cantidad de archivos que están en disco, tienen el tamaño exacto del servidor y se pueden abrir. El script hace esa comparación solo al terminar y la imprime, y el código de salida es cero únicamente si todo coincide. Esto responde también a cómo sabemos qué meses publicó la TLC: no lo sabemos de antemano ni lo escribimos a mano, sino que se lo preguntamos al servidor en cada corrida, así que volver a ejecutar el script más adelante recoge solos los meses que vayan apareciendo.

Al momento de nuestra descarga (12 de octubre de 2026) la TLC tenía publicados de enero a agosto de 2026 tanto para taxis amarillos como verdes, y septiembre, octubre, noviembre y diciembre respondieron 403. El resultado de la primera corrida fue este.

| Tipo | Año | Meses publicados | Archivos legibles en disco | Estado |
|---|---|---|---|---|
| yellow | 2026 | 8 (01 a 08) | 8 | OK |
| green | 2026 | 8 (01 a 08) | 8 | OK |

Se descargaron 16 archivos y no hubo ninguno fallido. En total ocupan 496 MB en `data/raw`. Para comprobar además que el contenido se lee, contamos filas con DuckDB directamente sobre los Parquet, y obtuvimos 29,703,355 viajes de taxis amarillos y 337,114 de verdes, es decir 30,040,469 en total, repartidos así por mes.

| Mes | Viajes (amarillos y verdes) |
|---|---|
| 2026-01 | 3,765,161 |
| 2026-02 | 3,437,239 |
| 2026-03 | 3,996,659 |
| 2026-04 | 3,875,478 |
| 2026-05 | 4,135,757 |
| 2026-06 | 3,881,411 |
| 2026-07 | 3,571,361 |
| 2026-08 | 3,377,403 |

## Pruebas del comportamiento

Probamos las tres propiedades que nos importaban en lugar de asumirlas. Al ejecutar el script una segunda vez, sin cambiar nada, reportó 0 descargados y 16 archivos que ya existían, así que no vuelve a bajar lo que ya tiene. Para el caso de un archivo dañado, truncamos a 500 KB el Parquet de taxis verdes de agosto, ejecutamos el script y este detectó que no coincidía con el servidor, lo volvió a descargar (1 redescargado, 7 omitidos) y el archivo resultante quedó idéntico byte a byte al original que habíamos respaldado. Por último, `--verify-only` confirmó que ambos tipos quedaron con 8 de 8 meses legibles sin descargar nada.

Algo que nos deja pensando es que esta verificación depende de que el servidor responda, entonces si la TLC está caída el script no puede decir nada sobre completitud, y por eso reporta esos meses como fallo en lugar de darlos por inexistentes. Nos parece más seguro que falle ruidosamente a que concluya en silencio que ya no hay nada más que bajar.

## Efecto sobre las comparaciones entre años

Como 2026 solo llega hasta agosto, cuando incorporemos 2024 y 2025 (que sí están completos) no podremos comparar totales anuales sin más, porque estaríamos comparando 8 meses contra 12. Decidimos que las comparaciones entre años se harán sobre los mismos meses (enero a agosto de cada año) o con promedios mensuales, y lo dejaremos explícito en cada análisis donde aplique.
