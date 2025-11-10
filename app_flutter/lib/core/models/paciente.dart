// lib/core/models/paciente.dart

enum Sexo { masculino, femenino, otro }

class Paciente {
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

  static String normalizarSexo(String? sexo) {
    if (sexo == null) return 'otro';
    
    String sexoLower = sexo.toLowerCase();
    if (sexoLower == 'm' || sexoLower == 'masculino' || sexoLower.contains('masc')) {
      return 'masculino';
    } else if (sexoLower == 'f' || sexoLower == 'femenino' || sexoLower.contains('fem')) {
      return 'femenino';
    } else {
      return 'otro';
    }
  }

  Map<String, dynamic> toJson() {
    String sexoNormalizado = normalizarSexo(sexo);
    
    return {
      if (idPaciente != null) 'idPaciente': idPaciente,
      'nombrePaciente': nombrePaciente,
      'fechaNacimiento': fechaNacimiento.toIso8601String().split('T')[0],
      'correo': correo,
      'telefono': telefono,
      'direccion': direccion,
      'sexo': sexoNormalizado,
      'nacionalidad': nacionalidad,
      'ocupacion': ocupacion,
      'prevision': prevision,
      'tipoSangre': tipoSangre,
    };
  }

  String get fechaNacimientoFormatted {
    return '${fechaNacimiento.day.toString().padLeft(2, '0')}/${fechaNacimiento.month.toString().padLeft(2, '0')}/${fechaNacimiento.year}';
  }

  String get sexoDisplay {
    switch (sexo.toLowerCase()) {
      case 'masculino': return 'Masculino';
      case 'femenino': return 'Femenino';
      case 'otro': return 'Otro';
      default: return 'Otro';
    }
  }
}