const mysql = require('mysql2/promise');
const { faker } = require('@faker-js/faker');

faker.locale = 'es';

// ====================================
// CONFIGURACIÓN
// ====================================
const DB_CONFIG = {
  host: 'localhost',
  user: 'meditrack_user',
  password: 'PasswordSeguro123!',
  database: 'MediTrack'
};

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

// ====================================
// GENERADORES
// ====================================

async function generarHabitosPacientes(connection, pacientes, habitos) {
  console.log(`\n🚬 Generando hábitos para ~60% de pacientes...`);
  
  const pacientesConHabitos = Math.floor(pacientes.length * 0.6);
  const pacientesSeleccionados = faker.helpers.shuffle(pacientes).slice(0, pacientesConHabitos);
  let totalAsignados = 0;

  for (const idPaciente of pacientesSeleccionados) {
    const numHabitos = randomInt(1, 4);
    const habitosSeleccionados = faker.helpers.shuffle(habitos).slice(0, numHabitos);

    for (const idHabito of habitosSeleccionados) {
      const observacion = Math.random() > 0.7 ? faker.lorem.sentence() : null;

      await connection.execute(
        'INSERT INTO HabitoPaciente (idHabito, idPaciente, observacion) VALUES (?, ?, ?)',
        [idHabito, idPaciente, observacion]
      );

      totalAsignados++;
    }
  }

  console.log(`   ✅ ${totalAsignados} hábitos asignados a ${pacientesConHabitos} pacientes`);
}

async function generarAlergiasPacientes(connection, pacientes, alergias) {
  console.log(`\n🤧 Generando alergias para ~30% de pacientes...`);
  
  const pacientesConAlergias = Math.floor(pacientes.length * 0.3);
  const pacientesSeleccionados = faker.helpers.shuffle(pacientes).slice(0, pacientesConAlergias);
  let totalAsignadas = 0;

  for (const idPaciente of pacientesSeleccionados) {
    const numAlergias = randomInt(1, 3);
    const alergiasSeleccionadas = faker.helpers.shuffle(alergias).slice(0, numAlergias);

    for (const idAlergia of alergiasSeleccionadas) {
      const fechaRegistro = randomDate(
        new Date(Date.now() - 3650 * 24 * 60 * 60 * 1000), // 10 años atrás
        new Date()
      ).toISOString().split('T')[0];

      const observacion = Math.random() > 0.6 ? 
        faker.helpers.arrayElement([
          'Reacción leve', 'Reacción moderada', 'Reacción severa',
          'Confirmado por especialista', 'Urticaria', 'Edema'
        ]) : null;

      await connection.execute(
        'INSERT INTO AlergiaPaciente (idPaciente, idAlergia, observacion, fechaRegistro) VALUES (?, ?, ?, ?)',
        [idPaciente, idAlergia, observacion, fechaRegistro]
      );

      totalAsignadas++;
    }
  }

  console.log(`   ✅ ${totalAsignadas} alergias asignadas a ${pacientesConAlergias} pacientes`);
}

async function generarVacunasPacientes(connection, pacientes, vacunas) {
  console.log(`\n💉 Generando vacunas para todos los pacientes...`);
  
  let totalVacunas = 0;

  for (let i = 0; i < pacientes.length; i++) {
    const idPaciente = pacientes[i];
    const numVacunas = randomInt(2, 5);
    const vacunasSeleccionadas = faker.helpers.shuffle(vacunas).slice(0, numVacunas);

    for (const idVacuna of vacunasSeleccionadas) {
      const fecha = randomDate(
        new Date(Date.now() - 3650 * 24 * 60 * 60 * 1000),
        new Date()
      ).toISOString().split('T')[0];

      const dosis = faker.helpers.arrayElement([
        '1ra dosis', '2da dosis', '3ra dosis', 'Refuerzo', 'Dosis única'
      ]);

      const observacion = Math.random() > 0.7 ? 
        faker.helpers.arrayElement([
          'Sin reacciones adversas',
          'Reacción leve en zona de inyección',
          'Aplicada según calendario',
          'Dosis de refuerzo programada'
        ]) : null;

      await connection.execute(
        'INSERT INTO PacienteVacuna (idPaciente, idVacuna, fecha, dosis, observacion) VALUES (?, ?, ?, ?, ?)',
        [idPaciente, idVacuna, fecha, dosis, observacion]
      );

      totalVacunas++;
    }

    if ((i + 1) % 200 === 0) {
      const porcentaje = ((i + 1) / pacientes.length * 100).toFixed(1);
      console.log(`   📊 Progreso: ${i + 1}/${pacientes.length} pacientes (${porcentaje}%)`);
    }
  }

  console.log(`   ✅ ${totalVacunas} vacunas asignadas`);
}

