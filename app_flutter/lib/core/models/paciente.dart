// lib/core/models/paciente.dart

class Paciente{
  final int? idPaciente;
  final String nombrePaciente;
  final DateTime fechaNacimiento;
  final String? correo;
  final String? telefono;
  final String? direccion;
  final String sexo;
  final String? nacionalidad;
  final String? ocupacion;
  final String? prevision;
  final String? tipoSangre;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // constructor
  Paciente({
    this.idPaciente,
    required this.nombrePaciente,
    required this.fechaNacimiento,
    this.correo,
    this.telefono,
    this.direccion,
    required this.sexo,
    this.nacionalidad,
    this.ocupacion,
    this.prevision,
    this.tipoSangre,
    this.createdAt,
    this.updatedAt,
  });

  // factory para JSON -> objeto
  factory Paciente.fromJson(Map<String, dynamic> json) {
    return Paciente(
      idPaciente: json['idPaciente'],
      nombrePaciente: json['nombrePaciente'],
      fechaNacimiento: DateTime.parse(json['fechaNacimiento']),
      correo: json['correo'],
      telefono: json['telefono'],
      direccion: json['direccion'],
      sexo: json['sexo'],
      nacionalidad: json['nacionalidad'],
      ocupacion: json['ocupacion'],
      prevision: json['prevision'],
      tipoSangre: json['tipoSangre'],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  // metodo para objeto -> JSON
  Map<String, dynamic> toJson() {
    return {
      if (idPaciente != null) 'idPaciente': idPaciente,
      'nombrePaciente': nombrePaciente,
      'fechaNacimiento': fechaNacimiento.toIso8601String().split('T')[0], // Solo fecha YYYY-MM-DD
      'correo': correo,
      'telefono': telefono,
      'direccion': direccion,
      'sexo': sexo,
      'nacionalidad': nacionalidad,
      'ocupacion': ocupacion,
      'prevision': prevision,
      'tipoSangre': tipoSangre,
    };
  }

  /// Helper para formatear fecha nacimiento como string legible
  String get fechaNacimientoFormatted {
    return '${fechaNacimiento.day.toString().padLeft(2, '0')}/${fechaNacimiento.month.toString().padLeft(2, '0')}/${fechaNacimiento.year}';
  }

}