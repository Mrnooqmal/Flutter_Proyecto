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

// ====================================
// DATOS MÉDICOS REALISTAS
// ====================================
const especialidades = [
  'Medicina General', 'Cardiología', 'Pediatría', 'Ginecología',
  'Traumatología', 'Dermatología', 'Neurología', 'Psiquiatría',
  'Oftalmología', 'Otorrinolaringología', 'Endocrinología', 'Urología',
  'Gastroenterología', 'Neumología', 'Nefrología'
];

const nombresServicios = [
  'Hospital Clínico Universidad de Chile',
  'Clínica Las Condes',
  'Hospital San Borja Arriarán',
  'Clínica Alemana',
  'Hospital Barros Luco',
  'Clínica Santa María',
  'Hospital del Salvador',
  'Clínica Universidad de los Andes',
  'CESFAM Juan Pablo II',
  'CESFAM San Alberto Hurtado',
  'Consultorio Médico Providencia',
  'Centro Médico San Joaquín'
];

const motivosConsulta = [
  'Control de salud general', 'Dolor abdominal', 'Cefalea persistente',
  'Control de presión arterial', 'Fiebre y malestar general',
  'Dolor de garganta', 'Control de diabetes', 'Tos persistente',
  'Dolor lumbar', 'Control post-operatorio', 'Revisión de exámenes',
  'Dolor articular', 'Fatiga crónica', 'Mareos', 'Insomnio',
  'Control prenatal', 'Dolor de pecho', 'Problemas digestivos'
];

const diagnosticos = [
  'Estado general estable', 'Hipertensión arterial controlada',
  'Infección respiratoria alta', 'Lumbalgia mecánica',
  'Gastritis aguda', 'Ansiedad leve', 'Diabetes tipo 2 controlada',
  'Migraña común', 'Faringitis viral', 'Dermatitis de contacto',
  'Artrosis leve', 'Mejoría progresiva', 'Requiere seguimiento',
  'Sin hallazgos patológicos'
];

function randomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function randomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

// ====================================
// GENERADORES
// ====================================

async function generarProfesionalesSalud(connection, cantidad = 30) {
  console.log(`\n📋 Generando ${cantidad} profesionales de salud...`);
  const profesionales = [];

  for (let i = 0; i < cantidad; i++) {
    const sexo = faker.person.sex();
    const nombre = `Dr. ${faker.person.firstName(sexo)} ${faker.person.lastName()}`;
    const especialidad = randomItem(especialidades);

    const [result] = await connection.execute(
      'INSERT INTO ProfesionalSalud (nombre, especialidad) VALUES (?, ?)',
      [nombre, especialidad]
    );

    profesionales.push(result.insertId);
  }

  console.log(`   ✅ ${cantidad} profesionales creados`);
  return profesionales;
}

async function generarServiciosSalud(connection, tiposConsulta) {
  console.log(`\n🏥 Generando ${nombresServicios.length} servicios de salud...`);
  const servicios = [];

  for (const nombre of nombresServicios) {
    const direccion = `${faker.location.streetAddress()}, ${faker.location.city()}`;
    const idTipo = randomItem(tiposConsulta);

    const [result] = await connection.execute(
      'INSERT INTO ServicioSalud (nombreServicioSalud, direccion, idTipoServicioSalud) VALUES (?, ?, ?)',
      [nombre, direccion, idTipo]
    );

    servicios.push(result.insertId);
  }

  console.log(`   ✅ ${nombresServicios.length} servicios creados`);
  return servicios;
}

