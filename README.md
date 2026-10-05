# Lab 8 - DuckDB

Repositorio base del laboratorio 8 del curso **CC3084 - Data Science**
(Universidad del Valle de Guatemala, Ciclo 2, 2026).

Este es el repositorio **proporcionado por el docente**. Contiene la estructura
del proyecto, el ambiente de ejecucion basado en Docker y un script que descarga
los datos de **2026**. Todo lo demas debe ser construido por cada equipo.

## Trabajo con fork

El laboratorio se desarrolla y se entrega sobre un **fork** de este repositorio.
No se trabaja directamente sobre el repositorio del docente.

1. Realice un fork de este repositorio:
   <https://github.com/menene/duckdb>

2. Clone **su propio fork** (no el del docente):

   ```bash
   git clone https://github.com/<su-usuario>/duckdb.git
   cd duckdb
   ```

3. Opcional, para recibir correcciones publicadas por el docente:

   ```bash
   git remote add upstream https://github.com/menene/duckdb.git
   git fetch upstream
   ```

Realice commits frecuentes y descriptivos: el historial del repositorio es parte
de la evaluacion. **La entrega del laboratorio es la URL de su fork.**

## Estructura

```text
duckdb/
|
+-- data/
|   +-- raw/
|   +-- processed/
|
+-- notebooks/
|
+-- scripts/
|
+-- sql/
|
+-- docs/
|
+-- Dockerfile
+-- metabase.Dockerfile
+-- docker-compose.yml
+-- README.md
```

## Requisitos

- Docker, con Docker Compose
- Git

La primera construccion del ambiente descarga varios cientos de MB y puede
tardar algunos minutos.

Considere el espacio en disco: las imagenes de Docker ocupan unos 3 GB y los
datos de los tres anios del laboratorio superan 1.5 GB, a los que se suma la
base materializada del Ejercicio 6. Se recomienda tener al menos 10 GB libres.

## Datos

El repositorio incluye `scripts/download_data.py`, que descarga los archivos de
2026 publicados por la TLC (`--help` muestra las opciones disponibles). Los
archivos se guardan en `data/raw/<tipo>/<anio>/`.

La TLC publica cada mes con varias semanas de atraso, por lo que los ultimos
meses de 2026 todavia no existen. El script consulta al servidor que meses estan
publicados, de modo que vuelve a ejecutarse sin problema conforme aparezcan
nuevos archivos.

Los datos descargados **no deben incluirse en el repositorio Git**. El archivo
`.gitignore` ya esta configurado para evitarlo.

Fuente de datos: NYC TLC Trip Record Data
<https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page>

Dentro de los contenedores, la carpeta `data/` del proyecto esta montada en
`/workspace/data`. Esa es la ruta que deben usar las herramientas que corren
dentro del ambiente, no la ruta de su computadora.

> **Nota sobre DuckDB:** un archivo `.duckdb` admite un solo proceso con permiso
> de escritura a la vez. Si conecta una herramienta externa a su base de datos,
> use el modo de solo lectura (`read_only`) en esa conexion; de lo contrario los
> demas procesos no podran abrir el archivo.

## Material a entregar

Al finalizar, su fork debe contener:

- el codigo fuente modificado y los scripts de descarga;
- las consultas SQL desarrolladas;
- el notebook o notebooks utilizados;
- la documentacion de las consultas;
- los scripts utilizados para los benchmarks;
- el codigo de los indicadores y visualizaciones;
- el tablero o la evidencia del tablero desarrollado;
- este `README.md`, completado segun la siguiente seccion.

Los archivos de datos descargados **no** deben incluirse.

---

# Documentacion del equipo

Las siguientes secciones explican como levantar el ambiente, descargar los datos,
ejecutar el analisis, reproducir los benchmarks y generar los resultados principales,
y al final enlazan a la documentacion de cada ejercicio y resumen lo que encontramos.

## Como levantar el ambiente

### Repositorio base

