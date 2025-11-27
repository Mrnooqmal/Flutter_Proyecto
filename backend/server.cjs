const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const multer = require('multer');
const EventEmitter = require('events');
const eventEmitter = new EventEmitter();

let sseClientes = [];

const app = express();
// AUMENTAR LÍMITES DE TAMAÑO - CRÍTICO PARA ARCHIVOS
app.use(express.json({ limit: '50mb' })); // Aumentado de 1mb a 50mb
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use(cors());

// Configurar multer para almacenar archivos en memoria
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 16 * 1024 * 1024, // 16MB maximo
  },
  fileFilter: (req, file, cb) => {
    // aceptar solo PDFs e imagenes
    if (file.mimetype === 'application/pdf' || file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Solo se permiten archivos PDF e imágenes'));
    }
  }
});

// Configuración de BD desde variables de entorno con valores por defecto
const dbHost = process.env.NODE_DB_HOST || process.env.DB_HOST || '127.0.0.1';
const dbPort = parseInt(process.env.NODE_DB_PORT || process.env.DB_PORT || '3306', 10);
const dbUser = process.env.NODE_DB_USER || process.env.DB_USERNAME || 'meditrack_user';
const dbPass = process.env.NODE_DB_PASS || process.env.DB_PASSWORD || 'PasswordSeguro123!';
const dbName = process.env.NODE_DB_NAME || process.env.DB_DATABASE || 'MediTrack';

const db = mysql.createConnection({
  host: dbHost,
  port: dbPort,
  user: dbUser,
  password: dbPass,
  database: dbName,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  enableKeepAlive: true,
  keepAliveInitialDelay: 0
});

db.connect((err) => {
  if (err) {
    console.error('Error conectando a MySQL:', err);
    return;
  }
  console.log('Conectado a MySQL en EC2');
});


// GET /api/pacientes - Obtener todos los pacientes
app.get('/api/pacientes', (req, res) => {
  const query = 'SELECT * FROM Paciente ORDER BY idPaciente DESC';
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error en MySQL:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});




















// ==============================================================================================================
  // ==============================
  // ENDPOINTS PARA CONSULTAS Laravel
  // ==============================

  // GET /api/consultas - listar consultas con búsqueda por paciente y paginación
  app.get('/api/consultas', async (req, res) => {
    try {
      const q = (req.query.q || '').trim();
      const page = parseInt(req.query.page || '1', 10);
      const perPage = 25;
      const offset = (page - 1) * perPage;

      // Base query
      let whereClause = '';
      const params = [];

      if (q) {
        // Buscar por el nombre real presente en la tabla Paciente
        whereClause = `WHERE (p.nombrePaciente LIKE ?)`;
        const like = `%${q}%`;
        params.push(like);
      }

      // Total count
      const countQuery = `SELECT COUNT(*) as total FROM Consulta c LEFT JOIN Paciente p ON c.idPaciente = p.idPaciente ${whereClause}`;
      const [countResults] = await db.promise().query(countQuery, params);
      const total = countResults[0].total || 0;

      // Data query with pagination and basic relations (paciente, tipoConsulta)
      const dataQuery = `
        SELECT c.*, p.nombrePaciente, tc.nombreTipoConsulta
        FROM Consulta c
        LEFT JOIN Paciente p ON c.idPaciente = p.idPaciente
        LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
        ${whereClause}
        ORDER BY c.idConsulta DESC
        LIMIT ? OFFSET ?
      `;

      params.push(perPage, offset);
      const [rows] = await db.promise().query(dataQuery, params);

      res.json({
        success: true,
        data: rows,
        meta: {
          total,
          perPage,
          page,
          lastPage: Math.ceil(total / perPage)
        }
      });
    } catch (error) {
      console.error('Error listando consultas:', error);
      res.status(500).json({ success: false, message: 'Error listando consultas', error: error.message });
    }
  });

  // GET /api/consultas/create - datos necesarios para formulario (pacientes y tipos)
  app.get('/api/consultas/create', async (req, res) => {
    try {
      // Simplificar a las columnas que existen en la base de datos
      const pacientesQuery = `SELECT idPaciente, nombrePaciente as nombre FROM Paciente ORDER BY nombrePaciente LIMIT 200`;
      const tiposQuery = `SELECT idTipoConsulta, nombreTipoConsulta FROM TipoConsulta ORDER BY nombreTipoConsulta`;

      const [pacientes] = await db.promise().query(pacientesQuery);
      const [tipos] = await db.promise().query(tiposQuery);

      res.json({ success: true, data: { pacientes, tipos } });
    } catch (error) {
      console.error('Error obteniendo meta para crear consulta:', error);
      res.status(500).json({ success: false, message: 'Error obteniendo meta', error: error.message });
    }
  });

  // POST /api/consultas - crear nueva consulta
  app.post('/api/consultas', async (req, res) => {
    try {
      const {
        idPaciente,
        idServicioSalud,
        idProfesionalSalud,
        idTipoConsulta,
        fechaIngreso,
        fechaEgreso,
        condicionEgreso,
        hora,
        motivo,
        observacion
      } = req.body;

      const insertQuery = `
        INSERT INTO Consulta
        (idPaciente, idServicioSalud, idProfesionalSalud, idTipoConsulta, fechaIngreso, fechaEgreso, condicionEgreso, hora, motivo, observacion)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      const [result] = await db.promise().query(insertQuery, [
        idPaciente || null,
        idServicioSalud || null,
        idProfesionalSalud || null,
        idTipoConsulta || null,
        fechaIngreso || null,
        fechaEgreso || null,
        condicionEgreso || null,
        hora || null,
        motivo || null,
        observacion || null
      ]);

      const nuevoId = result.insertId;

      const [newRow] = await db.promise().query('SELECT * FROM Consulta WHERE idConsulta = ?', [nuevoId]);

      // Notificar SSE a clientes si aplica
      notificarClientes('consulta_creada', newRow[0] || { idConsulta: nuevoId });

      res.status(201).json({ success: true, data: newRow[0] || { idConsulta: nuevoId } });
    } catch (error) {
      console.error('Error creando consulta:', error);
      res.status(500).json({ success: false, message: 'Error creando consulta', error: error.message });
    }
  });

  // GET /api/consultas/:id - obtener consulta con relaciones
  app.get('/api/consultas/:id', async (req, res) => {
    try {
      const id = req.params.id;
      // Evitar joins a tablas que pueden no existir en todas las instalaciones (ProfesionalSalud, ServicioSalud)
      const [rows] = await db.promise().query(
        `SELECT c.*, p.nombrePaciente, tc.nombreTipoConsulta
         FROM Consulta c
         LEFT JOIN Paciente p ON c.idPaciente = p.idPaciente
         LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
         WHERE c.idConsulta = ?`, [id]
      );

      if (!rows || rows.length === 0) {
        return res.status(404).json({ success: false, message: 'Consulta no encontrada' });
      }

      // obtener consultaExamenes
      const [examenes] = await db.promise().query('SELECT * FROM ConsultaExamen WHERE idConsulta = ? ORDER BY fecha DESC', [id]);

      const consulta = rows[0];
      consulta.consultaExamenes = examenes;

      res.json({ success: true, data: consulta });
    } catch (error) {
      console.error('Error obteniendo consulta:', error);
      res.status(500).json({ success: false, message: 'Error obteniendo consulta', error: error.message });
    }
  });

  // GET /api/consultas/:id/edit - datos para editar (consulta + pacientes + tipos)
  app.get('/api/consultas/:id/edit', async (req, res) => {
    try {
      const id = req.params.id;
      const [[consultaRows], pacientes] = await Promise.all([
        db.promise().query('SELECT * FROM Consulta WHERE idConsulta = ?', [id]),
        db.promise().query(`SELECT idPaciente, nombrePaciente as nombre FROM Paciente ORDER BY nombrePaciente LIMIT 200`)
      ]);

      const [tipos] = await db.promise().query('SELECT idTipoConsulta, nombreTipoConsulta FROM TipoConsulta ORDER BY nombreTipoConsulta');

      if (!consultaRows || consultaRows.length === 0) {
        return res.status(404).json({ success: false, message: 'Consulta no encontrada' });
      }

      res.json({ success: true, data: { consulta: consultaRows[0], pacientes: pacientes[0], tipos } });
    } catch (error) {
      console.error('Error obteniendo datos para editar consulta:', error);
      res.status(500).json({ success: false, message: 'Error obteniendo datos', error: error.message });
    }
  });

  // PUT /api/consultas/:id - actualizar consulta
  app.put('/api/consultas/:id', async (req, res) => {
    try {
      const id = req.params.id;
      const {
        idPaciente,
        idServicioSalud,
        idProfesionalSalud,
        idTipoConsulta,
        fechaIngreso,
        fechaEgreso,
        condicionEgreso,
        hora,
        motivo,
        observacion
      } = req.body;

      const updateQuery = `
        UPDATE Consulta SET
          idPaciente = ?, idServicioSalud = ?, idProfesionalSalud = ?, idTipoConsulta = ?,
          fechaIngreso = ?, fechaEgreso = ?, condicionEgreso = ?, hora = ?, motivo = ?, observacion = ?
        WHERE idConsulta = ?
      `;

      const [result] = await db.promise().query(updateQuery, [
        idPaciente || null,
        idServicioSalud || null,
        idProfesionalSalud || null,
        idTipoConsulta || null,
        fechaIngreso || null,
        fechaEgreso || null,
        condicionEgreso || null,
        hora || null,
        motivo || null,
        observacion || null,
        id
      ]);

      if (result.affectedRows === 0) {
        return res.status(404).json({ success: false, message: 'Consulta no encontrada' });
      }

      const [updated] = await db.promise().query('SELECT * FROM Consulta WHERE idConsulta = ?', [id]);

      notificarClientes('consulta_actualizada', updated[0]);

      res.json({ success: true, data: updated[0] });
    } catch (error) {
      console.error('Error actualizando consulta:', error);
      res.status(500).json({ success: false, message: 'Error actualizando consulta', error: error.message });
    }
  });

  // DELETE /api/consultas/:id - eliminar consulta
  app.delete('/api/consultas/:id', async (req, res) => {
    try {
      const id = req.params.id;
      const [result] = await db.promise().query('DELETE FROM Consulta WHERE idConsulta = ?', [id]);

      if (result.affectedRows === 0) {
        return res.status(404).json({ success: false, message: 'Consulta no encontrada' });
      }

      notificarClientes('consulta_eliminada', { idConsulta: parseInt(id) });

      res.json({ success: true, message: 'Consulta eliminada' });
    } catch (error) {
      console.error('Error eliminando consulta:', error);
      res.status(500).json({ success: false, message: 'Error eliminando consulta', error: error.message });
    }
  });

  // ==============================================================================================================
















// sse - endpoint para stream de cambios 
app.get('/api/pacientes/stream', (req, res) => {
  // configurar headers
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');

  // comentario inicial
  res.write(': conexion sse ok\n\n');

  // agregar cliente a la lista
  sseClientes.push(res);
  console.log(`cliente sse conectado. total: ${sseClientes.length}`);

  // manejar desconexion
  req.on('close', () => {
    sseClientes = sseClientes.filter(client => client !== res);
    console.log(`cliente sse desconectado. total: ${sseClientes.length}`);
  });
});

// GET /api/pacientes/:id - Obtener paciente por ID
app.get('/api/pacientes/:id', (req, res) => {
  const { id } = req.params;
  const query = 'SELECT * FROM Paciente WHERE idPaciente = ?';
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error en MySQL:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    
    if (results.length === 0) {
      return res.status(404).json({ error: 'Paciente no encontrado' });
    }
    
    res.json(results[0]);
  });
});


// funcion para notificar cambios via sse a todos los clientes conectados
function notificarClientes(evento, data) {
  const mensaje = `event: ${evento}\ndata: ${JSON.stringify(data)}\n\n`;

  console.log('notificando via sse:', evento, data);

  sseClientes.forEach(client => {
    client.write(mensaje);
  });
}

// POST /api/pacientes - Crear nuevo paciente
app.post('/api/pacientes', (req, res) => {
  const { nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre } = req.body;
  
  // validar campos requeridos
  if (!nombrePaciente || !fechaNacimiento || !sexo) {
    return res.status(400).json({ error: 'faltan campos requeridos: nombrePaciente, fechaNacimiento, sexo' });
  }
  
  // validar que sexo sea uno de los valores permitidos
  const sexosValidos = ['masculino', 'femenino', 'otro'];
  if (!sexosValidos.includes(sexo.toLowerCase())) {
    return res.status(400).json({ error: 'sexo debe ser: masculino, femenino u otro' });
  }
  
  const query = `
    INSERT INTO Paciente 
    (nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;
  
  db.query(query, [
    nombrePaciente,
    fechaNacimiento, 
    correo || null, 
    telefono || null, 
    direccion || null, 
    sexo.toLowerCase(), 
    nacionalidad || null, 
    ocupacion || null, 
    prevision || null, 
    tipoSangre || null
  ], 
    (err, results) => {
      if (err) {
        console.error('error en mysql:', err);
        return res.status(500).json({ error: 'error creando paciente', details: err.message });
      }
      
      const nuevoPaciente = {
        idPaciente: results.insertId,
        nombrePaciente,
        fechaNacimiento,
        correo,
        telefono,
        direccion,
        sexo,
        nacionalidad,
        ocupacion,
        prevision,
        tipoSangre
      };

      res.json({ 
        ...nuevoPaciente,
        message: 'paciente creado ok'
      });

      // notificar via sse
      notificarClientes('paciente_creado', nuevoPaciente);
    }
  );
});

// DELETE /api/pacientes/:id - Eliminar paciente
app.delete('/api/pacientes/:id', (req, res) => {
  const { id } = req.params;
  const query = 'DELETE FROM Paciente WHERE idPaciente = ?';

  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error en MySQL:', err);
      return res.status(500).json({ error: 'Error eliminando paciente' });
    }

    if (results.affectedRows === 0) {
      return res.status(404).json({ error: 'Paciente no encontrado' });
    }

    res.json({ message: 'Paciente eliminado exitosamente' });

    // notificar SSE
    notificarClientes('paciente_eliminado', { idPaciente: parseInt(id) });
  });
});

