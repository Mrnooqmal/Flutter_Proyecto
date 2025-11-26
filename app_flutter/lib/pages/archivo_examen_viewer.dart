import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:photo_view/photo_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

class ArchivoExamenViewer extends StatefulWidget {
  final int idExamen;
  final int idConsulta;
  final String nombreExamen;
  final String? archivoTipo;

  const ArchivoExamenViewer({
    super.key,
    required this.idExamen,
    required this.idConsulta,
    required this.nombreExamen,
    this.archivoTipo,
  });

  @override
  State<ArchivoExamenViewer> createState() => _ArchivoExamenViewerState();
}

class _ArchivoExamenViewerState extends State<ArchivoExamenViewer> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _archivoBytes;
  String? _archivoTipo;
  String? _archivoNombre;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _cargarArchivo();
  }

  Future<void> _cargarArchivo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = 'http://localhost:3001/api/examenes/${widget.idExamen}/${widget.idConsulta}/archivo';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final base64String = data['contenido'];
        
        setState(() {
          _archivoBytes = base64Decode(base64String);
          _archivoTipo = data['tipo'];
          _archivoNombre = data['nombre'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error al cargar el archivo: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el archivo: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _descargarArchivo() async {
    if (_archivoBytes == null || _archivoNombre == null) return;

    setState(() => _descargando = true);

    try {
      // Obtener directorio de descargas
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_archivoNombre';
      
      // Guardar archivo
      final file = File(filePath);
      await file.writeAsBytes(_archivoBytes!);

      setState(() => _descargando = false);

      if (!mounted) return;

      // mostrar confirmacion y opcion de abrir
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Archivo guardado en: $filePath'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () async {
              await OpenFile.open(filePath);
            },
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      setState(() => _descargando = false);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al descargar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreExamen),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          if (_archivoBytes != null)
            IconButton(
              icon: _descargando 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              onPressed: _descargando ? null : _descargarArchivo,
              tooltip: 'Descargar archivo',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarArchivo,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _archivoBytes == null
                  ? const Center(child: Text('No se pudo cargar el archivo'))
                  : _buildViewer(),
    );
  }

  Widget _buildViewer() {
    if (_archivoTipo == null) {
      return const Center(child: Text('Tipo de archivo desconocido'));
    }

    // Visualizar PDF
    if (_archivoTipo!.contains('pdf')) {
      return SfPdfViewer.memory(
        _archivoBytes!,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      );
    }
    
    // Visualizar imagen
    if (_archivoTipo!.contains('image')) {
      return PhotoView(
        imageProvider: MemoryImage(_archivoBytes!),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
        backgroundDecoration: const BoxDecoration(
          color: Colors.white,
        ),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Tipo de archivo no soportado: $_archivoTipo',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _descargarArchivo,
            icon: const Icon(Icons.download),
            label: const Text('Descargar archivo'),
          ),
        ],
      ),
    );
  }
}
