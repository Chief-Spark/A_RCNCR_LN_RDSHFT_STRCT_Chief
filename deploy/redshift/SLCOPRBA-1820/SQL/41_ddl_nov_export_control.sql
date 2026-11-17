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
  ultimo_error      VARCHAR(4000),
  fecha_inicio      TIMESTAMP      DEFAULT GETDATE(),
  fecha_fin         TIMESTAMP,
  usuario_bd        VARCHAR(100)
)
DISTSTYLE ALL
SORTKEY (ambiente, fecha_inicio);
