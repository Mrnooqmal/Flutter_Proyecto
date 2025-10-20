const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

const db = mysql.createConnection({
  host: '54.167.116.30', //ip_publica_ec2 , remplazar cada que cambie
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

// POST /api/pacientes - Crear nuevo paciente
app.post('/api/pacientes', (req, res) => {
  const { nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre } = req.body;
  
  const query = `
    INSERT INTO Paciente 
    (nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre) 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;
  
  db.query(query, [nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre], 
    (err, results) => {
      if (err) {
        console.error('Error en MySQL:', err);
        return res.status(500).json({ error: 'Error creando paciente' });
      }
      
      res.json({ 
        idPaciente: results.insertId,
        nombrePaciente, fechaNacimiento, correo, telefono, direccion, sexo, nacionalidad, ocupacion, prevision, tipoSangre,
        message: 'Paciente creado exitosamente'
      });
    }
  );
});

// Iniciar servidor
const PORT = 3001;
app.listen(PORT, () => {
  console.log(`API Server running on http://localhost:${PORT}`);
});