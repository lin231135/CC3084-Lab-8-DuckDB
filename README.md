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

Las siguientes secciones deben ser completadas por cada equipo. El README final
debe permitir que una persona que no participo en el desarrollo pueda levantar el
ambiente, descargar los datos, ejecutar el analisis, reproducir los benchmarks y
generar los resultados principales.

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
`data/raw/<tipo>/<anio>/`.

```bash
# amarillos y verdes de 2026 (valor por defecto)
docker exec lab8-lab python scripts/download_data.py

# otros anios y/o un solo tipo de taxi
docker exec lab8-lab python scripts/download_data.py --years 2024 2026
docker exec lab8-lab python scripts/download_data.py --years 2025 --taxi green

# solo verificar lo que hay en disco contra el servidor, sin descargar
docker exec lab8-lab python scripts/download_data.py --verify-only
```

El script le pregunta al servidor que meses estan publicados, descarga solo los
que faltan o estan danados, y al final imprime una verificacion de completitud
(meses publicados contra archivos legibles). Ademas descarga una vez la tabla de
zonas de la TLC (`data/raw/zonas/taxi_zone_lookup.csv`), que se usa para nombrar
las zonas en el analisis. Para tener 2024 y 2026 juntos:

```bash
docker exec lab8-lab python scripts/download_data.py --years 2024 2026
``` Volver a ejecutarlo no re-descarga
lo que ya esta bien. Al 12 de octubre de 2026 la TLC tenia publicados de enero a
agosto de 2026, y por eso las comparaciones entre anios se hacen sobre los mismos
meses. El detalle de los cambios, las pruebas y los resultados esta en
[docs/ejercicio_02.md](docs/ejercicio_02.md).

## Como ejecutar el analisis

Las consultas viven en `sql/`, organizadas por ejercicio, y los notebooks en
`notebooks/` las leen desde ahi en lugar de copiarlas. Con el ambiente levantado
y los datos descargados, hay dos formas de ejecutar el Ejercicio 3:

```bash
# desde JupyterLab: abrir http://127.0.0.1:8888/lab y correr
#   notebooks/ejercicio_03_consultas_parquet.ipynb

# o desde la terminal, ejecutando el notebook completo
docker exec lab8-lab sh -c "cd /workspace/notebooks && jupyter nbconvert --to notebook --execute --inplace ejercicio_03_consultas_parquet.ipynb"
```

Las rutas dentro de los archivos `.sql` son las del contenedor (`/workspace/data/...`).
La explicacion de cada consulta y las decisiones tomadas estan en
[docs/ejercicio_03.md](docs/ejercicio_03.md).

Los ejercicios 4 y 5 siguen el mismo esquema (consultas en `sql/ejercicio_04/` y
`sql/ejercicio_05/`, notebooks `ejercicio_04_analisis_exploratorio.ipynb` y
`ejercicio_05_incorporacion_2024.ipynb`, documentacion en
[docs/ejercicio_04.md](docs/ejercicio_04.md) y [docs/ejercicio_05.md](docs/ejercicio_05.md)).

### Ejecutar las consultas desde la terminal

`scripts/ejecutar_sql.py` corre todos los `.sql` de una carpeta, con las vistas
primero. Sirve para reproducir resultados y para comprobar que las consultas
siguen funcionando cuando cambian los datos:

```bash
V="sql/ejercicio_03/00_vista_viajes.sql sql/ejercicio_04/00_vistas_apoyo.sql"

# todos los anios que haya en data/raw
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_05 --vistas $V

# solo 2026 (reproduce los numeros documentados de los ejercicios 3 y 4)
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas $V --anios 2026

# guardar resultados y compararlos despues con otra corrida
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas $V --anios 2026 --salida data/processed/resultados/ej04
docker exec lab8-lab python scripts/ejecutar_sql.py sql/ejercicio_04 --vistas $V --anios 2026 --comparar data/processed/resultados/ej04 --silencioso
```

Las vistas leen todos los anios de `data/raw` y respetan la variable de DuckDB
`anios` (`SET VARIABLE anios = [2024, 2026];`), asi que no hay que editar SQL para
acotar un analisis. El ejecutor limita DuckDB a 4 hilos y 2 GB de memoria
(`--hilos`, `--memoria`), porque los percentiles exactos sobre decenas de millones
de filas agotan la memoria del contenedor, que comparte unos 5 GB con Metabase.

## Como reproducir los benchmarks

<!-- TODO (Ejercicio 6) -->

## Como generar los resultados principales

<!-- TODO -->