El repositorio base es el del docente (<https://github.com/menene/duckdb>). No
hicimos fork porque el repositorio del equipo ya existia y su enlace ya habia
sido entregado, asi que incorporamos el contenido del repositorio del docente
dentro del nuestro, respetando su estructura. Donde el enunciado dice "clone su
fork", el procedimiento con nuestro repositorio es este:

```bash
git clone https://github.com/lin231135/CC3084-Lab-8-DuckDB.git
cd CC3084-Lab-8-DuckDB
```

### Pasos

1. Abrir Docker Desktop (o iniciar el servicio de Docker) y esperar a que el
   motor este listo (`docker info` debe responder sin errores).
2. Construir y levantar los dos servicios desde la raiz del repositorio:

   ```bash
   docker compose up --build -d
   ```

3. Esperar a que Metabase termine de iniciar (la primera vez tarda uno o dos
   minutos) y verificar:

   ```bash
   docker compose ps
   curl http://127.0.0.1:3000/api/health   # {"status":"ok"}
   ```

4. Abrir los servicios en el navegador:

   | Servicio | URL | Para que se usa |
   |---|---|---|
   | JupyterLab | <http://127.0.0.1:8888/lab> | notebooks y scripts, sin token |
   | Metabase | <http://127.0.0.1:3000> | tablero (Ejercicio 7) |

5. Para ejecutar comandos dentro del ambiente de analisis:

   ```bash
   docker exec -it lab8-lab bash
   ```

6. Para detener todo sin borrar nada: `docker compose down`.

La carpeta `data/` se monta en `/workspace/data` dentro de los contenedores, y esa
es la ruta que se usa desde Jupyter, los scripts y Metabase. El detalle de cada
servicio, las versiones instaladas y el proposito de cada directorio esta en
[docs/ejercicio_01.md](docs/ejercicio_01.md).

## Como descargar los datos

Los datos salen de los Parquet mensuales que publica la TLC. El script
`scripts/download_data.py` corre dentro del contenedor `lab` (con el ambiente
levantado, ver la seccion anterior) y guarda cada archivo en
`data/raw/<tipo>/<anio>/`. Para tener los tres anios del laboratorio:

```bash
docker exec lab8-lab python scripts/download_data.py --years 2024 2025 2026
```

Otras formas de usarlo:

```bash
# amarillos y verdes de 2026 (valor por defecto)
docker exec lab8-lab python scripts/download_data.py

# otros anios y/o un solo tipo de taxi
docker exec lab8-lab python scripts/download_data.py --years 2025 --taxi green

# solo verificar lo que hay en disco contra el servidor, sin descargar
docker exec lab8-lab python scripts/download_data.py --verify-only
```

El script le pregunta al servidor que meses estan publicados, descarga solo los que
faltan o estan danados, y al final imprime una verificacion de completitud (meses
publicados contra archivos legibles). Volver a ejecutarlo no re-descarga lo que ya
esta bien. Ademas descarga una vez la tabla de zonas de la TLC
(`data/raw/zonas/taxi_zone_lookup.csv`), que se usa para nombrar las zonas en el
analisis.

Al 12 de octubre de 2026 la TLC tenia publicados 2024 y 2025 completos y de enero a
agosto de 2026, por lo que los datos son 32 meses por tipo de taxi (121,184,384
viajes y unos 2 GB de Parquet) y las comparaciones entre anios se hacen sobre los
mismos meses. El detalle de los cambios, las pruebas y los resultados esta en
[docs/ejercicio_02.md](docs/ejercicio_02.md), [docs/ejercicio_05.md](docs/ejercicio_05.md)
y [docs/ejercicio_08.md](docs/ejercicio_08.md).

## Como ejecutar el analisis

Las consultas viven en `sql/`, organizadas por ejercicio, y los notebooks en
`notebooks/` las leen desde ahi en lugar de copiarlas. Con el ambiente levantado y
los datos descargados, los notebooks se pueden abrir en JupyterLab
(<http://127.0.0.1:8888/lab>) o ejecutar desde la terminal:

```bash
docker exec lab8-lab sh -c "cd /workspace/notebooks && jupyter nbconvert --to notebook --execute --inplace ejercicio_03_consultas_parquet.ipynb"
```

| Ejercicio | Notebook | Consultas | Documentacion |
|---|---|---|---|
| 3. Consultas directas sobre Parquet | `ejercicio_03_consultas_parquet.ipynb` | `sql/ejercicio_03/` | [docs/ejercicio_03.md](docs/ejercicio_03.md) |
| 4. Analisis exploratorio | `ejercicio_04_analisis_exploratorio.ipynb` | `sql/ejercicio_04/` | [docs/ejercicio_04.md](docs/ejercicio_04.md) |
| 5. Incorporacion de 2024 | `ejercicio_05_incorporacion_2024.ipynb` | `sql/ejercicio_05/` | [docs/ejercicio_05.md](docs/ejercicio_05.md) |
| 8. Los tres anios | `ejercicio_08_tres_anios.ipynb` | `sql/ejercicio_08/` | [docs/ejercicio_08.md](docs/ejercicio_08.md) |

Las rutas dentro de los archivos `.sql` son las del contenedor (`/workspace/data/...`).
Los notebooks de los ejercicios 3 y 4 fijan `SET VARIABLE anios = [2026]` para
reproducir los numeros documentados, que se calcularon cuando solo habia datos de
2026. El notebook del ejercicio 5 conserva los resultados de cuando habia 2024 y
2026, y el del ejercicio 8 usa la tabla con los tres anios.

### Ejecutar las consultas desde la terminal

`scripts/ejecutar_sql.py` corre todos los `.sql` de una carpeta, con las vistas
primero. Sirve para reproducir resultados y para comprobar que las consultas siguen
funcionando cuando cambian los datos:

```bash
V="sql/ejercicio_03/00_vista_viajes.sql sql/ejercicio_04/00_vistas_apoyo.sql"

# todos los anios que haya en data/raw
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_05 --vistas $V

# solo 2026 (reproduce los numeros documentados de los ejercicios 3 y 4)
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas $V --anios 2026

# guardar resultados y compararlos despues con otra corrida
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas $V --anios 2026 --salida data/processed/resultados/ej04
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas $V --anios 2026 --comparar data/processed/resultados/ej04 --silencioso

# las consultas del ejercicio 8 leen la tabla materializada (ver la seccion de benchmarks)
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_08 --base data/processed/taxis.duckdb
```

Las vistas leen todos los anios de `data/raw` y respetan la variable de DuckDB
`anios` (`SET VARIABLE anios = [2024, 2026];`), asi que no hay que editar SQL para
acotar un analisis. El ejecutor limita DuckDB a 4 hilos y 2 GB de memoria (`--hilos`,
`--memoria`), porque los percentiles exactos sobre decenas de millones de filas
agotan la memoria del contenedor, que comparte unos 5 GB con Metabase. Con los tres
anios algunas consultas con muchos percentiles sobre los Parquet tardan varios
minutos (ver [docs/ejercicio_08.md](docs/ejercicio_08.md)).

## Como reproducir los benchmarks

El benchmark compara consultar los Parquet directamente contra una tabla
materializada en DuckDB (Ejercicio 6). Necesita los datos descargados y el ambiente
levantado. Para medir sin interferencia conviene detener Metabase, que ademas debe
estar detenido mientras se escribe la base (un `.duckdb` admite un solo proceso con
permiso de escritura):

```bash
docker compose stop metabase

# construye (o completa) data/processed/taxis.duckdb y mide las 7 consultas de sql/ejercicio_06
docker exec lab8-lab python scripts/benchmark_parquet_vs_tabla.py --volumenes 2026-08 2026-06,2026-07,2026-08 2026 2024 2024,2026 2024,2025,2026

# solo cargar la tabla, o rehacerla desde cero
docker exec lab8-lab python scripts/benchmark_parquet_vs_tabla.py --solo-construir
docker exec lab8-lab python scripts/benchmark_parquet_vs_tabla.py --reconstruir --solo-construir

# volver a medir solo una consulta sin perder el resto del CSV
docker exec lab8-lab python scripts/benchmark_parquet_vs_tabla.py --volumenes 2024,2025,2026 --solo-consultas 6_6 --agregar

# probar con mas memoria para DuckDB
docker exec lab8-lab python scripts/benchmark_parquet_vs_tabla.py --volumenes 2024,2025,2026 --memoria 4GB --salida data/processed/otra_memoria.csv
```

Un volumen es una lista de anios (`2024`) o meses (`2026-08`) separados por comas. La
carga de la tabla es incremental: al descargar un anio nuevo solo se insertan los
meses que faltan. El script deja `docs/benchmark_resultados.csv` (mediana, minimo,
maximo y desviacion por volumen, consulta y estrategia), `docs/benchmark_entorno.json`
y `docs/benchmark_carga_tabla.json`, y comprueba que las dos estrategias devuelven el
mismo resultado. Con 32 meses de datos y la configuracion por defecto (5
repeticiones, 6 volumenes) tarda cerca de una hora. Los resultados y su analisis
estan en [docs/ejercicio_06.md](docs/ejercicio_06.md).

## Como generar los resultados principales

Los resultados principales son el analisis documentado en `docs/`, el benchmark y el
tablero. Con el ambiente levantado, la secuencia completa desde cero es esta:

```bash
# 1. datos (el script omite lo que ya existe)
docker exec lab8-lab python scripts/download_data.py --years 2024 2025 2026

# 2. tabla materializada y benchmark (con Metabase detenido)
docker compose stop metabase
docker exec lab8-lab python scripts/benchmark_parquet_vs_tabla.py --volumenes 2026-08 2026-06,2026-07,2026-08 2026 2024 2024,2026 2024,2025,2026

# 3. vistas del tablero dentro de la base (tambien con Metabase detenido)
docker exec lab8-lab python scripts/preparar_vistas_tablero.py

# 4. tablero en Metabase
docker compose start metabase
docker exec lab8-lab python scripts/montar_tablero_metabase.py

# 5. graficas de los indicadores como PNG (docs/img/tablero)
docker exec lab8-lab python scripts/generar_indicadores.py
```

### Tablero en Metabase

Abrir <http://127.0.0.1:3000> e iniciar sesion con el usuario local del laboratorio,
que crea `montar_tablero_metabase.py` y solo existe en este Metabase (escucha
unicamente en 127.0.0.1):

| Usuario | Clave |
|---|---|
| `lab8@example.com` | `Taxis-NYC-Lab8-2026` |

El tablero "Taxis de Nueva York: indicadores" esta en la coleccion "Lab 8 DuckDB".
Metabase se conecta a `/workspace/data/processed/taxis.duckdb` en modo `read_only`,
con la ruta de dentro del contenedor, como indica la nota sobre DuckDB mas arriba, y
con 3 GB de memoria para DuckDB (con 1 GB las preguntas eran mucho mas lentas). Cada
pregunta del tablero es SQL nativo tomado de `sql/ejercicio_07/`. La captura del
tablero esta en `docs/img/tablero/metabase_tablero.png` y las graficas generadas con
matplotlib en `docs/img/tablero/`.

Problemas conocidos y como resolverlos:

| Sintoma | Causa | Solucion |
|---|---|---|
| `montar_tablero_metabase.py` falla al crear la coleccion | Error de la configuracion inicial de Metabase | Volver a ejecutarlo, ya reintenta solo |
| `Could not set lock on file` al construir la tabla | Metabase tiene la base abierta | `docker compose stop metabase`, reconstruir y volver a iniciarlo |
| El cambio de memoria de DuckDB en Metabase falla | DuckDB no permite otra configuracion sobre un archivo ya abierto | `docker compose restart metabase` y volver a ejecutar el script |
| `Cannot allocate memory` en una consulta de percentiles | Demasiados percentiles exactos a la vez | Pedirlos como lista en una sola llamada y usar `--hilos 4 --memoria 2GB` |

## Estructura final y documentacion

```text
.
+-- data/raw/<tipo>/<anio>/    Parquet de la TLC y data/raw/zonas (no van a Git)
+-- data/processed/            taxis.duckdb y resultados intermedios (no van a Git)
+-- sql/ejercicio_03 a 08/     una consulta por archivo
+-- notebooks/                 notebooks ejecutados de los ejercicios 3, 4, 5 y 8
+-- scripts/                   descarga, ejecutor de SQL, benchmark y tablero
+-- docs/                      un documento por ejercicio, resultados del benchmark e imagenes
+-- Dockerfile, metabase.Dockerfile, docker-compose.yml, requirements.txt
```

| Documento | Contenido |
|---|---|
| [docs/ejercicio_01.md](docs/ejercicio_01.md) | Ambiente, inventario de herramientas, proposito de cada directorio |
| [docs/ejercicio_02.md](docs/ejercicio_02.md) | Sistema de descarga y verificacion de completitud |
| [docs/ejercicio_03.md](docs/ejercicio_03.md) | Consultas directas sobre Parquet y problemas de calidad |
| [docs/ejercicio_04.md](docs/ejercicio_04.md) | Analisis exploratorio y hallazgos |
| [docs/ejercicio_05.md](docs/ejercicio_05.md) | Incorporacion de 2024 y cambios en las consultas |
| [docs/ejercicio_06.md](docs/ejercicio_06.md) | Parquet contra tabla materializada |
| [docs/ejercicio_07.md](docs/ejercicio_07.md) | Indicadores y tablero |
| [docs/ejercicio_08.md](docs/ejercicio_08.md) | Los tres anios y sus patrones |
| [docs/ejercicio_09.md](docs/ejercicio_09.md) | Discusion |

## Resultados principales

Con los tres anios (121,184,384 viajes) encontramos cuatro cosas que resumimos aqui y
que se explican en los documentos. Los taxis verdes y amarillos son dos servicios
distintos y no versiones grandes y pequenas del mismo: los verdes pierden viajes cada
anio (10% menos en 2025 y 14% menos en 2026 por dia) y concentran el 40% de sus
viajes en dos zonas de East Harlem, mientras que los amarillos tuvieron su maximo en
2025. La tarifa flexible, que no registra pasajeros ni propina, paso de 9.5% a 26.0%
de los viajes amarillos entre 2024 y 2026, sobre todo durante 2025. El total mediano
de los amarillos tiene un escalon en diciembre de 2025 que viene de la tarifa del
taximetro y no de los recargos. Y en el benchmark, una tabla materializada fue de 1.4 a
6.7 veces mas rapida que leer Parquet mientras cupo en la memoria de DuckDB, pero con
32 meses y 2 GB perdio toda su ventaja, que recupero con 4 GB.
