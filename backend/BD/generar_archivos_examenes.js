const mysql = require('mysql2/promise');
const { createCanvas } = require('canvas');
const PDFDocument = require('pdfkit');

// ====================================
// CONFIGURACIÓN
// ====================================
const DB_CONFIG = {
  host: 'localhost',
  user: 'meditrack_user',
  password: 'PasswordSeguro123!',
  database: 'MediTrack'
};

// ====================================
// GENERADORES DE ARCHIVOS FAKE
// ====================================

// Generar PDF fake de examen médico
function generarPDFExamen(nombreExamen, tipoExamen, valorReferencia) {
  return new Promise((resolve) => {
    const doc = new PDFDocument({ size: 'A4', margin: 50 });
    const chunks = [];

    doc.on('data', (chunk) => chunks.push(chunk));
    doc.on('end', () => resolve(Buffer.concat(chunks)));

    // Header
    doc.fontSize(20).text('RESULTADO DE EXAMEN MÉDICO', { align: 'center' });
    doc.moveDown();
    doc.fontSize(10).text(`Fecha: ${new Date().toLocaleDateString('es-CL')}`, { align: 'right' });
    doc.moveDown(2);

    // Información del examen
    doc.fontSize(14).text(`Examen: ${nombreExamen}`, { underline: true });
    doc.moveDown();
    doc.fontSize(12).text(`Tipo: ${tipoExamen}`);
    doc.moveDown();
    doc.fontSize(11).text(`Valor de Referencia: ${valorReferencia}`);
    doc.moveDown(2);

    // Resultados simulados
    doc.fontSize(12).text('RESULTADOS:', { underline: true });
    doc.moveDown();
    
    const resultados = [
      'Estado: Normal',
      'Observaciones: Sin hallazgos significativos',
      'Comentarios: Paciente en condiciones óptimas',
      'Recomendaciones: Mantener seguimiento regular'
    ];

    resultados.forEach(resultado => {
      doc.fontSize(10).text(`• ${resultado}`);
      doc.moveDown(0.5);
    });


    doc.end();
  });
}

// Generar imagen fake de examen (PNG)
function generarImagenExamen(nombreExamen, tipoExamen) {
  const canvas = createCanvas(800, 600);
  const ctx = canvas.getContext('2d');

  // Fondo blanco
  ctx.fillStyle = '#FFFFFF';
  ctx.fillRect(0, 0, 800, 600);

  // Borde
  ctx.strokeStyle = '#333333';
  ctx.lineWidth = 3;
  ctx.strokeRect(10, 10, 780, 580);

  // Título
  ctx.fillStyle = '#2C3E50';
  ctx.font = 'bold 32px Arial';
  ctx.textAlign = 'center';
  ctx.fillText('EXAMEN MÉDICO', 400, 80);

  // Línea divisoria
  ctx.strokeStyle = '#3498DB';
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(100, 120);
  ctx.lineTo(700, 120);
  ctx.stroke();

  // Información
  ctx.fillStyle = '#34495E';
  ctx.font = '20px Arial';
  ctx.textAlign = 'left';
  ctx.fillText(`Examen: ${nombreExamen}`, 100, 180);
  ctx.fillText(`Tipo: ${tipoExamen}`, 100, 220);
  ctx.fillText(`Fecha: ${new Date().toLocaleDateString('es-CL')}`, 100, 260);

  // Gráfico simulado (barras)
  ctx.fillStyle = '#3498DB';
  ctx.fillRect(150, 350, 80, 150);
  ctx.fillStyle = '#2ECC71';
  ctx.fillRect(280, 380, 80, 120);
  ctx.fillStyle = '#E74C3C';
  ctx.fillRect(410, 400, 80, 100);
  ctx.fillStyle = '#F39C12';
  ctx.fillRect(540, 420, 80, 80);

  // Etiquetas
  ctx.fillStyle = '#7F8C8D';
  ctx.font = '12px Arial';
  ctx.textAlign = 'center';
  ctx.fillText('Ene', 190, 530);
  ctx.fillText('Feb', 320, 530);
  ctx.fillText('Mar', 450, 530);
  ctx.fillText('Abr', 580, 530);

  // Footer
  ctx.fillStyle = '#95A5A6';
  ctx.font = '10px Arial';
  ctx.textAlign = 'center';
  ctx.fillText('Documento de demostración - Generado automáticamente', 400, 570);

  return canvas.toBuffer('image/png');
}

