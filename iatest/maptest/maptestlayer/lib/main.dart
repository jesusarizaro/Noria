import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'grafo.dart';

void main() => runApp(const CampusMapApp());

class CampusMapApp extends StatelessWidget {
  const CampusMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CampusMapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController mapController = MapController();
  final List<Polyline> caminos = [];
  final List<Marker> puntosInteres = [];
  final GrafoCampus grafoCampus = GrafoCampus();
  LatLng? puntoInicio;
  LatLng? puntoFin;
  List<LatLng> rutaOptima = [];

  @override
  void initState() {
    super.initState();
    cargarGeoJSON();
    grafoCampus.cargarDesdeGeoJSON('assets/Layers.geojson').then((_) {
      print('Grafo cargado con ${grafoCampus.nodos.length} nodos.');
      setState(() {});
    });
  }

  Future<void> cargarGeoJSON() async {
    final String data = await rootBundle.loadString('assets/Layers.geojson');
    final geojson = jsonDecode(data);
    final List<LatLng> todasLasCoordenadas = [];

    for (var feature in geojson['features']) {
      final geometry = feature['geometry'];
      final type = geometry['type'];
      final propiedades = feature['properties'] ?? {};

      if (type == 'LineString') {
        final List coords = geometry['coordinates'];
        final puntosLinea =
            coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

        caminos.add(Polyline(
          points: puntosLinea,
          color: Colors.blue,
          strokeWidth: 3,
        ));

        todasLasCoordenadas.addAll(puntosLinea);
      }

      if (type == 'Point') {
        final List coord = geometry['coordinates'];
        final nombre = propiedades['name'] ?? 'Sin nombre';
        final descripcion = propiedades['descripcion'] ?? 'Sin descripción';

        final punto = LatLng(coord[1], coord[0]);
        puntosInteres.add(Marker(
          point: punto,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(nombre),
                  content: Text(descripcion),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cerrar"),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(Icons.location_on, color: Colors.red, size: 30),
          ),
        ));

        todasLasCoordenadas.add(punto);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (todasLasCoordenadas.isNotEmpty) {
        final bounds = LatLngBounds.fromPoints(todasLasCoordenadas);
        mapController.fitCamera(
          CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(20),
          ),
        );
      }
    });

    setState(() {});
  }

  void calcularRutaInteractiva() {
    if (puntoInicio != null && puntoFin != null) {
      rutaOptima = grafoCampus.encontrarRuta(puntoInicio!, puntoFin!);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campus Map')),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: LatLng(0, 0),
          initialZoom: 16,
          onTap: (_, puntoTocado) {
            setState(() {
              if (puntoInicio == null || (puntoInicio != null && puntoFin != null)) {
                puntoInicio = puntoTocado;
                puntoFin = null;
                rutaOptima.clear();
              } else if (puntoInicio != null && puntoFin == null) {
                puntoFin = puntoTocado;
                calcularRutaInteractiva();
              }
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          PolylineLayer(polylines: caminos),
          PolylineLayer(
            polylines: [
              Polyline(points: rutaOptima, color: Colors.green, strokeWidth: 5),
            ],
          ),
          MarkerLayer(markers: [
            ...puntosInteres,
            if (puntoInicio != null)
              Marker(
                point: puntoInicio!,
                child: const Icon(Icons.location_on, color: Colors.green, size: 40),
              ),
            if (puntoFin != null)
              Marker(
                point: puntoFin!,
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
          ]),
        ],
      ),
    );
  }
}