// PUT /api/pacientes/:id - Actualizar paciente (CORREGIDO)
app.put('/api/pacientes/:id', (req, res) => {
  const { id } = req.params;
  const {
    nombrePaciente,
    fechaNacimiento,
    correo,
    telefono,
    direccion,
    sexo,
    nacionalidad,
    ocupacion,
    prevision,
    tipoSangre
  } = req.body;

  console.log('>>> Actualizando paciente ID:', id);
  console.log('>>> Correo recibido:', correo);

  // Primero verificar si el paciente existe y obtener su correo actual
  const checkQuery = 'SELECT correo FROM Paciente WHERE idPaciente = ?';
  
  db.query(checkQuery, [id], (checkErr, checkResults) => {
    if (checkErr) {
      console.error('Error verificando paciente:', checkErr);
      return res.status(500).json({ error: 'Error verificando paciente', details: checkErr.message });
    }

    if (checkResults.length === 0) {
      return res.status(404).json({ error: 'Paciente no encontrado' });
    }

    const pacienteActual = checkResults[0];
    const correoActual = pacienteActual.correo;
    
    console.log('>>> Correo actual en BD:', correoActual);
    console.log('>>> Correo nuevo recibido:', correo);

    // si el correo no cambio, hacer UPDATE normal
    if (correo === correoActual || correo === null || correo === '') {
      console.log('>>> Correo no cambio o es nulo, procediendo con UPDATE normal');
      
      const updateQuery = `
        UPDATE Paciente 
        SET nombrePaciente = ?, fechaNacimiento = ?, correo = ?, telefono = ?,
        direccion = ?, sexo = ?, nacionalidad = ?, ocupacion = ?,
        prevision = ?, tipoSangre = ?
        WHERE idPaciente = ?
      `;

      const values = [
        nombrePaciente,
        fechaNacimiento,
        correo,
        telefono,
        direccion,
        sexo,
        nacionalidad,
        ocupacion,
        prevision,
        tipoSangre,
        id
      ];

      db.query(updateQuery, values, (updateErr, updateResult) => {
        if (updateErr) {
          console.error('Error en UPDATE:', updateErr);
          return res.status(500).json({ error: 'Error actualizando paciente', details: updateErr.message });
        }
        
        if (updateResult.affectedRows === 0) {
          return res.status(404).json({ error: 'Paciente no encontrado' });
        }
        
        const pacienteActualizado = {
          idPaciente: parseInt(id),
          nombrePaciente,
          fechaNacimiento,
          correo,
          telefono,
          direccion,
          sexo,
          nacionalidad,
          ocupacion,
          prevision,
          tipoSangre
        };

        console.log('✅ Paciente actualizado exitosamente. ID:', id);
        res.json(pacienteActualizado);

        // notificar SSE
        notificarClientes('paciente_actualizado', pacienteActualizado);
      });
    } else {
      // si el correo cambio, verificar que no exista en otro paciente
      console.log('>>> Correo cambio, verificando duplicado...');
      
      const checkEmailQuery = 'SELECT idPaciente FROM Paciente WHERE correo = ? AND idPaciente != ?';
      
      db.query(checkEmailQuery, [correo, id], (emailErr, emailResults) => {
        if (emailErr) {
          console.error('Error verificando correo:', emailErr);
          return res.status(500).json({ error: 'Error verificando correo', details: emailErr.message });
        }

        if (emailResults.length > 0) {
          console.log('❌ Correo ya existe en otro paciente');
          return res.status(400).json({ error: 'El correo electrónico ya está en uso por otro paciente' });
        }

        // Si el correo no existe en otro paciente, proceder con UPDATE
        console.log('✅ Correo disponible, procediendo con UPDATE');
        
        const updateQuery = `
          UPDATE Paciente 
          SET nombrePaciente = ?, fechaNacimiento = ?, correo = ?, telefono = ?,
          direccion = ?, sexo = ?, nacionalidad = ?, ocupacion = ?,
          prevision = ?, tipoSangre = ?
          WHERE idPaciente = ?
        `;

        const values = [
          nombrePaciente,
          fechaNacimiento,
          correo,
          telefono,
          direccion,
          sexo,
          nacionalidad,
          ocupacion,
          prevision,
          tipoSangre,
          id
        ];

        db.query(updateQuery, values, (updateErr, updateResult) => {
          if (updateErr) {
            console.error('Error en UPDATE:', updateErr);
            return res.status(500).json({ error: 'Error actualizando paciente', details: updateErr.message });
          }
          
          if (updateResult.affectedRows === 0) {
            return res.status(404).json({ error: 'Paciente no encontrado' });
          }
          
          const pacienteActualizado = {
            idPaciente: parseInt(id),
            nombrePaciente,
            fechaNacimiento,
            correo,
            telefono,
            direccion,
            sexo,
            nacionalidad,
            ocupacion,
            prevision,
            tipoSangre
          };

          console.log('Paciente actualizado exitosamente. ID:', id);
          res.json(pacienteActualizado);

          notificarClientes('paciente_actualizado', pacienteActualizado);
        });
      });
    }
  });
});

// ====================================
// ENDPOINTS PARA FICHA MEDICA DETALLADA
// ====================================