async function generarConsultasYSignosVitales(connection, pacientes, profesionales, servicios, tiposConsulta) {
  console.log(`\n💉 Generando consultas y signos vitales para ${pacientes.length} pacientes...`);
  
  let totalConsultas = 0;
  let totalSignosVitales = 0;

  for (let i = 0; i < pacientes.length; i++) {
    const idPaciente = pacientes[i];
    const numConsultas = randomInt(2, 5);

    for (let j = 0; j < numConsultas; j++) {
      // Generar fecha de consulta (últimos 2 años)
      const fechaIngreso = randomDate(
        new Date(Date.now() - 730 * 24 * 60 * 60 * 1000),
        new Date()
      ).toISOString().split('T')[0];

      const motivo = randomItem(motivosConsulta);
      const observacion = randomItem(diagnosticos);
      const idProfesional = randomItem(profesionales);
      const idServicio = randomItem(servicios);
      const idTipo = randomItem(tiposConsulta);

      // Insertar consulta
      const [consultaResult] = await connection.execute(
        `INSERT INTO Consulta (idPaciente, idServicioSalud, idProfesionalSalud, idTipoConsulta, fechaIngreso, motivo, observacion)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [idPaciente, idServicio, idProfesional, idTipo, fechaIngreso, motivo, observacion]
      );

      const idConsulta = consultaResult.insertId;
      totalConsultas++;

      // Insertar signos vitales para esta consulta
      // 1. Peso (idDatoClinico = 3)
      const peso = (randomInt(50, 100) + Math.random()).toFixed(1);
      await connection.execute(
        'INSERT INTO DetalleConsulta (idConsulta, idDatoClinico, valor, fechaRegistro) VALUES (?, ?, ?, ?)',
        [idConsulta, 3, `${peso} kg`, fechaIngreso]
      );

      // 2. Presión arterial (idDatoClinico = 1)
      const sistolica = randomInt(100, 140);
      const diastolica = randomInt(60, 90);
      await connection.execute(
        'INSERT INTO DetalleConsulta (idConsulta, idDatoClinico, valor, fechaRegistro) VALUES (?, ?, ?, ?)',
        [idConsulta, 1, `${sistolica}/${diastolica}`, fechaIngreso]
      );

      // 3. Temperatura (idDatoClinico = 2)
      const temperatura = (36 + Math.random() * 2).toFixed(1);
      await connection.execute(
        'INSERT INTO DetalleConsulta (idConsulta, idDatoClinico, valor, fechaRegistro) VALUES (?, ?, ?, ?)',
        [idConsulta, 2, `${temperatura} °C`, fechaIngreso]
      );

      totalSignosVitales += 3;
    }

    // Progreso cada 100 pacientes
    if ((i + 1) % 100 === 0) {
      const porcentaje = ((i + 1) / pacientes.length * 100).toFixed(1);
      console.log(`   📊 Progreso: ${i + 1}/${pacientes.length} pacientes (${porcentaje}%)`);
    }
  }

  console.log(`   ✅ ${totalConsultas} consultas creadas`);
  console.log(`   ✅ ${totalSignosVitales} signos vitales registrados`);
}

async function generarMedicamentosCronicos(connection, pacientes, medicamentos) {
  console.log(`\n💊 Generando medicamentos crónicos para ~30% de pacientes...`);
  
  const pacientesConMedicamentos = Math.floor(pacientes.length * 0.3);
  let totalAsignados = 0;

  // Seleccionar pacientes aleatorios
  const pacientesSeleccionados = faker.helpers.shuffle(pacientes).slice(0, pacientesConMedicamentos);

  for (const idPaciente of pacientesSeleccionados) {
    const numMedicamentos = randomInt(1, 3);
    const medicamentosSeleccionados = faker.helpers.shuffle(medicamentos).slice(0, numMedicamentos);

    for (const idMedicamento of medicamentosSeleccionados) {
      const fechaInicio = randomDate(
        new Date(Date.now() - 365 * 24 * 60 * 60 * 1000),
        new Date()
      ).toISOString().split('T')[0];

      await connection.execute(
        'INSERT INTO MedicamentoCronicoPaciente (idPaciente, idMedicamento, fechaInicio, cronico) VALUES (?, ?, ?, ?)',
        [idPaciente, idMedicamento, fechaInicio, true]
      );

      totalAsignados++;
    }
  }

  console.log(`   ✅ ${totalAsignados} medicamentos crónicos asignados a ${pacientesConMedicamentos} pacientes`);
}

// ====================================
// FUNCIÓN PRINCIPAL
// ====================================
async function generarDatosMedicos() {
  let connection;

  try {
    console.log('🔌 Conectando a la base de datos...');
    connection = await mysql.createConnection(DB_CONFIG);
    console.log('✅ Conexión establecida');

    const startTime = Date.now();

    // Obtener pacientes existentes
    console.log('\n📊 Consultando datos existentes...');
    const [pacientes] = await connection.execute('SELECT idPaciente FROM Paciente');
    const [tiposConsulta] = await connection.execute('SELECT idTipoConsulta FROM TipoConsulta');
    const [medicamentos] = await connection.execute('SELECT idMedicamento FROM Medicamento');

    console.log(`   ✅ ${pacientes.length} pacientes encontrados`);
    console.log(`   ✅ ${tiposConsulta.length} tipos de consulta disponibles`);
    console.log(`   ✅ ${medicamentos.length} medicamentos disponibles`);

    const idsPacientes = pacientes.map(p => p.idPaciente);
    const idsTiposConsulta = tiposConsulta.map(t => t.idTipoConsulta);
    const idsMedicamentos = medicamentos.map(m => m.idMedicamento);

    // Generar profesionales y servicios
    const profesionales = await generarProfesionalesSalud(connection, 30);
    const servicios = await generarServiciosSalud(connection, idsTiposConsulta);

    // Generar consultas y signos vitales
    await generarConsultasYSignosVitales(connection, idsPacientes, profesionales, servicios, idsTiposConsulta);

    // Generar medicamentos crónicos
    await generarMedicamentosCronicos(connection, idsPacientes, idsMedicamentos);

    const endTime = Date.now();
    const duracion = ((endTime - startTime) / 1000).toFixed(2);

    console.log('\n✅ ¡PROCESO COMPLETADO!');
    console.log(`⏱️  Tiempo total: ${duracion} segundos`);

    // Mostrar estadísticas finales
    console.log('\n📈 ESTADÍSTICAS FINALES:');
    const [stats] = await connection.execute(`
      SELECT 
        (SELECT COUNT(*) FROM ProfesionalSalud) as profesionales,
        (SELECT COUNT(*) FROM ServicioSalud) as servicios,
        (SELECT COUNT(*) FROM Consulta) as consultas,
        (SELECT COUNT(*) FROM DetalleConsulta) as signosVitales,
        (SELECT COUNT(*) FROM MedicamentoCronicoPaciente) as medicamentosCronicos
    `);

    console.log(`   👨‍⚕️ Profesionales: ${stats[0].profesionales}`);
    console.log(`   🏥 Servicios de salud: ${stats[0].servicios}`);
    console.log(`   📋 Consultas médicas: ${stats[0].consultas}`);
    console.log(`   💓 Signos vitales registrados: ${stats[0].signosVitales}`);
    console.log(`   💊 Medicamentos crónicos: ${stats[0].medicamentosCronicos}`);

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
generarDatosMedicos();
