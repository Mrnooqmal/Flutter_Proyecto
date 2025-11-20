const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const multer = require('multer');
const EventEmitter = require('events');
const eventEmitter = new EventEmitter();

let sseClientes = [];

const app = express();
app.use(cors());
app.use(express.json());

// Configurar multer para almacenar archivos en memoria
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 16 * 1024 * 1024, // 16MB máximo
  },
  fileFilter: (req, file, cb) => {
    // Aceptar solo PDFs e imágenes
    if (file.mimetype === 'application/pdf' || file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Solo se permiten archivos PDF e imágenes'));
    }
  }
});

const db = mysql.createConnection({
  host: 'localhost', //ip_publica_ec2 , remplazar cada que cambie
  // para conectarse luego remotamente: mysql -h [ip_publica_ec2] -u meditrack_user2 -p , y luego password: M3d!Track2025
  //"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -h 34.233.199.164 -u meditrack_user2 -p
  user: 'meditrack_user',
  password: 'PasswordSeguro123!',
  database: 'MediTrack'
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
  const { nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre, fotoPerfil } = req.body;
  
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
    (nombrePaciente, fotoPerfil, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;
  
  db.query(query, [
    nombrePaciente,
    fotoPerfil || null,
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
        fotoPerfil,
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

    // Si el correo no cambió, hacer UPDATE normal
    if (correo === correoActual || correo === null || correo === '') {
      console.log('>>> Correo no cambió o es nulo, procediendo con UPDATE normal');
      
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
      // Si el correo cambió, verificar que no exista en otro paciente
      console.log('>>> Correo cambió, verificando duplicado...');
      
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
// ENDPOINTS PARA FICHA MÉDICA DETALLADA
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

// GET /api/pacientes/:id/medicamentos-cronicos - Obtener medicamentos crónicos de un paciente
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
      console.error('Error obteniendo medicamentos crónicos:', err);
      return res.status(500).json({ error: 'Error del servidor' });
    }
    res.json(results);
  });
});

// GET /api/pacientes/:id/habitos - Obtener hábitos de un paciente
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

// GET /api/pacientes/:id/examenes - Obtener exámenes de un paciente
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

    // Buscar última consulta del paciente o crear una nueva
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

const PORT = 3001;
app.listen(PORT, () => {
  console.log(`API Server running on http://localhost:${PORT}`);
});