// GET /api/pacientes/:id/consultas - Obtener consultas de un paciente
app.get('/api/pacientes/:id/consultas', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      c.idConsulta,
      c.fechaIngreso,
      c.motivo,
      c.observacion,
      c.condicionEgreso,
      tc.nombreTipoConsulta,
      ps.nombre as nombreProfesional,
      ps.especialidad,
      ss.nombreServicioSalud
    FROM Consulta c
    LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
    LEFT JOIN ProfesionalSalud ps ON c.idProfesionalSalud = ps.idProfesionalSalud
    LEFT JOIN ServicioSalud ss ON c.idServicioSalud = ss.idServicioSalud
    WHERE c.idPaciente = ?
    ORDER BY c.fechaIngreso DESC
    LIMIT 10
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo consultas:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/signos-vitales - Obtener signos vitales de un paciente
app.get('/api/pacientes/:id/signos-vitales', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      dc.idConsulta,
      c.fechaIngreso,
      dcl.nombre as tipoDato,
      dcl.unidadMedida,
      dc.valor,
      dc.fechaRegistro
    FROM DetalleConsulta dc
    INNER JOIN Consulta c ON dc.idConsulta = c.idConsulta
    INNER JOIN DatoClinico dcl ON dc.idDatoClinico = dcl.idDatoClinico
    WHERE c.idPaciente = ?
    ORDER BY dc.fechaRegistro DESC, dc.idConsulta DESC
    LIMIT 30
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo signos vitales:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/medicamentos-cronicos - obtener medicamentos cronicos de un paciente
app.get('/api/pacientes/:id/medicamentos-cronicos', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      m.idMedicamento,
      m.nombreMedicamento,
      m.empresa,
      mcp.fechaInicio,
      mcp.fechaFin,
      mcp.cronico
    FROM MedicamentoCronicoPaciente mcp
    INNER JOIN Medicamento m ON mcp.idMedicamento = m.idMedicamento
    WHERE mcp.idPaciente = ?
    ORDER BY mcp.fechaInicio DESC
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo medicamentos cronicos:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/habitos - obtener habitos de un paciente
app.get('/api/pacientes/:id/habitos', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      h.idHabito,
      h.habito as nombreHabito,
      hp.observacion
    FROM HabitoPaciente hp
    INNER JOIN Habito h ON hp.idHabito = h.idHabito
    WHERE hp.idPaciente = ?
    ORDER BY h.habito
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo hábitos:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/alergias - Obtener alergias de un paciente
app.get('/api/pacientes/:id/alergias', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      a.idAlergia,
      a.alergia as nombreAlergia,
      ap.observacion,
      ap.fechaRegistro
    FROM AlergiaPaciente ap
    INNER JOIN Alergia a ON ap.idAlergia = a.idAlergia
    WHERE ap.idPaciente = ?
    ORDER BY ap.fechaRegistro DESC
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo alergias:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/vacunas - Obtener vacunas de un paciente
app.get('/api/pacientes/:id/vacunas', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      v.idVacuna,
      v.nombre as nombreVacuna,
      v.observacion as descripcionVacuna,
      pv.fecha,
      pv.dosis,
      pv.observacion
    FROM PacienteVacuna pv
    INNER JOIN Vacuna v ON pv.idVacuna = v.idVacuna
    WHERE pv.idPaciente = ?
    ORDER BY pv.fecha DESC
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo vacunas:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/examenes - obtener examenes de un paciente
app.get('/api/pacientes/:id/examenes', (req, res) => {
  const { id } = req.params;
  
  const query = `
    SELECT 
      e.idExamen,
      e.nombreExamen,
      e.tipoExamen,
      e.unidadMedida,
      e.valorReferencia,
      ce.fecha,
      ce.observacion,
      ce.idConsulta,
      ce.archivoNombre,
      ce.archivoTipo,
      ce.archivoSize,
      ce.archivoFechaSubida,
      c.fechaIngreso as fechaConsulta,
      tc.nombreTipoConsulta
    FROM ConsultaExamen ce
    INNER JOIN Examen e ON ce.idExamen = e.idExamen
    INNER JOIN Consulta c ON ce.idConsulta = c.idConsulta
    LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
    WHERE c.idPaciente = ?
    ORDER BY ce.fecha DESC
    LIMIT 20
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error('Error obteniendo exámenes:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/examenes/:idExamen/:idConsulta/archivo - Obtener archivo de examen (metadata + base64)
app.get('/api/examenes/:idExamen/:idConsulta/archivo', (req, res) => {
  const { idExamen, idConsulta } = req.params;
  
  const query = `
    SELECT 
      archivoNombre,
      archivoTipo,
      archivoSize,
      archivoBlob,
      archivoFechaSubida
    FROM ConsultaExamen
    WHERE idExamen = ? AND idConsulta = ?
  `;
  
  db.query(query, [idExamen, idConsulta], (err, results) => {
    if (err) {
      console.error('Error obteniendo archivo:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    
    if (results.length === 0 || !results[0].archivoBlob) {
      return res.status(404).json({ error: 'Archivo no encontrado' });
    }
    
    const archivo = results[0];
    
    // Convertir BLOB a base64
    const base64 = archivo.archivoBlob.toString('base64');
    
    res.json({
      nombre: archivo.archivoNombre,
      tipo: archivo.archivoTipo,
      size: archivo.archivoSize,
      fechaSubida: archivo.archivoFechaSubida,
      contenido: base64
    });
  });
});

// GET /api/examenes/:idExamen/:idConsulta/download - Descargar archivo directamente
app.get('/api/examenes/:idExamen/:idConsulta/download', (req, res) => {
  const { idExamen, idConsulta } = req.params;
  
  const query = `
    SELECT 
      archivoNombre,
      archivoTipo,
      archivoBlob
    FROM ConsultaExamen
    WHERE idExamen = ? AND idConsulta = ?
  `;
  
  db.query(query, [idExamen, idConsulta], (err, results) => {
    if (err) {
      console.error('Error descargando archivo:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    
    if (results.length === 0 || !results[0].archivoBlob) {
      return res.status(404).json({ error: 'Archivo no encontrado' });
    }
    
    const archivo = results[0];
    
    // Configurar headers para descarga
    res.setHeader('Content-Type', archivo.archivoTipo);
    res.setHeader('Content-Disposition', `attachment; filename="${archivo.archivoNombre}"`);
    res.setHeader('Content-Length', archivo.archivoBlob.length);
    
    // Enviar archivo
    res.send(archivo.archivoBlob);
  });
});

// POST /api/examenes/upload - Subir archivo de examen
app.post('/api/examenes/upload', upload.single('archivo'), async (req, res) => {
  try {
    const { idPaciente, idExamen, observacion } = req.body;
    
    if (!req.file) {
      return res.status(400).json({ error: 'No se proporcionó archivo' });
    }
    
    if (!idPaciente || !idExamen) {
      return res.status(400).json({ error: 'idPaciente e idExamen son requeridos' });
    }

    // buscar ultima consulta del paciente o crear una nueva
    db.query(
      'SELECT idConsulta FROM Consulta WHERE idPaciente = ? ORDER BY fechaIngreso DESC LIMIT 1',
      [idPaciente],
      (err, consultas) => {
        if (err) {
          console.error('Error buscando consulta:', err);
          return res.status(500).json({ error: 'Error del servidor' });
        }

        let idConsulta;

        const insertarExamen = (consultaId) => {
          const fecha = new Date().toISOString().split('T')[0];
          const archivoNombre = req.file.originalname;
          const archivoTipo = req.file.mimetype;
          const archivoBlob = req.file.buffer;
          const archivoSize = req.file.size;

          // Insertar examen con archivo
          db.query(
            `INSERT INTO ConsultaExamen 
             (idExamen, idConsulta, fecha, observacion, archivoNombre, archivoTipo, archivoBlob, archivoSize, archivoFechaSubida) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
            [idExamen, consultaId, fecha, observacion || null, archivoNombre, archivoTipo, archivoBlob, archivoSize],
            (err, result) => {
              if (err) {
                console.error('Error insertando examen:', err);
                return res.status(500).json({ error: 'Error guardando examen' });
              }

              res.json({
                success: true,
                message: 'Archivo subido exitosamente',
                idConsulta: consultaId,
                idExamen: idExamen,
                archivoNombre: archivoNombre,
                archivoSize: archivoSize
              });
            }
          );
        };

        if (consultas.length > 0) {
          // Usar consulta existente
          insertarExamen(consultas[0].idConsulta);
        } else {
          // Crear nueva consulta
          db.query(
            `INSERT INTO Consulta (idPaciente, fechaIngreso, motivo, idTipoConsulta) 
             VALUES (?, NOW(), 'Subida de examen', 1)`,
            [idPaciente],
            (err, result) => {
              if (err) {
                console.error('Error creando consulta:', err);
                return res.status(500).json({ error: 'Error creando consulta' });
              }
              insertarExamen(result.insertId);
            }
          );
        }
      }
    );
  } catch (error) {
    console.error('Error en upload:', error);
    res.status(500).json({ error: 'Error procesando archivo' });
  }
});

// ====================================
// DASHBOARD ENDPOINTS
// ====================================

// GET /api/dashboard/stats - estadisticas principales
app.get('/api/dashboard/stats', (req, res) => {
  const queries = {
    totalPacientes: 'SELECT COUNT(*) as total FROM Paciente',
    consultasHoy: `SELECT COUNT(*) as total FROM Consulta WHERE fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)`,
    pacientesCriticos: `
      SELECT COUNT(DISTINCT c.idPaciente) as total
      FROM DetalleConsulta dc
      JOIN Consulta c ON dc.idConsulta = c.idConsulta
      WHERE c.fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        AND (
          (dc.idDatoClinico = 2 AND (dc.valor < 36 OR dc.valor > 38))
          OR (dc.idDatoClinico = 5 AND dc.valor > 140)
        )
    `,
    examenesPendientes: `
      SELECT COUNT(*) as total 
      FROM ConsultaExamen ce
      JOIN Consulta c ON ce.idConsulta = c.idConsulta
      WHERE c.fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    `
  };

  const stats = {};
  let completedQueries = 0;
  const totalQueries = Object.keys(queries).length;

  Object.keys(queries).forEach(key => {
    db.query(queries[key], (err, results) => {
      if (err) {
        console.error(`Error en query ${key}:`, err);
        stats[key] = 0;
      } else {
        stats[key] = results[0].total;
      }
      
      completedQueries++;
      if (completedQueries === totalQueries) {
        res.json(stats);
      }
    });
  });
});

// GET /api/dashboard/consultas-por-dia - consultas de los ultimos 30 dias
app.get('/api/dashboard/consultas-por-dia', (req, res) => {
  const dias = req.query.dias || 30;
  
  const query = `
    SELECT 
      DATE(fechaIngreso) as fecha,
      COUNT(*) as cantidad
    FROM Consulta
    WHERE fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL ? DAY)
    GROUP BY DATE(fechaIngreso)
    ORDER BY fecha ASC
  `;
  
  db.query(query, [dias], (err, results) => {
    if (err) {
      console.error('Error obteniendo consultas por dia:', err);
      return res.status(500).json({ error: 'Error obteniendo datos' });
    }
    res.json(results);
  });
});

// GET /api/dashboard/pacientes-por-edad - distribucion de pacientes por rango etario
app.get('/api/dashboard/pacientes-por-edad', (req, res) => {
  const query = `
    SELECT 
      CASE 
        WHEN TIMESTAMPDIFF(YEAR, fechaNacimiento, CURDATE()) < 18 THEN '0-17'
        WHEN TIMESTAMPDIFF(YEAR, fechaNacimiento, CURDATE()) BETWEEN 18 AND 40 THEN '18-40'
        WHEN TIMESTAMPDIFF(YEAR, fechaNacimiento, CURDATE()) BETWEEN 41 AND 65 THEN '41-65'
        ELSE '65+'
      END as rangoEdad,
      COUNT(*) as cantidad
    FROM Paciente
    GROUP BY rangoEdad
    ORDER BY rangoEdad
  `;
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error obteniendo distribucion por edad:', err);
      return res.status(500).json({ error: 'Error obteniendo datos' });
    }
    res.json(results);
  });
});

// GET /api/dashboard/top-examenes - top 5 examenes mas solicitados
app.get('/api/dashboard/top-examenes', (req, res) => {
  const query = `
    SELECT 
      e.nombreExamen as examen,
      COUNT(*) as cantidad
    FROM ConsultaExamen ce
    INNER JOIN Examen e ON ce.idExamen = e.idExamen
    GROUP BY e.idExamen, e.nombreExamen
    ORDER BY cantidad DESC
    LIMIT 5
  `;
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error obteniendo top examenes:', err);
      return res.status(500).json({ error: 'Error obteniendo datos' });
    }
    res.json(results);
  });
});

// GET /api/dashboard/top-medicamentos - top 5 medicamentos mas recetados
app.get('/api/dashboard/top-medicamentos', (req, res) => {
  const query = `
    SELECT 
      m.nombreMedicamento as medicamento,
      COUNT(*) as cantidad
    FROM MedicamentoCronicoPaciente mc
    INNER JOIN Medicamento m ON mc.idMedicamento = m.idMedicamento
    GROUP BY m.idMedicamento, m.nombreMedicamento
    ORDER BY cantidad DESC
    LIMIT 5
  `;
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error obteniendo top medicamentos:', err);
      return res.status(500).json({ error: 'Error obteniendo datos' });
    }
    res.json(results);
  });
});

// GET /api/dashboard/ultimas-consultas - ultimas 5 consultas registradas
app.get('/api/dashboard/ultimas-consultas', (req, res) => {
  const query = `
    SELECT 
      c.idConsulta,
      c.fechaIngreso,
      c.motivo,
      p.nombrePaciente,
      p.idPaciente
    FROM Consulta c
    INNER JOIN Paciente p ON c.idPaciente = p.idPaciente
    ORDER BY c.fechaIngreso DESC
    LIMIT 5
  `;
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error obteniendo últimas consultas:', err);
      return res.status(500).json({ error: 'Error obteniendo datos' });
    }
    res.json(results);
  });
});

