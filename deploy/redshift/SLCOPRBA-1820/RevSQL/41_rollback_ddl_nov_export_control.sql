-- HU SLCOPRBA-1820 | Subtarea SLCOPRBA-1823 (STRCT) - UNLOAD Calculo RECONOCER
-- Rollback de 41_ddl_nov_export_control.sql
-- Revierte la tabla de control del Exportador de Novedades.
-- Tablas SI admiten IF EXISTS en Redshift (a diferencia de PROCEDURE/FUNCTION).
DROP TABLE IF EXISTS bdm_datos.nov_export_control;
