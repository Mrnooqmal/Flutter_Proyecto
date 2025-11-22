const mysql = require('mysql2/promise');
const { faker } = require('@faker-js/faker');

// Configurar Faker en español
faker.locale = 'es';

// CONFIGURACIÓN
const DB_CONFIG = {
  host: 'localhost',
  user: 'meditrack_user',
  password: 'PasswordSeguro123!',
  database: 'MediTrack'
};

const CANTIDAD_PACIENTES = 1000;

// Datos específicos para Chile
const previsiones = [
  'Fonasa A', 'Fonasa B', 'Fonasa C', 'Fonasa D',
  'Isapre Banmédica', 'Isapre Consalud', 'Isapre Cruz Blanca', 
  'Isapre Colmena', 'Isapre Vida Tres', 'Isapre Nueva Masvida',
  'Particular', 'CAPREDENA', 'DIPRECA'
];

const nacionalidades = [
  'Chilena', 'Argentina', 'Peruana', 'Colombiana', 'Venezolana', 
  'Ecuatoriana', 'Boliviana', 'Brasileña', 'Uruguaya', 'Paraguaya'
];

const tiposSangre = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];

function randomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

function generarPaciente() {
  const sexo = faker.person.sex();
  const sexoEs = sexo === 'male' ? 'masculino' : 'femenino';
  
  const nombre = faker.person.firstName(sexo);
  const apellido = faker.person.lastName();
  const nombreCompleto = `${nombre} ${apellido}`;
  
  return {
    nombrePaciente: nombreCompleto,
    fechaNacimiento: faker.date.birthdate({ min: 1, max: 90, mode: 'age' }).toISOString().split('T')[0],
    correo: faker.internet.email({ firstName: nombre, lastName: apellido }).toLowerCase(),
    telefono: `+569${faker.string.numeric(8)}`,
    direccion: `${faker.location.streetAddress()}, ${faker.location.city()}`,
    sexo: sexoEs,
    nacionalidad: Math.random() > 0.3 ? 'Chilena' : randomItem(nacionalidades),
    ocupacion: faker.person.jobTitle(),
    prevision: randomItem(previsiones),
    tipoSangre: randomItem(tiposSangre)
  };
}

async function generarPacientes() {
  let connection;
  try {
    console.log(' Conectando a la base de datos...');
    connection = await mysql.createConnection(DB_CONFIG);
    console.log(' Conexión establecida\n');
    console.log(` Generando ${CANTIDAD_PACIENTES} pacientes con datos realistas...\n`);

    const startTime = Date.now();
    for (let i = 0; i < CANTIDAD_PACIENTES; i++) {
      const paciente = generarPaciente();
      await connection.execute(
        `INSERT INTO Paciente (nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [paciente.nombrePaciente, paciente.fechaNacimiento, paciente.correo, paciente.telefono,
         paciente.direccion, paciente.sexo, paciente.nacionalidad, paciente.ocupacion,
         paciente.prevision, paciente.tipoSangre]
      );
      if ((i + 1) % 100 === 0) {
        const porcentaje = ((i + 1) / CANTIDAD_PACIENTES * 100).toFixed(1);
        console.log(`    Progreso: ${i + 1}/${CANTIDAD_PACIENTES} (${porcentaje}%)`);
      }
    }

    const endTime = Date.now();
    const duracion = ((endTime - startTime) / 1000).toFixed(2);
    console.log(`\n ¡Completado! ${CANTIDAD_PACIENTES} pacientes insertados`);
    console.log(`  Tiempo: ${duracion} segundos`);

    const [rows] = await connection.execute('SELECT COUNT(*) as total FROM Paciente');
    console.log(`\n Total en BD: ${rows[0].total}`);

    const [ultimos] = await connection.execute(
      'SELECT nombrePaciente, correo, prevision FROM Paciente ORDER BY idPaciente DESC LIMIT 5'
    );
    console.log('\n Últimos 5 pacientes:');
    ultimos.forEach((p, idx) => {
      console.log(`   ${idx + 1}. ${p.nombrePaciente} - ${p.correo} - ${p.prevision}`);
    });

  } catch (error) {
    console.error(' Error:', error.message);
  } finally {
    if (connection) {
      await connection.end();
      console.log('\n Conexión cerrada');
    }
  }
}

generarPacientes();