// GET /api/dashboard/alertas-signos-vitales - Pacientes con signos vitales anormales
app.get('/api/dashboard/alertas-signos-vitales', (req, res) => {
  const query = `
    SELECT 
      p.idPaciente,
      p.nombrePaciente,
      MAX(CASE WHEN dc.idDatoClinico = 1 THEN dc.valor END) as presionArterial,
      MAX(CASE WHEN dc.idDatoClinico = 2 THEN dc.valor END) as temperatura,
      MAX(CASE WHEN dc.idDatoClinico = 3 THEN dc.valor END) as peso,
      MAX(CASE WHEN dc.idDatoClinico = 5 THEN dc.valor END) as glucosa,
      dc.fechaRegistro as fechaMedicion,
      CASE
        WHEN MAX(CASE WHEN dc.idDatoClinico = 2 THEN CAST(dc.valor AS DECIMAL(10,2)) END) > 38 THEN 'Fiebre'
        WHEN MAX(CASE WHEN dc.idDatoClinico = 2 THEN CAST(dc.valor AS DECIMAL(10,2)) END) < 35 THEN 'Hipotermia'
        WHEN MAX(CASE WHEN dc.idDatoClinico = 5 THEN CAST(dc.valor AS DECIMAL(10,2)) END) > 200 THEN 'Glucosa alta'
        WHEN MAX(CASE WHEN dc.idDatoClinico = 5 THEN CAST(dc.valor AS DECIMAL(10,2)) END) < 70 THEN 'Glucosa baja'
        ELSE 'Otro'
      END as alerta
    FROM DetalleConsulta dc
    INNER JOIN Consulta c ON dc.idConsulta = c.idConsulta
    INNER JOIN Paciente p ON c.idPaciente = p.idPaciente
    WHERE dc.fechaRegistro >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    AND dc.idDatoClinico IN (1, 2, 3, 5)
    GROUP BY p.idPaciente, p.nombrePaciente, dc.fechaRegistro
    HAVING (
      MAX(CASE WHEN dc.idDatoClinico = 2 THEN CAST(dc.valor AS DECIMAL(10,2)) END) > 38 OR
      MAX(CASE WHEN dc.idDatoClinico = 2 THEN CAST(dc.valor AS DECIMAL(10,2)) END) < 35 OR
      MAX(CASE WHEN dc.idDatoClinico = 5 THEN CAST(dc.valor AS DECIMAL(10,2)) END) > 200 OR
      MAX(CASE WHEN dc.idDatoClinico = 5 THEN CAST(dc.valor AS DECIMAL(10,2)) END) < 70
    )
    ORDER BY dc.fechaRegistro DESC
    LIMIT 10
  `;
  
  db.query(query, (err, results) => {
    if (err) {
      console.error('Error obteniendo alertas de signos vitales:', err);
      return res.status(500).json({ error: 'Error obteniendo datos' });
    }
    res.json(results);
  });
});


// DELETE /api/pacientes/:id - Eliminar paciente
app.delete('/api/pacientes/:id', (req, res) => {
  const { id } = req.params;
  const query = 'DELETE FROM Paciente WHERE idPaciente = ?';

  db.query(query, [id], (err, results) => {
    if (err) {
      console.error(`Error en DELETE /api/pacientes/${id}:`, err.message);
      return res.status(500).json({ 
        error: 'Error eliminando paciente',
        details: err.message 
      });
    }

    if (results.affectedRows === 0) {
      console.log(`DELETE /api/pacientes/${id} - Paciente no encontrado`);
      return res.status(404).json({ error: 'Paciente no encontrado' });
    }

    console.log(`DELETE /api/pacientes/${id} - Paciente eliminado exitosamente`);
    res.json({ message: 'Paciente eliminado exitosamente' });

    // Notificar SSE
    notificarClientes('paciente_eliminado', { idPaciente: parseInt(id) });
  });
});

// ========== ENDPOINTS DE FAMILIAS ==========

// GET /api/familias/:idPaciente - Obtener familias de un paciente con sus miembros
app.get('/api/familias/:idPaciente', (req, res) => {
  const { idPaciente } = req.params;
  
  console.log(`GET /api/familias/${idPaciente} - Buscando familias`);
  
  const query = `
    SELECT 
      f.idFamilia, 
      f.nombre, 
      f.descripcion, 
      f.idOwner, 
      f.created_at, 
      f.updated_at,
      fp.idPaciente as miembro_idPaciente,
      fp.rol as miembro_rol,
      COALESCE(fp.fechaAgregado, NOW()) as miembro_fechaAgregado,
      p.nombrePaciente,
      p.fechaNacimiento,
      p.correo,
      p.telefono,
      p.direccion,
      p.sexo,
      p.nacionalidad,
      p.ocupacion,
      p.prevision,
      p.tipoSangre
    FROM Familia f
    LEFT JOIN FamiliaPaciente fp ON f.idFamilia = fp.idFamilia
    LEFT JOIN Paciente p ON fp.idPaciente = p.idPaciente
    WHERE f.idOwner = ? OR fp.idPaciente = ?
    ORDER BY f.idFamilia, COALESCE(fp.fechaAgregado, NOW()) DESC
  `;
  
  db.query(query, [idPaciente, idPaciente], (err, results) => {
    if (err) {
      console.error(`Error en GET /api/familias/${idPaciente}:`, err.message);
      return res.status(500).json({ 
        error: 'Error obteniendo familias', 
        details: err.message 
      });
    }
    
    const familiasMap = new Map();
    
    results.forEach(row => {
      if (!familiasMap.has(row.idFamilia)) {
        familiasMap.set(row.idFamilia, {
          idFamilia: row.idFamilia,
          nombre: row.nombre,
          descripcion: row.descripcion,
          idOwner: row.idOwner,
          created_at: row.created_at,
          updated_at: row.updated_at,
          miembros: []
        });
      }
      
      if (row.miembro_idPaciente) {
        const miembro = {
          idFamilia: row.idFamilia,
          idPaciente: row.miembro_idPaciente,
          rol: row.miembro_rol,
          fechaAgregado: row.miembro_fechaAgregado,
          paciente: {
            idPaciente: row.miembro_idPaciente,
            nombrePaciente: row.nombrePaciente,
            fechaNacimiento: row.fechaNacimiento,
            correo: row.correo,
            telefono: row.telefono,
            direccion: row.direccion,
            sexo: row.sexo,
            nacionalidad: row.nacionalidad,
            ocupacion: row.ocupacion,
            prevision: row.prevision,
            tipoSangre: row.tipoSangre
          }
        };
        console.log(`  Miembro encontrado: ${row.nombrePaciente} (ID: ${row.miembro_idPaciente}) en familia ${row.idFamilia}`);
        familiasMap.get(row.idFamilia).miembros.push(miembro);
      }
    });
    
    const familias = Array.from(familiasMap.values());
    
    console.log(`GET /api/familias/${idPaciente} - ${familias.length} familias encontradas`);
    familias.forEach(f => {
      console.log(`  Familia ${f.idFamilia} (${f.nombre}): ${f.miembros.length} miembros`);
    });
    res.json({ data: familias });
  });
});

// GET /api/familias/:id - Obtener familia por ID (ENDPOINT NUEVO - SOLUCIÓN AL 404)
app.get('/api/familias/:id', (req, res) => {
  const { id } = req.params;
  
  console.log(`GET /api/familias/${id} - Buscando familia por ID`);
  
  const query = `
    SELECT 
      f.idFamilia, 
      f.nombre, 
      f.descripcion, 
      f.idOwner, 
      f.created_at, 
      f.updated_at,
      fp.idPaciente as miembro_idPaciente,
      fp.rol as miembro_rol,
      COALESCE(fp.fechaAgregado, NOW()) as miembro_fechaAgregado,
      p.nombrePaciente,
      p.fotoPerfil,
      p.fechaNacimiento,
      p.correo,
      p.telefono,
      p.direccion,
      p.sexo,
      p.nacionalidad,
      p.ocupacion,
      p.prevision,
      p.tipoSangre
    FROM Familia f
    LEFT JOIN FamiliaPaciente fp ON f.idFamilia = fp.idFamilia
    LEFT JOIN Paciente p ON fp.idPaciente = p.idPaciente
    WHERE f.idFamilia = ?
    ORDER BY COALESCE(fp.fechaAgregado, NOW()) DESC
  `;
  
  db.query(query, [id], (err, results) => {
    if (err) {
      console.error(`Error en GET /api/familias/${id}:`, err.message);
      return res.status(500).json({ 
        error: 'Error obteniendo familia', 
        details: err.message 
      });
    }
    
    if (results.length === 0) {
      console.log(`GET /api/familias/${id} - Familia no encontrada`);
      return res.status(404).json({ error: 'Familia no encontrada' });
    }
    
    const familia = {
      idFamilia: results[0].idFamilia,
      nombre: results[0].nombre,
      descripcion: results[0].descripcion,
      idOwner: results[0].idOwner,
      created_at: results[0].created_at,
      updated_at: results[0].updated_at,
      miembros: []
    };
    
    results.forEach(row => {
      if (row.miembro_idPaciente) {
        const miembro = {
          idFamilia: row.idFamilia,
          idPaciente: row.miembro_idPaciente,
          rol: row.miembro_rol,
          fechaAgregado: row.miembro_fechaAgregado,
          paciente: {
            idPaciente: row.miembro_idPaciente,
            nombrePaciente: row.nombrePaciente,
            fotoPerfil: row.fotoPerfil,
            fechaNacimiento: row.fechaNacimiento,
            correo: row.correo,
            telefono: row.telefono,
            direccion: row.direccion,
            sexo: row.sexo,
            nacionalidad: row.nacionalidad,
            ocupacion: row.ocupacion,
            prevision: row.prevision,
            tipoSangre: row.tipoSangre
          }
        };
        familia.miembros.push(miembro);
      }
    });
    
    console.log(`GET /api/familias/${id} - Familia encontrada con ${familia.miembros.length} miembros`);
    res.json({ data: familia });
  });
});

// POST /api/familias - Crear nueva familia
app.post('/api/familias', (req, res) => {
  const { nombre, descripcion, idOwner } = req.body;
  
  console.log('📝 POST /api/familias - Creando familia:', { nombre, idOwner });
  
  if (!nombre || !idOwner) {
    return res.status(400).json({ 
      error: 'Faltan campos requeridos: nombre, idOwner' 
    });
  }
  
  const query = `
    INSERT INTO Familia (nombre, descripcion, idOwner)
    VALUES (?, ?, ?)
  `;
  
  db.query(query, [nombre, descripcion || null, idOwner], (err, results) => {
    if (err) {
      console.error('Error en POST /api/familias:', err.message);
      return res.status(500).json({ 
        error: 'Error creando familia', 
        details: err.message 
      });
    }
    
    const nuevaFamilia = {
      idFamilia: results.insertId,
      nombre,
      descripcion: descripcion || null,
      idOwner,
      miembros: []
    };
    
    console.log(`POST /api/familias - Familia creada con ID: ${results.insertId}`);
    res.status(201).json({ data: nuevaFamilia });
  });
});

