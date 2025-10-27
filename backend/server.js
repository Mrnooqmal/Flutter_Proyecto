const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const EventEmitter = require('events');
const eventEmitter = new EventEmitter();

let sseClientes = [];

const app = express();
app.use(cors());
app.use(express.json());

const db = mysql.createConnection({
  host: '54.205.63.99', //ip_publica_ec2 , remplazar cada que cambie
  // para conectarse luego remotamente: mysql -h [ip_publica_ec2] -u meditrack_user2 -p , y luego password: M3d!Track2025
  //"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -h 98.81.192.180 -u meditrack_user2 -p
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

// PUT /api/pacientes/:id - Actualizar paciente
app.put('/api/pacientes/:id', (req, res) => {
  const { id } = req.params;
  const { nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre } = req.body;

  const query = `
  UPDATE Paciente
  SET nombrePaciente = ?, fechaNacimiento = ?, correo = ?, telefono = ?,
  direccion = ?, sexo = ?, nacionalidad = ?, ocupacion = ?,
  prevision = ?, tipoSangre = ?
  `;

  db.query(query, [nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre, id],
    (err, results) => {
      if (err) {
        console.error('Error en MySQL:', err);
        return res.status(500).json({ error: 'Error actualizando paciente' });
      }

      if (results.affectedRows === 0) {
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

      res.json(pacienteActualizado);

      // notificar SSE
      notificarClientes('paciente_actualizado', pacienteActualizado);
    }
  );
});


// Iniciar servidor
const PORT = 3001;
app.listen(PORT, () => {
  console.log(`API Server running on http://localhost:${PORT}`);
});