// ====================================
// FUNCIÓN PRINCIPAL
// ====================================
async function poblarArchivosExamenes() {
  let connection;

  try {
    console.log('🔌 Conectando a la base de datos...');
    connection = await mysql.createConnection(DB_CONFIG);
    console.log('✅ Conexión establecida\n');

    const startTime = Date.now();

    // Obtener exámenes sin archivo
    console.log('📊 Consultando exámenes sin archivo...');
    const [examenes] = await connection.execute(`
      SELECT 
        ce.idExamen,
        ce.idConsulta,
        e.nombreExamen,
        e.tipoExamen,
        e.valorReferencia
      FROM ConsultaExamen ce
      INNER JOIN Examen e ON ce.idExamen = e.idExamen
      WHERE ce.archivoBlob IS NULL
      ORDER BY RAND()
      LIMIT 500
    `);

    console.log(`   ✅ ${examenes.length} exámenes encontrados\n`);

    if (examenes.length === 0) {
      console.log('⚠️  No hay exámenes sin archivo para poblar');
      return;
    }

    console.log('📄 Generando archivos fake...\n');
    let archivosGenerados = 0;

    for (let i = 0; i < examenes.length; i++) {
      const examen = examenes[i];
      const esPDF = Math.random() > 0.5; // 50% PDF, 50% PNG

      let archivoBuffer;
      let nombreArchivo;
      let tipoArchivo;

      if (esPDF) {
        archivoBuffer = await generarPDFExamen(
          examen.nombreExamen,
          examen.tipoExamen,
          examen.valorReferencia
        );
        nombreArchivo = `examen_${examen.idExamen}_${examen.idConsulta}_${Date.now()}.pdf`;
        tipoArchivo = 'application/pdf';
      } else {
        archivoBuffer = generarImagenExamen(
          examen.nombreExamen,
          examen.tipoExamen
        );
        nombreArchivo = `examen_${examen.idExamen}_${examen.idConsulta}_${Date.now()}.png`;
        tipoArchivo = 'image/png';
      }

      const archivoSize = archivoBuffer.length;

      // Insertar en BD
      await connection.execute(
        `UPDATE ConsultaExamen 
         SET archivoNombre = ?,
             archivoTipo = ?,
             archivoBlob = ?,
             archivoSize = ?,
             archivoFechaSubida = NOW()
         WHERE idExamen = ? AND idConsulta = ?`,
        [nombreArchivo, tipoArchivo, archivoBuffer, archivoSize, examen.idExamen, examen.idConsulta]
      );

      archivosGenerados++;

      if ((i + 1) % 50 === 0) {
        const porcentaje = ((i + 1) / examenes.length * 100).toFixed(1);
        const sizeMB = (archivoSize / 1024 / 1024).toFixed(2);
        console.log(`   📊 Progreso: ${i + 1}/${examenes.length} (${porcentaje}%) - Último: ${sizeMB} MB (${tipoArchivo})`);
      }
    }

    const endTime = Date.now();
    const duracion = ((endTime - startTime) / 1000).toFixed(2);

    console.log('\n✅ ¡PROCESO COMPLETADO!');
    console.log(`⏱️  Tiempo total: ${duracion} segundos`);
    console.log(`📄 Archivos generados: ${archivosGenerados}\n`);

    // Estadísticas finales
    console.log('📈 ESTADÍSTICAS FINALES:');
    const [stats] = await connection.execute(`
      SELECT 
        COUNT(*) as Total,
        SUM(CASE WHEN archivoBlob IS NOT NULL THEN 1 ELSE 0 END) as ConArchivo,
        SUM(CASE WHEN archivoBlob IS NULL THEN 1 ELSE 0 END) as SinArchivo,
        ROUND(SUM(archivoSize) / 1024 / 1024, 2) as TotalMB,
        ROUND(AVG(archivoSize) / 1024, 2) as PromedioKB
      FROM ConsultaExamen
    `);

    const stat = stats[0];
    console.log(`   📋 Total exámenes: ${stat.Total}`);
    console.log(`   ✅ Con archivo: ${stat.ConArchivo}`);
    console.log(`   ❌ Sin archivo: ${stat.SinArchivo}`);
    console.log(`   💾 Tamaño total: ${stat.TotalMB} MB`);
    console.log(`   📊 Promedio por archivo: ${stat.PromedioKB} KB`);

    // Distribución por tipo
    const [tipos] = await connection.execute(`
      SELECT 
        archivoTipo,
        COUNT(*) as Cantidad,
        ROUND(SUM(archivoSize) / 1024 / 1024, 2) as TotalMB
      FROM ConsultaExamen
      WHERE archivoBlob IS NOT NULL
      GROUP BY archivoTipo
    `);

    console.log('\n📊 DISTRIBUCIÓN POR TIPO:');
    tipos.forEach(tipo => {
      console.log(`   ${tipo.archivoTipo}: ${tipo.Cantidad} archivos (${tipo.TotalMB} MB)`);
    });

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n🔌 Conexión cerrada');
    }
  }
}

// ====================================
// EJECUTAR
// ====================================
poblarArchivosExamenes();