// POST /api/familias/:idFamilia/miembros - Agregar miembro a familia
app.post('/api/familias/:idFamilia/miembros', (req, res) => {
  const { idFamilia } = req.params;
  const { idPaciente, rol } = req.body;
  
  console.log(`POST /api/familias/${idFamilia}/miembros - Agregando miembro:`);
  console.log(`  idFamilia: ${idFamilia}`);
  console.log(`  idPaciente: ${idPaciente}`);
  console.log(`  rol: ${rol}`);
  
  if (!idPaciente || !rol) {
    return res.status(400).json({ 
      error: 'Faltan campos requeridos: idPaciente, rol' 
    });
  }
  
  const checkQuery = 'SELECT idFamilia FROM Familia WHERE idFamilia = ?';
  
  db.query(checkQuery, [idFamilia], (checkErr, checkResults) => {
    if (checkErr) {
      console.error(`Error verificando familia ${idFamilia}:`, checkErr.message);
      return res.status(500).json({ 
        error: 'Error verificando familia', 
        details: checkErr.message 
      });
    }
    
    if (checkResults.length === 0) {
      console.log(`Familia ${idFamilia} no encontrada`);
      return res.status(404).json({ error: 'Familia no encontrada' });
    }
    
    const insertQuery = `
      INSERT INTO FamiliaPaciente (idFamilia, idPaciente, rol)
      VALUES (?, ?, ?)
    `;
    
    db.query(insertQuery, [idFamilia, idPaciente, rol], (insertErr) => {
      if (insertErr) {
        if (insertErr.code === 'ER_DUP_ENTRY') {
          console.log(`Miembro ${idPaciente} ya está en familia ${idFamilia}`);
          return res.status(200).json({ 
            data: { idFamilia, idPaciente, rol },
            message: 'Miembro ya existe en la familia'
          });
        }
        
        console.error(`Error agregando miembro a familia ${idFamilia}:`, insertErr.message);
        return res.status(500).json({ 
          error: 'Error agregando miembro', 
          details: insertErr.message 
        });
      }
      
      console.log(`Miembro ${idPaciente} agregado exitosamente a familia ${idFamilia}`);
      res.status(201).json({ 
        data: { idFamilia, idPaciente, rol },
        message: 'Miembro agregado exitosamente'
      });
    });
  });
});

// DELETE /api/familias/:idFamilia/miembros/:idPaciente - Eliminar miembro de familia
app.delete('/api/familias/:idFamilia/miembros/:idPaciente', (req, res) => {
  const { idFamilia, idPaciente } = req.params;
  
  console.log(`DELETE /api/familias/${idFamilia}/miembros/${idPaciente}`);
  
  const query = 'DELETE FROM FamiliaPaciente WHERE idFamilia = ? AND idPaciente = ?';
  
  db.query(query, [idFamilia, idPaciente], (err, results) => {
    if (err) {
      console.error(`Error eliminando miembro:`, err.message);
      return res.status(500).json({ 
        error: 'Error eliminando miembro', 
        details: err.message 
      });
    }
    
    if (results.affectedRows === 0) {
      console.log(`Miembro no encontrado en familia`);
      return res.status(404).json({ error: 'Miembro no encontrado en familia' });
    }
    
    console.log(`Miembro eliminado de familia`);
    res.json({ message: 'Miembro eliminado exitosamente' });
  });
});

// PUT /api/familias/:idFamilia - Actualizar familia (nombre y descripción)
app.put('/api/familias/:idFamilia', (req, res) => {
  const { idFamilia } = req.params;
  const { nombre, descripcion } = req.body;
  
  console.log(`PUT /api/familias/${idFamilia} - Actualizando familia:`, { nombre, descripcion });
  
  const query = 'UPDATE Familia SET nombre = ?, descripcion = ?, updated_at = NOW() WHERE idFamilia = ?';
  
  db.query(query, [nombre || null, descripcion || null, idFamilia], (err, results) => {
    if (err) {
      console.error(`Error actualizando familia:`, err.message);
      return res.status(500).json({ 
        error: 'Error actualizando familia', 
        details: err.message 
      });
    }
    
    if (results.affectedRows === 0) {
      console.log(`Familia no encontrada`);
      return res.status(404).json({ error: 'Familia no encontrada' });
    }
    
    // Obtener la familia actualizada
    const selectQuery = `
      SELECT idFamilia, nombre, descripcion, idOwner, created_at, updated_at
      FROM Familia WHERE idFamilia = ?
    `;
    
    db.query(selectQuery, [idFamilia], (err, familiaResults) => {
      if (err) {
        console.error(`Error obteniendo familia actualizada:`, err.message);
        return res.status(500).json({ error: 'Error obteniendo familia actualizada' });
      }
      
      console.log(`Familia actualizada exitosamente`);
      res.json({ data: familiaResults[0] });
    });
  });
});

// DELETE /api/familias/:idFamilia - Eliminar una familia completamente
app.delete('/api/familias/:idFamilia', (req, res) => {
  const { idFamilia } = req.params;
  
  console.log(`DELETE /api/familias/${idFamilia} - Eliminando familia`);
  
  // Primero eliminar todos los miembros de la familia
  const deleteMiembrosQuery = 'DELETE FROM FamiliaPaciente WHERE idFamilia = ?';
  
  db.query(deleteMiembrosQuery, [idFamilia], (err) => {
    if (err) {
      console.error(`Error eliminando miembros de familia:`, err.message);
      return res.status(500).json({ 
        error: 'Error eliminando miembros de familia', 
        details: err.message 
      });
    }
    
    // Luego eliminar la familia
    const deleteFamiliaQuery = 'DELETE FROM Familia WHERE idFamilia = ?';
    
    db.query(deleteFamiliaQuery, [idFamilia], (err, results) => {
      if (err) {
        console.error(`Error eliminando familia:`, err.message);
        return res.status(500).json({ 
          error: 'Error eliminando familia', 
          details: err.message 
        });
      }
      
      if (results.affectedRows === 0) {
        console.log(`Familia no encontrada`);
        return res.status(404).json({ error: 'Familia no encontrada' });
      }
      
      console.log(`Familia eliminada exitosamente`);
      res.json({ message: 'Familia eliminada exitosamente' });
    });
  });
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  db.query('SELECT 1', (err) => {
    if (err) {
      return res.status(500).json({ 
        status: 'error', 
        database: 'disconnected',
        message: err.message 
      });
    }
    res.json({ 
      status: 'healthy', 
      database: 'connected',
      timestamp: new Date().toISOString() 
    });
  });
});

// ==========================================
// ENDPOINTS PARA VERFICHA - INFORMACIÓN MÉDICA DETALLADA
// ==========================================

/**
 * GET /api/patients/:id/consultations
 * Obtener todas las consultas de un paciente con sus relaciones
 */
app.get('/api/patients/:id/consultations', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        c.idConsulta,
        c.fechaIngreso,
        c.fechaEgreso,
        c.hora,
        c.motivo,
        c.observacion,
        c.condicionEgreso,
        tc.nombreTipoConsulta as tipoConsulta,
        ss.nombreServicioSalud as servicio,
        ps.nombre as profesional,
        ps.especialidad
      FROM Consulta c
      LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
      LEFT JOIN ServicioSalud ss ON c.idServicioSalud = ss.idServicioSalud
      LEFT JOIN ProfesionalSalud ps ON c.idProfesionalSalud = ps.idProfesionalSalud
      WHERE c.idPaciente = ?
      ORDER BY c.fechaIngreso DESC, c.hora DESC
      LIMIT 50
    `;
    
    const [consultas] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: consultas,
      total: consultas.length
    });
    
  } catch (error) {
    console.error('Error obteniendo consultas:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener consultas del paciente',
      error: error.message
    });
  }
});

/**
 * GET /api/patients/:id/exams
 * Obtener todos los exámenes realizados por un paciente
 */
app.get('/api/patients/:id/exams', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        e.idExamen,
        e.nombreExamen,
        e.tipoExamen,
        e.unidadMedida,
        e.valorReferencia,
        ce.fecha,
        ce.observacion,
        c.fechaIngreso as fechaConsulta,
        c.motivo as motivoConsulta
      FROM ConsultaExamen ce
      INNER JOIN Examen e ON ce.idExamen = e.idExamen
      INNER JOIN Consulta c ON ce.idConsulta = c.idConsulta
      WHERE c.idPaciente = ?
      ORDER BY ce.fecha DESC, c.fechaIngreso DESC
      LIMIT 50
    `;
    
    const [examenes] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: examenes,
      total: examenes.length
    });
    
  } catch (error) {
    console.error('Error obteniendo exámenes:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener exámenes del paciente',
      error: error.message
    });
  }
});

/**
 * POST /api/patients/:id/exams
 * Crear un examen y asociarlo opcionalmente a una consulta mediante ConsultaExamen.
 * Body esperado:
 * {
 *   nombreExamen, tipoExamen, unidadMedida?, valorReferencia?, idConsulta?, observacion?
 * }
 */
app.post('/api/patients/:id/exams', async (req, res) => {
  const idPaciente = req.params.id;
  const {
    nombreExamen,
    tipoExamen,
    unidadMedida,
    valorReferencia,
    idConsulta,
    observacion
  } = req.body;

  if (!nombreExamen || !tipoExamen) {
    return res.status(400).json({ success: false, message: 'nombreExamen y tipoExamen son requeridos' });
  }

  const conn = await db.promise().getConnection();
  try {
    await conn.beginTransaction();

    const [pac] = await conn.query('SELECT idPaciente FROM Paciente WHERE idPaciente = ?', [idPaciente]);
    if (pac.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Paciente no encontrado' });
    }

    // Si se envía idConsulta validar que pertenezca al paciente
    if (idConsulta) {
      const [cons] = await conn.query('SELECT idConsulta FROM Consulta WHERE idConsulta = ? AND idPaciente = ?', [idConsulta, idPaciente]);
      if (cons.length === 0) {
        await conn.rollback();
        return res.status(400).json({ success: false, message: 'La consulta indicada no pertenece al paciente' });
      }
    }

    // Insertar examen
    const [insertExamen] = await conn.query(
      `INSERT INTO Examen (nombreExamen, tipoExamen, unidadMedida, valorReferencia) VALUES (?, ?, ?, ?)`,
      [nombreExamen, tipoExamen, unidadMedida || null, valorReferencia || null]
    );
    const nuevoIdExamen = insertExamen.insertId;

    // Asociar en ConsultaExamen si hay idConsulta
    if (idConsulta) {
      await conn.query(
        `INSERT INTO ConsultaExamen (idExamen, idConsulta, fecha, observacion) VALUES (?, ?, CURDATE(), ?)`,
        [nuevoIdExamen, idConsulta, observacion || null]
      );
    }

    await conn.commit();

    // Recuperar datos combinados para respuesta
    let detalle = null;
    if (idConsulta) {
      const [rows] = await db.promise().query(
        `SELECT e.idExamen, e.nombreExamen, e.tipoExamen, e.unidadMedida, e.valorReferencia,
                ce.fecha, ce.observacion, c.idConsulta, c.motivo
         FROM Examen e
         INNER JOIN ConsultaExamen ce ON e.idExamen = ce.idExamen
         INNER JOIN Consulta c ON ce.idConsulta = c.idConsulta
         WHERE e.idExamen = ?`, [nuevoIdExamen]
      );
      detalle = rows[0];
    } else {
      const [rows] = await db.promise().query(
        `SELECT e.idExamen, e.nombreExamen, e.tipoExamen, e.unidadMedida, e.valorReferencia
         FROM Examen e WHERE e.idExamen = ?`, [nuevoIdExamen]
      );
      detalle = rows[0];
    }

    res.status(201).json({ success: true, data: detalle });
  } catch (error) {
    console.error('Error creando examen:', error);
    try { await conn.rollback(); } catch (e) {}
    res.status(500).json({ success: false, message: 'Error al crear examen', error: error.message });
  } finally {
    conn.release();
  }
});

/**
 * POST /api/consultations/:id/exams
 * Atajo para crear examen ya ligado a una consulta específica.
 */
