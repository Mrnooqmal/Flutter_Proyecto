-- ====================================
-- Script de migración: Agregar soporte BLOB a ConsultaExamen
-- Ejecutar UNA SOLA VEZ
-- ====================================

USE MediTrack;

-- Agregar columnas para almacenar archivos
ALTER TABLE ConsultaExamen 
ADD COLUMN archivoNombre VARCHAR(255) NULL COMMENT 'Nombre original del archivo',
ADD COLUMN archivoTipo VARCHAR(50) NULL COMMENT 'MIME type (application/pdf, image/jpeg, etc)',
ADD COLUMN archivoBlob LONGBLOB NULL COMMENT 'Contenido binario del archivo',
ADD COLUMN archivoSize INT NULL COMMENT 'Tamaño del archivo en bytes',
ADD COLUMN archivoFechaSubida TIMESTAMP NULL COMMENT 'Fecha de subida del archivo';

-- Verificar cambios
DESCRIBE ConsultaExamen;

-- Mostrar estadísticas
SELECT 
    COUNT(*) as TotalExamenes,
    SUM(CASE WHEN archivoBlob IS NOT NULL THEN 1 ELSE 0 END) as ConArchivo,
    SUM(CASE WHEN archivoBlob IS NULL THEN 1 ELSE 0 END) as SinArchivo
FROM ConsultaExamen;

SELECT 'Migración completada exitosamente' as Resultado;