async function crearExamenesYAsignar(connection, consultas) {
  console.log(`\n🔬 Creando catálogo de exámenes...`);

  const examenes = [
    { nombre: 'Hemograma completo', tipo: 'Hematología', unidad: 'células/mm³', valorRef: 'Normal' },
    { nombre: 'Glicemia en ayunas', tipo: 'Bioquímica', unidad: 'mg/dL', valorRef: '70-100' },
    { nombre: 'Perfil lipídico', tipo: 'Bioquímica', unidad: 'mg/dL', valorRef: 'Colesterol <200' },
    { nombre: 'Creatinina', tipo: 'Función renal', unidad: 'mg/dL', valorRef: '0.7-1.3' },
    { nombre: 'Urea', tipo: 'Función renal', unidad: 'mg/dL', valorRef: '15-40' },
    { nombre: 'Transaminasas (GOT/GPT)', tipo: 'Función hepática', unidad: 'U/L', valorRef: '<40' },
    { nombre: 'TSH', tipo: 'Hormonal', unidad: 'mUI/L', valorRef: '0.4-4.0' },
    { nombre: 'Orina completa', tipo: 'Urianálisis', unidad: '-', valorRef: 'Normal' },
    { nombre: 'Radiografía de tórax', tipo: 'Imagenología', unidad: '-', valorRef: 'Sin hallazgos' },
    { nombre: 'Electrocardiograma', tipo: 'Cardiología', unidad: '-', valorRef: 'Ritmo sinusal normal' },
  ];

  const idsExamenes = [];

  for (const examen of examenes) {
    const [result] = await connection.execute(
      'INSERT INTO Examen (nombreExamen, tipoExamen, unidadMedida, valorReferencia) VALUES (?, ?, ?, ?)',
      [examen.nombre, examen.tipo, examen.unidad, examen.valorRef]
    );
    idsExamenes.push(result.insertId);
  }

  console.log(`   ✅ ${examenes.length} tipos de exámenes creados`);

  console.log(`\n🔬 Asignando exámenes a ~40% de consultas...`);
  
  const consultasConExamenes = Math.floor(consultas.length * 0.4);
  const consultasSeleccionadas = faker.helpers.shuffle(consultas).slice(0, consultasConExamenes);
  let totalExamenesAsignados = 0;

  for (const idConsulta of consultasSeleccionadas) {
    const numExamenes = randomInt(1, 3);
    const examenesSeleccionados = faker.helpers.shuffle(idsExamenes).slice(0, numExamenes);

    for (const idExamen of examenesSeleccionados) {
      const fecha = randomDate(
        new Date(Date.now() - 180 * 24 * 60 * 60 * 1000),
        new Date()
      ).toISOString().split('T')[0];

      const observacion = Math.random() > 0.6 ? 
        faker.helpers.arrayElement([
          'Resultados normales',
          'Requiere seguimiento',
          'Valores alterados leves',
          'Dentro de parámetros normales'
        ]) : null;

      await connection.execute(
        'INSERT INTO ConsultaExamen (idExamen, idConsulta, fecha, observacion) VALUES (?, ?, ?, ?)',
        [idExamen, idConsulta, fecha, observacion]
      );

      totalExamenesAsignados++;
    }
  }

  console.log(`   ✅ ${totalExamenesAsignados} exámenes asignados a ${consultasConExamenes} consultas`);
}

// ====================================
// FUNCIÓN PRINCIPAL
// ====================================
async function generarDatosComplementarios() {
  let connection;

  try {
    console.log('🔌 Conectando a la base de datos...');
    connection = await mysql.createConnection(DB_CONFIG);
    console.log('✅ Conexión establecida');

    const startTime = Date.now();

    // Obtener datos existentes
    console.log('\n📊 Consultando datos existentes...');
    const [pacientes] = await connection.execute('SELECT idPaciente FROM Paciente');
    const [habitos] = await connection.execute('SELECT idHabito FROM Habito');
    const [alergias] = await connection.execute('SELECT idAlergia FROM Alergia');
    const [vacunas] = await connection.execute('SELECT idVacuna FROM Vacuna');
    const [consultas] = await connection.execute('SELECT idConsulta FROM Consulta');

    console.log(`   ✅ ${pacientes.length} pacientes`);
    console.log(`   ✅ ${habitos.length} hábitos disponibles`);
    console.log(`   ✅ ${alergias.length} alergias disponibles`);
    console.log(`   ✅ ${vacunas.length} vacunas disponibles`);
    console.log(`   ✅ ${consultas.length} consultas registradas`);

    const idsPacientes = pacientes.map(p => p.idPaciente);
    const idsHabitos = habitos.map(h => h.idHabito);
    const idsAlergias = alergias.map(a => a.idAlergia);
    const idsVacunas = vacunas.map(v => v.idVacuna);
    const idsConsultas = consultas.map(c => c.idConsulta);

    // Generar datos
    await generarHabitosPacientes(connection, idsPacientes, idsHabitos);
    await generarAlergiasPacientes(connection, idsPacientes, idsAlergias);
    await generarVacunasPacientes(connection, idsPacientes, idsVacunas);
    await crearExamenesYAsignar(connection, idsConsultas);

    const endTime = Date.now();
    const duracion = ((endTime - startTime) / 1000).toFixed(2);

    console.log('\n✅ ¡PROCESO COMPLETADO!');
    console.log(`⏱️  Tiempo total: ${duracion} segundos`);

    // Mostrar estadísticas finales
    console.log('\n📈 ESTADÍSTICAS FINALES:');
    const [stats] = await connection.execute(`
      SELECT 
        (SELECT COUNT(*) FROM HabitoPaciente) as habitos,
        (SELECT COUNT(*) FROM AlergiaPaciente) as alergias,
        (SELECT COUNT(*) FROM PacienteVacuna) as vacunas,
        (SELECT COUNT(*) FROM Examen) as tiposExamenes,
        (SELECT COUNT(*) FROM ConsultaExamen) as examenesRealizados
    `);

    console.log(`   🚬 Hábitos asignados: ${stats[0].habitos}`);
    console.log(`   🤧 Alergias registradas: ${stats[0].alergias}`);
    console.log(`   💉 Vacunas aplicadas: ${stats[0].vacunas}`);
    console.log(`   🔬 Tipos de exámenes: ${stats[0].tiposExamenes}`);
    console.log(`   📋 Exámenes realizados: ${stats[0].examenesRealizados}`);

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
generarDatosComplementarios();