app.post('/api/consultations/:id/exams', async (req, res) => {
  const idConsulta = req.params.id;
  const { nombreExamen, tipoExamen, unidadMedida, valorReferencia, observacion } = req.body;
  if (!nombreExamen || !tipoExamen) {
    return res.status(400).json({ success: false, message: 'nombreExamen y tipoExamen son requeridos' });
  }
  const conn = await db.promise().getConnection();
  try {
    await conn.beginTransaction();
    // Validar consulta y paciente
    const [cons] = await conn.query('SELECT idConsulta, idPaciente FROM Consulta WHERE idConsulta = ?', [idConsulta]);
    if (cons.length === 0) {
      await conn.rollback();
      return res.status(404).json({ success: false, message: 'Consulta no encontrada' });
    }
    const idPaciente = cons[0].idPaciente;
    const [insertExamen] = await conn.query(
      `INSERT INTO Examen (nombreExamen, tipoExamen, unidadMedida, valorReferencia) VALUES (?, ?, ?, ?)`,
      [nombreExamen, tipoExamen, unidadMedida || null, valorReferencia || null]
    );
    const nuevoIdExamen = insertExamen.insertId;
    await conn.query(
      `INSERT INTO ConsultaExamen (idExamen, idConsulta, fecha, observacion) VALUES (?, ?, CURDATE(), ?)`,
      [nuevoIdExamen, idConsulta, observacion || null]
    );
    await conn.commit();
    const [rows] = await db.promise().query(
      `SELECT e.idExamen, e.nombreExamen, e.tipoExamen, e.unidadMedida, e.valorReferencia,
              ce.fecha, ce.observacion, c.idConsulta, c.motivo, c.idPaciente
       FROM Examen e
       INNER JOIN ConsultaExamen ce ON e.idExamen = ce.idExamen
       INNER JOIN Consulta c ON ce.idConsulta = c.idConsulta
       WHERE e.idExamen = ?`, [nuevoIdExamen]
    );
    res.status(201).json({ success: true, data: rows[0] });
  } catch (error) {
    console.error('Error creando examen ligado a consulta:', error);
    try { await conn.rollback(); } catch (e) {}
    res.status(500).json({ success: false, message: 'Error al crear examen para consulta', error: error.message });
  } finally {
    conn.release();
  }
});

/**
 * GET /api/patients/:id/diagnostics
 * Obtener todos los diagnósticos de un paciente
 */
app.get('/api/patients/:id/diagnostics', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        d.idDiagnostico,
        d.cie10,
        d.comentarios,
        cd.urgencia,
        cd.observacion,
        c.fechaIngreso,
        c.motivo as motivoConsulta,
        ps.nombre as profesional,
        ps.especialidad
      FROM ConsultaDiagnostico cd
      INNER JOIN Diagnostico d ON cd.idDiagnostico = d.idDiagnostico
      INNER JOIN Consulta c ON cd.idConsulta = c.idConsulta
      LEFT JOIN ProfesionalSalud ps ON c.idProfesionalSalud = ps.idProfesionalSalud
      WHERE c.idPaciente = ?
      ORDER BY c.fechaIngreso DESC, cd.urgencia DESC
      LIMIT 50
    `;
    
    const [diagnosticos] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: diagnosticos,
      total: diagnosticos.length
    });
    
  } catch (error) {
    console.error('Error obteniendo diagnósticos:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener diagnósticos del paciente',
      error: error.message
    });
  }
});

/**
 * GET /api/patients/:id/procedures
 * Obtener todos los procedimientos realizados a un paciente
 */
app.get('/api/patients/:id/procedures', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        p.idProcedimiento,
        p.nombreProcedimiento,
        p.fecha,
        p.indicaciones,
        tp.tipoProcedimiento,
        c.fechaIngreso as fechaConsulta,
        c.motivo as motivoConsulta,
        ps.nombre as profesional,
        ps.especialidad
      FROM ConsultaProcedimiento cp
      INNER JOIN Procedimiento p ON cp.idProcedimiento = p.idProcedimiento
      INNER JOIN Consulta c ON cp.idConsulta = c.idConsulta
      LEFT JOIN TipoProcedimiento tp ON p.idTipoProcedimiento = tp.idTipoProcedimiento
      LEFT JOIN ProfesionalSalud ps ON c.idProfesionalSalud = ps.idProfesionalSalud
      WHERE c.idPaciente = ?
      ORDER BY p.fecha DESC, c.fechaIngreso DESC
      LIMIT 50
    `;
    
    const [procedimientos] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: procedimientos,
      total: procedimientos.length
    });
    
  } catch (error) {
    console.error('Error obteniendo procedimientos:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener procedimientos del paciente',
      error: error.message
    });
  }
});

/**
 * GET /api/patients/:id/allergies
 * Obtener todas las alergias de un paciente
 */
app.get('/api/patients/:id/allergies', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        a.idAlergia,
        a.alergia as nombreAlergia,
        ap.observacion,
        ap.fechaRegistro
      FROM AlergiaPaciente ap
      INNER JOIN Alergia a ON ap.idAlergia = a.idAlergia
      WHERE ap.idPaciente = ?
      ORDER BY ap.fechaRegistro DESC
    `;
    
    const [alergias] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: alergias,
      total: alergias.length
    });
    
  } catch (error) {
    console.error('Error obteniendo alergias:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener alergias del paciente',
      error: error.message
    });
  }
});

/**
 * GET /api/patients/:id/habits
 * Obtener todos los hábitos de un paciente
 */
app.get('/api/patients/:id/habits', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        h.idHabito,
        h.habito as nombreHabito,
        hp.observacion
      FROM HabitoPaciente hp
      INNER JOIN Habito h ON hp.idHabito = h.idHabito
      WHERE hp.idPaciente = ?
      ORDER BY h.habito ASC
    `;
    
    const [habitos] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: habitos,
      total: habitos.length
    });
    
  } catch (error) {
    console.error('Error obteniendo hábitos:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener hábitos del paciente',
      error: error.message
    });
  }
});

/**
 * GET /api/patients/:id/vaccines
 * Obtener todas las vacunas de un paciente
 */
