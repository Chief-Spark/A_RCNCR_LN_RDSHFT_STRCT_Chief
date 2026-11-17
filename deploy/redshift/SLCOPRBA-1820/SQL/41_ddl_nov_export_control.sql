-- HU SLCOPRBA-1820 | Subtarea SLCOPRBA-1823 (STRCT) - UNLOAD Calculo RECONOCER
-- ============================================================
-- 41_ddl_nov_export_control.sql  (Reconocer / Novedades hacia la cuenta Batch)
-- Tabla de control del Exportador de Novedades (sp_novedades_exportar_7_tablas).
-- Objeto en bdm_datos; idempotente (CREATE TABLE IF NOT EXISTS). UTF-8 sin
-- BOM. Nunca GRANT ... TO PUBLIC.
--
-- POR QUE EXISTE (mismo principio que geo_lote_control del Exportador_GEO):
--   Cada corrida del export queda registrada con su run_id UNICO
--   (<YYYYMMDDTHH24MISSZ>_<FULL|DELTA>) y una FIRMA de los datos exportados
--   (por tabla: filas, MAX(lote), MAX(fecha_actualizacion), mas el modo).
--   Antes de exportar, el SP compara la firma actual con la ultima corrida
--   'completado' del ambiente: si es la MISMA, los datos no cambiaron y NO se
--   vuelve a hacer UNLOAD (no se crea otra carpeta en S3). Solo se genera un
--   run_id nuevo cuando hay novedades que exportar.
--   Asi una re-ejecucion sin cambios (reintento, o el doble DPLY del ciclo de
--   verificacion de Jenkins) no duplica carpetas, y cada run_id es irrepetible.
--
-- Estados: en_proceso -> completado | fallido. Una corrida 'fallido' NO
-- bloquea: la siguiente con la misma firma vuelve a exportar.
--
-- LA FRONTERA DEL EXPORT ES SUYA Y NO SE TOMA DE nov_control. Son procesos
-- distintos y el export puede correr mas veces que la carga, de modo que
-- heredar el watermark de Novedades dejaria fuera lo que se cargo entre dos
-- exportaciones. Se lee como
--   MAX(watermark_nuevo) WHERE estado = 'completado' AND ambiente = <el actual>
-- ACOTADO POR AMBIENTE, que es justo lo que a nov_control le falta y ya esta
-- anotado como riesgo latente en la bitacora del Batch.
--
-- POR QUE fecha_actualizacion Y NO lote: el cargador de Novedades no hace
-- UPDATE en sitio, hace DELETE + INSERT y solo sobre las filas de la ventana
-- (sp_novedades_cargar_mat_ubicacion_edf.sql:36-70, WHERE flag_op IN ('I','A')),
-- escribiendo fecha_actualizacion = GETDATE(). De modo que la fecha se mueve
-- en altas Y en cambios, y NO se mueve en lo que no se toco: discrimina. El
-- lote tambien serviria hoy, pero la fecha acumula si el export corre menos
-- veces que la carga.
--
-- bootstrap: si no hay frontera previa, el export corre como FULL aunque se
-- pida DELTA (mismo patron que 16_sp_unificacion_ciclo.sql:180-185). Sin esa
-- marca, un DELTA que en realidad bajo todo se leeria como incremental.
-- ============================================================

CREATE TABLE IF NOT EXISTS bdm_datos.nov_export_control (
  run_id            VARCHAR(200)   NOT NULL,   -- carpeta S3: <base>/<run_id>/
  ejecucion_id      VARCHAR(256),              -- in_solicitud (execution_id del Framework), trazabilidad
  ambiente          VARCHAR(10)    NOT NULL,   -- DEV | QA | DEMO | PROD
  modo              VARCHAR(10)    NOT NULL,   -- FULL | DELTA
  estado            VARCHAR(20)    NOT NULL,   -- en_proceso | completado | fallido
  firma_datos       VARCHAR(2000)  NOT NULL,   -- huella de los datos exportados
  s3_prefix         VARCHAR(1000),             -- s3://<bucket>/<base>/<run_id>/
  registros_total   BIGINT,                    -- suma de filas de las 7 tablas
  bootstrap         BOOLEAN,                   -- TRUE si se pidio DELTA y corrio como FULL
  watermark_anterior TIMESTAMP,                -- frontera leida al arrancar (NULL en bootstrap)
  watermark_nuevo   TIMESTAMP,                 -- MAX(fecha_actualizacion) del dato considerado
  ultimo_error      VARCHAR(4000),
  fecha_inicio      TIMESTAMP      DEFAULT GETDATE(),
  fecha_fin         TIMESTAMP,
  usuario_bd        VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (ambiente, fecha_inicio);
