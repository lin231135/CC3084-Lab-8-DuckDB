# Ejercicio 1: ambiente y estructura del proyecto

## Cómo incorporamos el repositorio base

El enunciado pide trabajar sobre un fork de <https://github.com/menene/duckdb>, pero nosotros ya habíamos creado nuestro propio repositorio y su enlace ya estaba entregado, así que no hicimos fork y en su lugar incorporamos el contenido del repositorio del docente dentro del nuestro, respetando la estructura original (`data/raw`, `data/processed`, `notebooks`, `scripts`, `sql`, `docs`, los dos Dockerfiles, `docker-compose.yml`, `requirements.txt` y el README). Lo que sí nos parece importante dejar claro es que todo lo que se construyó después de ese punto es trabajo del equipo, y que el repositorio del docente solo lo usamos como punto de partida.

## Qué levanta realmente el ambiente

Revisamos el `docker-compose.yml` antes de asumir nada y vimos que define dos servicios, no uno. El primero es `lab`, construido con el `Dockerfile` sobre `python:3.11.14-slim`, que corre JupyterLab en el puerto 8888 sin token ni contraseña y solo está expuesto en `127.0.0.1`, lo cual tiene sentido porque nadie más en la red debería poder llegar a un Jupyter sin autenticación. El segundo es `metabase`, construido con `metabase.Dockerfile` sobre `eclipse-temurin:21-jre-jammy`, con el jar de Metabase v0.63.19 y el driver de DuckDB 1.5.5.0 ya instalados en la carpeta de plugins, expuesto en el puerto 3000. Que la imagen esté basada en Debian y no en Alpine no es capricho, porque el driver de DuckDB trae una librería nativa que necesita glibc.

Las dos cosas que más nos llamaron la atención al leer la configuración son el montaje de volúmenes y el versionado. Ambos contenedores montan `./data` en `/workspace/data`, así que lo que descarguemos desde Jupyter lo ve Metabase sin copiar nada, y el contenedor `lab` además monta `notebooks`, `scripts`, `sql` y `docs`, de modo que lo que editamos dentro del contenedor queda directamente en el repositorio. Por otro lado, la versión de `duckdb` en `requirements.txt` (1.5.5) tiene que coincidir con la del driver de Metabase, o sea que si alguien la sube por su cuenta puede romper la conexión del tablero sin que sea obvio por qué.

## Verificación de que el ambiente levanta

Ejecutamos `docker compose up --build -d` desde la raíz del repositorio y esperamos a que ambos servicios respondieran. El resultado fue el siguiente.

| Servicio | Contenedor | Puerto | Verificación | Resultado |
|---|---|---|---|---|
| JupyterLab | `lab8-lab` | 8888 | `GET http://127.0.0.1:8888/lab` | HTTP 200 |
| Metabase | `lab8-metabase` | 3000 | `GET http://127.0.0.1:3000/api/health` | `{"status":"ok"}` |

Metabase tardó claramente más que Jupyter en quedar listo, porque la primera vez inicializa su base interna, así que si alguien intenta entrar a los pocos segundos y ve un error no significa que algo esté mal.

## Inventario de herramientas dentro del ambiente

Para no dar por hecho qué hay disponible, entramos a los contenedores con `docker exec` y consultamos las versiones instaladas.

| Contenedor | Herramienta | Versión |
|---|---|---|
| `lab8-lab` | Python | 3.11.14 |
| `lab8-lab` | duckdb | 1.5.5 |
| `lab8-lab` | jupyterlab | 4.6.4 |
| `lab8-lab` | pandas | 3.0.6 |
| `lab8-lab` | pyarrow | 25.0.1 |
| `lab8-lab` | matplotlib | 3.11.2 |
| `lab8-lab` | requests | 2.34.2 |
| `lab8-lab` | curl | disponible (`/usr/bin/curl`) |
| `lab8-metabase` | Java (OpenJDK) | 21.0.12.1 |
| `lab8-metabase` | Driver DuckDB para Metabase | `duckdb.metabase-driver.jar` en `/home/metabase/plugins` |

Comprobamos además que DuckDB funciona de verdad dentro del contenedor y no solo que el paquete esté instalado, ejecutando `import duckdb; duckdb.sql("select 42")` y obteniendo `[(42,)]`. Algo que notamos es que el contenedor `lab` no trae `git`, así que todo lo de control de versiones lo hacemos desde la máquina local y no desde dentro de Jupyter.

## Propósito de cada directorio

Los directorios `data/raw` y `data/processed` están separados por una razón de fondo. En `data/raw` guardamos los Parquet tal como los publica la TLC, organizados como `data/raw/<tipo>/<anio>/`, y no los modificamos nunca, porque esa es la fuente de verdad y si algo sale mal siempre podemos volver a ella. En `data/processed` va todo lo que derivamos nosotros, que en este laboratorio es principalmente la base `.duckdb` materializada del Ejercicio 6. Ninguno de los dos se sube a Git, y lo único que se versiona dentro de ellos son los archivos `.gitkeep` que mantienen la carpeta.

El directorio `sql` guarda las consultas en archivos `.sql`, organizadas por ejercicio, con la idea de que cada consulta exista en un solo lugar y que los notebooks y los documentos la referencien en lugar de copiarla. En `notebooks` van los notebooks de Jupyter donde ejecutamos y mostramos esas consultas, en `scripts` el código que se corre desde la terminal (la descarga de datos y los benchmarks), y en `docs` la documentación de cada ejercicio y las capturas del tablero. En la raíz quedan el `Dockerfile`, el `metabase.Dockerfile` y el `docker-compose.yml`, que definen el ambiente, y el `README.md`, que es la guía de reproducción.

## 1.6 Por qué importa un ambiente reproducible

Lo que más se nos quedó dando vueltas es que en este laboratorio hay varias piezas que dependen unas de otras de una forma bastante frágil, y el ambiente en Docker es lo que evita que eso se vuelva un dolor de cabeza. DuckDB, pyarrow y pandas cambian su comportamiento entre versiones (por ejemplo en cómo se infieren los tipos al leer Parquet), y el driver de Metabase tiene que estar alineado con la versión de DuckDB, así que si cada integrante usara su propia instalación local los resultados y los tiempos del benchmark podrían no ser comparables, y una consulta que funciona en una máquina podría fallar en otra sin que nadie sepa por qué. Con versiones fijadas en `requirements.txt` y en los Dockerfiles, una persona que nunca participó en el proyecto puede clonar el repositorio, correr `docker compose up --build` y estar en las mismas condiciones en las que trabajamos nosotros, que es justamente lo que se le pide al README final.

Los benchmarks son el caso donde más se nota, porque comparar Parquet contra una tabla materializada solo tiene sentido si las dos mediciones salen del mismo motor, con la misma versión y con los mismos recursos, y de nada sirve un número de tiempo si nadie puede repetir la condición que lo produjo. Además, que los datos se monten como volumen desde `./data` y no se copien dentro de la imagen nos deja reconstruir el ambiente cuando queramos sin volver a descargar más de 1.5 GB, lo cual es una ventaja práctica enorme. La parte que todavía nos deja pensando es hasta dónde llega realmente la reproducibilidad, porque el ambiente está fijado pero los datos de 2026 no, ya que la TLC sigue publicando meses nuevos, así que dos personas que descarguen en fechas distintas van a tener conjuntos distintos y tendremos que documentar con cuidado qué meses había al momento de cada descarga.