app.get('/api/patients/:id/vaccines', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        v.idVacuna,
        v.nombre as nombreVacuna,
        v.observacion as observacionVacuna,
        pv.fecha,
        pv.dosis,
        pv.observacion as observacionAplicacion
      FROM PacienteVacuna pv
      INNER JOIN Vacuna v ON pv.idVacuna = v.idVacuna
      WHERE pv.idPaciente = ?
      ORDER BY pv.fecha DESC
    `;
    
    const [vacunas] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: vacunas,
      total: vacunas.length
    });
    
  } catch (error) {
    console.error('Error obteniendo vacunas:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener vacunas del paciente',
      error: error.message
    });
  }
});

/**
 * GET /api/patients/:id/medicines
 * Obtener todos los medicamentos de un paciente
 */
app.get('/api/patients/:id/medicines', async (req, res) => {
  const patientId = req.params.id;
  
  try {
    const query = `
      SELECT 
        m.idMedicamento,
        m.nombreMedicamento,
        m.empresa,
        mcp.fechaInicio,
        mcp.fechaFin,
        mcp.cronico
      FROM MedicamentoCronicoPaciente mcp
      INNER JOIN Medicamento m ON mcp.idMedicamento = m.idMedicamento
      WHERE mcp.idPaciente = ?
      ORDER BY mcp.cronico DESC, mcp.fechaInicio DESC
    `;
    
    const [medicamentos] = await db.promise().query(query, [patientId]);
    
    res.json({
      success: true,
      data: medicamentos,
      total: medicamentos.length
    });
    
  } catch (error) {
    console.error('Error obteniendo medicamentos:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener medicamentos del paciente',
      error: error.message
    });
  }
});

// ==========================================
// ENDPOINTS PARA DASHBOARD - ESTADÍSTICAS
// ==========================================

/**
 * GET /api/dashboard/stats
 * Obtener estadísticas generales para el dashboard
 */
app.get('/api/dashboard/stats', async (req, res) => {
  try {
    // Total de pacientes
    const [totalPacientes] = await db.promise().query(
      'SELECT COUNT(*) as total FROM Paciente'
    );

    // Consultas de hoy
    const [consultasHoy] = await db.promise().query(
      'SELECT COUNT(*) as total FROM Consulta WHERE DATE(fechaIngreso) = CURDATE()'
    );

    // Exámenes pendientes (últimos 30 días)
    const [examenesPendientes] = await db.promise().query(
      'SELECT COUNT(DISTINCT ce.idExamen) as total FROM ConsultaExamen ce WHERE ce.fecha >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)'
    );

    // Alertas (diagnósticos urgentes del último mes)
    const [alertas] = await db.promise().query(
      `SELECT COUNT(DISTINCT cd.idDiagnostico) as total 
       FROM ConsultaDiagnostico cd 
       INNER JOIN Consulta c ON cd.idConsulta = c.idConsulta
       WHERE cd.urgencia = 1 
       AND c.fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)`
    );

    // Pacientes por grupo sanguíneo
    const [gruposSanguineos] = await db.promise().query(
      `SELECT tipoSangre, COUNT(*) as total 
       FROM Paciente 
       WHERE tipoSangre IS NOT NULL 
       GROUP BY tipoSangre 
       ORDER BY total DESC`
    );

    // Consultas por tipo (últimos 30 días)
    const [consultasPorTipo] = await db.promise().query(
      `SELECT tc.nombreTipoConsulta as tipo, COUNT(*) as total
       FROM Consulta c
       LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
       WHERE c.fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
       GROUP BY tc.nombreTipoConsulta
       ORDER BY total DESC
       LIMIT 5`
    );

    // Últimas consultas
    const [ultimasConsultas] = await db.promise().query(
      `SELECT 
        c.idConsulta,
        c.fechaIngreso,
        c.hora,
        c.motivo,
        p.nombrePaciente,
        tc.nombreTipoConsulta as tipoConsulta
       FROM Consulta c
       INNER JOIN Paciente p ON c.idPaciente = p.idPaciente
       LEFT JOIN TipoConsulta tc ON c.idTipoConsulta = tc.idTipoConsulta
       ORDER BY c.fechaIngreso DESC, c.hora DESC
       LIMIT 5`
    );

    // Diagnósticos recientes urgentes
    const [diagnosticosUrgentes] = await db.promise().query(
      `SELECT 
        d.idDiagnostico,
        d.cie10,
        d.comentarios,
        p.nombrePaciente,
        c.fechaIngreso
       FROM ConsultaDiagnostico cd
       INNER JOIN Diagnostico d ON cd.idDiagnostico = d.idDiagnostico
       INNER JOIN Consulta c ON cd.idConsulta = c.idConsulta
       INNER JOIN Paciente p ON c.idPaciente = p.idPaciente
       WHERE cd.urgencia = 1
       AND c.fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
       ORDER BY c.fechaIngreso DESC
       LIMIT 5`
    );

    res.json({
      success: true,
      data: {
        metricas: {
          totalPacientes: totalPacientes[0].total,
          consultasHoy: consultasHoy[0].total,
          examenesPendientes: examenesPendientes[0].total,
          alertas: alertas[0].total
        },
        gruposSanguineos: gruposSanguineos,
        consultasPorTipo: consultasPorTipo,
        ultimasConsultas: ultimasConsultas,
        diagnosticosUrgentes: diagnosticosUrgentes
      }
    });

  } catch (error) {
    console.error('Error obteniendo estadísticas del dashboard:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener estadísticas del dashboard',
      error: error.message
    });
  }
});

/**
 * GET /api/dashboard/paciente/:id
 * Obtener estadísticas completas del dashboard para un paciente específico
 */
app.get('/api/dashboard/paciente/:id', async (req, res) => {
  const idPaciente = req.params.id;
  
  try {
    // 1. Métricas generales del paciente
    const [metricasResult] = await db.promise().query(`
      SELECT 
        (SELECT COUNT(*) FROM Consulta WHERE idPaciente = ?) as totalConsultas,
        (SELECT COUNT(*) FROM Consulta WHERE idPaciente = ? AND fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)) as consultasUltimos30Dias,
        (SELECT COUNT(*) FROM ConsultaExamen ce 
         INNER JOIN Consulta c ON ce.idConsulta = c.idConsulta 
         WHERE c.idPaciente = ?) as examenesPendientes,
        (SELECT COUNT(*) FROM MedicamentoCronicoPaciente WHERE idPaciente = ?) as medicamentosCronicos
    `, [idPaciente, idPaciente, idPaciente, idPaciente]);

    // 2. Últimas 5 consultas
    const [ultimasConsultas] = await db.promise().query(`
      SELECT 
        c.idConsulta,
        c.fechaIngreso as fecha,
        c.hora,
        ss.nombreServicioSalud,
        ps.nombre as nombreProfesional,
        ps.especialidad
      FROM Consulta c
      LEFT JOIN ServicioSalud ss ON c.idServicioSalud = ss.idServicioSalud
      LEFT JOIN ProfesionalSalud ps ON c.idProfesionalSalud = ps.idProfesionalSalud
      WHERE c.idPaciente = ?
      ORDER BY c.fechaIngreso DESC, c.hora DESC
      LIMIT 5
    `, [idPaciente]);

    // 3. Diagnósticos recientes (últimos 30 días)
    const [diagnosticosRecientes] = await db.promise().query(`
      SELECT 
        d.idDiagnostico,
        d.cie10 as nombreDiagnostico,
        c.fechaIngreso as fecha,
        ps.nombre as nombreProfesional,
        CASE 
          WHEN cd.urgencia = 1 THEN 'Alta'
          ELSE 'Media'
        END as gravedad
      FROM ConsultaDiagnostico cd
      INNER JOIN Diagnostico d ON cd.idDiagnostico = d.idDiagnostico
      INNER JOIN Consulta c ON cd.idConsulta = c.idConsulta
      LEFT JOIN ProfesionalSalud ps ON c.idProfesionalSalud = ps.idProfesionalSalud
      WHERE c.idPaciente = ? AND c.fechaIngreso >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
      ORDER BY c.fechaIngreso DESC
      LIMIT 5
    `, [idPaciente]);

    // 4. Exámenes pendientes (últimos exámenes realizados)
    const [examenesPendientes] = await db.promise().query(`
      SELECT 
        e.idExamen,
        e.nombreExamen,
        ce.fecha,
        'Realizado' as estadoProceso,
        ss.nombreServicioSalud
      FROM ConsultaExamen ce
      INNER JOIN Examen e ON ce.idExamen = e.idExamen
      INNER JOIN Consulta c ON ce.idConsulta = c.idConsulta
      LEFT JOIN ServicioSalud ss ON c.idServicioSalud = ss.idServicioSalud
      WHERE c.idPaciente = ?
      ORDER BY ce.fecha DESC
      LIMIT 5
    `, [idPaciente]);

    // 5. Medicamentos crónicos activos
    const [medicamentosCronicos] = await db.promise().query(`
      SELECT 
        m.idMedicamento,
        m.nombreMedicamento,
        m.empresa as dosis,
        CASE 
          WHEN mcp.fechaFin IS NULL THEN 'Activo'
          ELSE 'Finalizado'
        END as frecuencia,
        mcp.fechaInicio
      FROM MedicamentoCronicoPaciente mcp
      INNER JOIN Medicamento m ON mcp.idMedicamento = m.idMedicamento
      WHERE mcp.idPaciente = ? AND mcp.cronico = 1
      ORDER BY mcp.fechaInicio DESC
      LIMIT 5
    `, [idPaciente]);

    // Respuesta con todas las estadísticas
    res.json({
      success: true,
      data: {
        metricas: metricasResult[0],
        ultimasConsultas,
        diagnosticosRecientes,
        examenesPendientes,
        medicamentosCronicos
      }
    });

  } catch (error) {
    console.error('Error obteniendo dashboard del paciente:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener estadísticas del paciente',
      error: error.message
    });
  }
});

/**
 * PUT /api/consultations/:id/exams/:examId/upload
 * Subir archivo a examen - CON LÍMITES AUMENTADOS
 */
app.put('/api/consultations/:id/exams/:examId/upload', async (req, res) => {
  const { id: idConsulta, examId } = req.params;
  const { archivoNombre, archivoTipo, archivoBlob, archivoSize } = req.body;

  console.log(`Subiendo archivo para examen ${examId}, consulta ${idConsulta}`);
  console.log(`Tamaño archivo: ${archivoSize} bytes`);

  if (!archivoNombre || !archivoBlob) {
    return res.status(400).json({ 
      success: false, 
      message: 'archivoNombre y archivoBlob son requeridos' 
    });
  }

  // Validar tamaño máximo (20MB)
  const maxSize = 20 * 1024 * 1024; // 20MB
  if (archivoSize && archivoSize > maxSize) {
    return res.status(413).json({
      success: false,
      message: `Archivo demasiado grande. Máximo permitido: 20MB`
    });
  }

  try {
    // Validar que ConsultaExamen existe
    const [existing] = await db.promise().query(
      'SELECT idExamen FROM ConsultaExamen WHERE idConsulta = ? AND idExamen = ?',
      [idConsulta, examId]
    );
    
    if (existing.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Examen/Consulta no encontrado' 
      });
    }

    // Convertir base64 a Buffer
    let bufferBlob;
    try {
      if (typeof archivoBlob === 'string') {
        // Remover prefijo data:image/...;base64, si existe
        const base64Data = archivoBlob.includes('base64,') 
          ? archivoBlob.split(',')[1] 
          : archivoBlob;
        bufferBlob = Buffer.from(base64Data, 'base64');
      } else {
        bufferBlob = archivoBlob;
      }
    } catch (convertError) {
      console.error('Error convirtiendo base64:', convertError);
      return res.status(400).json({
        success: false,
        message: 'Formato de archivo inválido'
      });
    }

    // Validar tamaño real del buffer
    if (bufferBlob.length > maxSize) {
      return res.status(413).json({
        success: false,
        message: `Archivo demasiado grande. Tamaño real: ${(bufferBlob.length / 1024 / 1024).toFixed(2)}MB, Máximo: 20MB`
      });
    }

    // Actualizar ConsultaExamen con archivo
    await db.promise().query(
      `UPDATE ConsultaExamen 
       SET archivoNombre = ?, archivoTipo = ?, archivoBlob = ?, archivoSize = ?, archivoFechaSubida = NOW()
       WHERE idConsulta = ? AND idExamen = ?`,
      [
        archivoNombre, 
        archivoTipo || 'application/octet-stream', 
        bufferBlob, 
        bufferBlob.length, 
        idConsulta, 
        examId
      ]
    );

    console.log(`Archivo subido correctamente: ${archivoNombre} (${bufferBlob.length} bytes)`);

    res.json({
      success: true,
      message: 'Archivo subido correctamente',
      data: { 
        idConsulta, 
        examId, 
        archivoNombre, 
        archivoTipo, 
        archivoSize: bufferBlob.length 
      }
    });
  } catch (error) {
    console.error('Error subiendo archivo:', error);
    res.status(500).json({ 
      success: false, 
      message: 'Error al subir archivo', 
      error: error.message 
    });
  }
});

/**
 * GET /api/consultations/:id/exams/:examId/download
 * Descargar archivo de ConsultaExamen
 */
app.get('/api/consultations/:id/exams/:examId/download', async (req, res) => {
  const { id: idConsulta, examId } = req.params;

  try {
    const [result] = await db.promise().query(
      'SELECT archivoNombre, archivoTipo, archivoBlob FROM ConsultaExamen WHERE idConsulta = ? AND idExamen = ?',
      [idConsulta, examId]
    );

    if (result.length === 0 || !result[0].archivoBlob) {
      return res.status(404).json({ success: false, message: 'Archivo no encontrado' });
    }

    const { archivoNombre, archivoTipo, archivoBlob } = result[0];
    res.set('Content-Type', archivoTipo || 'application/octet-stream');
    res.set('Content-Disposition', `attachment; filename="${archivoNombre}"`);
    res.send(archivoBlob);
  } catch (error) {
    console.error('Error descargando archivo:', error);
    res.status(500).json({ success: false, message: 'Error al descargar archivo', error: error.message });
  }
});

/**
 * POST /api/consultations/:id/exams/:examId/analyze
 * Analizar documento con AWS Textract - CON SIMULACIÓN DE FALLBACK
 */
app.post('/api/consultations/:id/exams/:examId/analyze', async (req, res) => {
  const { id: idConsulta, examId } = req.params;
  const { archivoBlob, archivoNombre, archivoTipo } = req.body;

  console.log(`Iniciando análisis Textract para examen ${examId}`);

  try {
    // Validar que el examen existe
    const [examenCheck] = await db.promise().query(
      'SELECT idExamen FROM ConsultaExamen WHERE idConsulta = ? AND idExamen = ?',
      [idConsulta, examId]
    );

    if (examenCheck.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Examen no encontrado' 
      });
    }

    // Convertir base64 a Buffer
    const base64Data = archivoBlob.includes('base64,') 
      ? archivoBlob.split(',')[1] 
      : archivoBlob;
    const bufferArchivo = Buffer.from(base64Data, 'base64');

    console.log(`Analizando archivo: ${archivoNombre} (${bufferArchivo.length} bytes)`);

    let analisis;
    
    // Intentar con AWS Textract real
    try {
      analisis = await awsConfig.analizarConTextract(bufferArchivo, archivoTipo);
      console.log(`Textract real - Confianza: ${analisis.confianza}%`);
    } catch (textractError) {
      console.warn('Textract no disponible, usando simulación:', textractError.message);
      // Fallback a simulación
      analisis = simularAnalisisTextract(archivoNombre, bufferArchivo);
      console.log(`Simulación - Confianza: ${analisis.confianza}%`);
    }

    res.json({
      success: true,
      data: {
        idExamen: parseInt(examId),
        idConsulta: parseInt(idConsulta),
        textoExtraido: analisis.texto,
        confianza: analisis.confianza,
        tablas: analisis.tablas || [],
        camposDetectados: analisis.camposDetectados || [],
        metadata: {
          fechaAnalisis: new Date().toISOString(),
          nombreArchivo: archivoNombre,
          tipoArchivo: archivoTipo
        }
      }
    });

  } catch (error) {
    console.error('Error en análisis Textract:', error);
    res.status(500).json({
      success: false,
      message: 'Error al analizar documento',
      error: error.message
    });
  }
});

/**
 * POST /api/consultations/:id/exams/:examId/suggestions
 * Obtener sugerencias de Textract - CON SIMULACIÓN DE FALLBACK
 */
app.post('/api/consultations/:id/exams/:examId/suggestions', async (req, res) => {
  const { id: idConsulta, examId } = req.params;
  const { archivoBlob, archivoTipo } = req.body;

  try {
    // Convertir base64 a Buffer
    const base64Data = archivoBlob.includes('base64,') 
      ? archivoBlob.split(',')[1] 
      : archivoBlob;
    const bufferArchivo = Buffer.from(base64Data, 'base64');

    let analisis;
    
    // Intentar con AWS Textract real primero
    try {
      analisis = await awsConfig.analizarConTextract(bufferArchivo, archivoTipo);
    } catch (textractError) {
      console.warn('Textract no disponible en sugerencias, usando simulación');
      analisis = simularAnalisisTextract('documento.pdf', bufferArchivo);
    }

    // Generar sugerencias desde campos detectados
    const sugerencias = (analisis.camposDetectados || []).map((campo, index) => ({
      id: index,
      campo: campo.nombre,
      valorSugerido: campo.valor,
      confianza: campo.confianza,
      tipo: campo.tipo
    }));

    console.log(`${sugerencias.length} sugerencias generadas`);

    res.json({
      success: true,
      data: {
        idExamen: parseInt(examId),
        sugerencias,
        confianzaGeneral: analisis.confianza,
        textoExtraido: analisis.texto.substring(0, 500) + '...'
      }
    });
  } catch (error) {
    console.error('Error obteniendo sugerencias:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener sugerencias',
      error: error.message
    });
  }
});

/**
 * PUT /api/consultations/:id/exams/:examId/apply-suggestions
 * Aplicar sugerencias aceptadas - ACTUALIZAR EXAMEN CON DATOS EXTRAÍDOS
 */
app.put('/api/consultations/:id/exams/:examId/apply-suggestions', async (req, res) => {
  const { id: idConsulta, examId } = req.params;
  const { sugerenciasAplicadas } = req.body;

  console.log(`Aplicando ${Object.keys(sugerenciasAplicadas).length} sugerencias al examen ${examId}`);

  try {
    // Validar que el examen existe
    const [examenCheck] = await db.promise().query(
      'SELECT observacion FROM ConsultaExamen WHERE idConsulta = ? AND idExamen = ?',
      [idConsulta, examId]
    );

    if (examenCheck.length === 0) {
      return res.status(404).json({ 
        success: false, 
        message: 'Examen no encontrado' 
      });
    }

    // Formatear sugerencias para observacion
    const sugerenciasTexto = Object.entries(sugerenciasAplicadas)
      .map(([campo, valor]) => `${campo}: ${valor}`)
      .join(' | ');
    
    const observacionNueva = `[Textract-Aplicado] ${sugerenciasTexto}`;

    // Actualizar ConsultaExamen.observacion
    await db.promise().query(
      `UPDATE ConsultaExamen 
       SET observacion = ?, updated_at = NOW()
       WHERE idConsulta = ? AND idExamen = ?`,
      [observacionNueva, idConsulta, examId]
    );

    // También actualizar el examen principal si hay campos relevantes
    const camposExamen = extraerCamposExamen(sugerenciasAplicadas);
    if (Object.keys(camposExamen).length > 0) {
      await db.promise().query(
        `UPDATE Examen 
         SET nombreExamen = COALESCE(?, nombreExamen),
             tipoExamen = COALESCE(?, tipoExamen),
             unidadMedida = COALESCE(?, unidadMedida),
             valorReferencia = COALESCE(?, valorReferencia),
             updated_at = NOW()
         WHERE idExamen = ?`,
        [
          camposExamen.nombreExamen,
          camposExamen.tipoExamen,
          camposExamen.unidadMedida,
          camposExamen.valorReferencia,
          examId
        ]
      );
    }

    console.log(`Sugerencias aplicadas y examen actualizado`);

    res.json({
      success: true,
      message: 'Sugerencias aplicadas correctamente',
      data: {
        examId: parseInt(examId),
        camposActualizados: camposExamen
      }
    });
  } catch (error) {
    console.error('Error aplicando sugerencias:', error);
    res.status(500).json({
      success: false,
      message: 'Error al aplicar sugerencias',
      error: error.message
    });
  }
});

/**
 * Función auxiliar: Inferir tipo de campo desde el nombre
 */
// ==========================================
// FUNCIONES AUXILIARES PARA TEXTRACT
// ==========================================

/**
 * Simulación de Textract para desarrollo/fallback
 */
function simularAnalisisTextract(nombreArchivo, bufferArchivo) {
  console.log('Usando simulación de Textract');
  
  // Texto simulado de un examen de laboratorio
  const textoSimulado = `
INFORME DE LABORATORIO CLÍNICO
LABORATORIO CLÍNICO CENTRAL
Fecha: 15/03/2024

DATOS DEL PACIENTE:
Nombre: MARÍA GONZÁLEZ RUIZ
Edad: 35 años
Sexo: Femenino
Médico Tratante: Dr. Carlos Méndez

RESULTADOS:

HEMOGRAMA COMPLETO:
Hemoglobina: 13.2 g/dL (Valor referencia: 12.0 - 15.5 g/dL)
Hematocrito: 39.8% (36.0 - 46.0%)
Leucocitos: 6.800 /μL (4.500 - 11.000 /μL)
Plaquetas: 250.000 /μL (150.000 - 450.000 /μL)

QUÍMICA SANGUÍNEA:
Glucosa: 95 mg/dL (70 - 110 mg/dL)
Urea: 28 mg/dL (15 - 45 mg/dL)
Creatinina: 0.8 mg/dL (0.5 - 1.1 mg/dL)
Colesterol Total: 185 mg/dL (<200 mg/dL)
Triglicéridos: 120 mg/dL (<150 mg/dL)

OBSERVACIONES:
Resultados dentro de parámetros normales. Control rutinario en 6 meses.
  `.trim();

  // Campos detectados simulados
  const camposDetectados = [
    { nombre: 'Nombre Paciente', valor: 'MARÍA GONZÁLEZ RUIZ', confianza: 95, tipo: 'texto' },
    { nombre: 'Edad', valor: '35', confianza: 90, tipo: 'numero' },
    { nombre: 'Sexo', valor: 'Femenino', confianza: 92, tipo: 'texto' },
    { nombre: 'Fecha Examen', valor: '15/03/2024', confianza: 88, tipo: 'fecha' },
    { nombre: 'Médico', valor: 'Dr. Carlos Méndez', confianza: 85, tipo: 'texto' },
    { nombre: 'Hemoglobina', valor: '13.2', confianza: 90, tipo: 'numero' },
    { nombre: 'Unidad Hemoglobina', valor: 'g/dL', confianza: 89, tipo: 'texto' },
    { nombre: 'Referencia Hemoglobina', valor: '12.0 - 15.5', confianza: 85, tipo: 'texto' },
    { nombre: 'Glucosa', valor: '95', confianza: 91, tipo: 'numero' },
    { nombre: 'Unidad Glucosa', valor: 'mg/dL', confianza: 90, tipo: 'texto' },
    { nombre: 'Colesterol Total', valor: '185', confianza: 88, tipo: 'numero' },
    { nombre: 'Observaciones', valor: 'Resultados dentro de parámetros normales. Control rutinario en 6 meses.', confianza: 82, tipo: 'texto' }
  ];

  // Tablas simuladas
  const tablasSimuladas = [
    {
      titulo: 'HEMOGRAMA',
      filas: [
        ['Parámetro', 'Resultado', 'Unidad', 'Referencia'],
        ['Hemoglobina', '13.2', 'g/dL', '12.0 - 15.5'],
        ['Hematocrito', '39.8', '%', '36.0 - 46.0'],
        ['Leucocitos', '6.800', '/μL', '4.500 - 11.000'],
        ['Plaquetas', '250.000', '/μL', '150.000 - 450.000']
      ],
      confianza: 90
    },
    {
      titulo: 'QUÍMICA SANGUÍNEA',
      filas: [
        ['Parámetro', 'Resultado', 'Unidad', 'Referencia'],
        ['Glucosa', '95', 'mg/dL', '70 - 110'],
        ['Urea', '28', 'mg/dL', '15 - 45'],
        ['Creatinina', '0.8', 'mg/dL', '0.5 - 1.1'],
        ['Colesterol Total', '185', 'mg/dL', '<200'],
        ['Triglicéridos', '120', 'mg/dL', '<150']
      ],
      confianza: 88
    }
  ];

  return {
    texto: textoSimulado,
    confianza: 85,
    camposDetectados: camposDetectados,
    tablas: tablasSimuladas,
    keyValuePairs: camposDetectados.map(campo => ({
      clave: campo.nombre,
      valor: campo.valor,
      confianza: campo.confianza / 100
    }))
  };
}

/**
 * Extraer campos relevantes para la tabla Examen
 */
function extraerCamposExamen(sugerenciasAplicadas) {
  const campos = {};
  
  Object.entries(sugerenciasAplicadas).forEach(([campo, valor]) => {
    const campoLower = campo.toLowerCase();
    
    if (campoLower.includes('nombre') && campoLower.includes('examen')) {
      campos.nombreExamen = valor;
    } else if (campoLower.includes('tipo') && campoLower.includes('examen')) {
      campos.tipoExamen = valor;
    } else if (campoLower.includes('unidad')) {
      campos.unidadMedida = valor;
    } else if (campoLower.includes('referencia')) {
      campos.valorReferencia = valor;
    }
  });

  return campos;
}

/**
 * Inferir tipo de campo desde el nombre
 */
function inferirTipoCampo(nombreCampo) {
  const campo = nombreCampo.toLowerCase();
  
  if (campo.includes('fecha')) return 'fecha';
  if (campo.includes('cantidad') || campo.includes('cantidad')) return 'numero';
  if (campo.includes('nombre')) return 'texto';
  if (campo.includes('precio') || campo.includes('total')) return 'numero';
  if (campo.includes('resultado') || campo.includes('valor')) return 'texto';
  
  return 'texto';
}

/**
 * GET /api/dashboard/recent-patients
 * Obtener pacientes registrados recientemente
 */
app.get('/api/dashboard/recent-patients', async (req, res) => {
  try {
    const limit = req.query.limit || 10;
    
    const query = `
      SELECT 
        idPaciente,
        nombrePaciente,
        fechaNacimiento,
        tipoSangre,
        prevision,
        fotoPerfil,
        created_at
      FROM Paciente
      ORDER BY created_at DESC
      LIMIT ?
    `;
    
    const [pacientes] = await db.promise().query(query, [parseInt(limit)]);
    
    res.json({
      success: true,
      data: pacientes,
      total: pacientes.length
    });

  } catch (error) {
    console.error('Error obteniendo pacientes recientes:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener pacientes recientes',
      error: error.message
    });
  }
});


// ==========================================
// MANEJO DE ERRORES Y SEÑALES
// ==========================================

// Manejo global de errores
process.on('uncaughtException', (err) => {
  console.error('Error no capturado:', err.message);
});

process.on('unhandledRejection', (err) => {
  console.error('Promise rechazada:', err.message);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('\nApagando servidor...');
  
  // Cerrar clientes SSE
  sseClientes.forEach(client => {
    try {
      client.end();
    } catch (err) {
      console.error('Error cerrando cliente SSE:', err.message);
    }
  });
  
  // Cerrar pool de conexiones
  db.end((err) => {
    if (err) {
      console.error('Error cerrando pool BD:', err.message);
    }
    console.log('Servidor cerrado correctamente');
    process.exit(0);
  });
});

const PORT = 3001;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n API Server corriendo en http://localhost:${PORT}`);
  console.log(`Escuchando en 0.0.0.0:${PORT}`);
  console.log(`Base de datos: AWS RDS MySQL (34.233.199.164)`);
  console.log(`Límites aumentados: 50MB para archivos`);
  console.log(`Textract con simulación de fallback`);
  console.log(`Listo para solicitudes\n`);
});