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
  final List<Polygon> edificios = [];
  final GrafoCampus grafoCampus = GrafoCampus();
  LatLng? puntoInicio;
  LatLng? puntoFin;
  List<LatLng> rutaOptima = [];
  bool mostrarEdificios = true;
  bool mostrarMarcadores = true;
  bool modoAccesible = false;

  @override
  void initState() {
    super.initState();
    cargarGeoJSON();
    grafoCampus.cargarDesdeGeoJSON('assets/Layers.geojson').then((_) {
      setState(() {});
    });
  }

  Future<void> cargarGeoJSON() async {
    final String data = await rootBundle.loadString('assets/Layers.geojson');
    final geojson = jsonDecode(data);

    for (var feature in geojson['features']) {
      final geometry = feature['geometry'];
      final type = geometry['type'];
      final propiedades = feature['properties'] ?? {};

      if (type == 'LineString') {
        final List coords = geometry['coordinates'];
        final puntosLinea = coords.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        caminos.add(Polyline(points: puntosLinea, color: Colors.blue, strokeWidth: 3));
      }

      if (type == 'Point') {
        final List coord = geometry['coordinates'];
        final nombre = propiedades['name'] ?? 'Sin nombre';
        final descripcion = propiedades['descripcion'] ?? 'Sin descripción';

        // Asignar ícono según el tipo de punto
        String? iconPath; 
        if (propiedades["name"] == "Paso peatonal") {
          iconPath = "assets/sidewalking.png";
        } else if (propiedades["name"] == "Escaleras") {
          iconPath = "assets/stairs.png";
        } else if (propiedades["name"] == "Escalera") {
          iconPath = "assets/stairs.png";
        } else if (propiedades["ramp"] == "yes") {
          iconPath = "assets/ramp.png";
        } else if (propiedades["name"] == "Rampa") { 
          iconPath = "assets/ramp.png";
        }

        puntosInteres.add(Marker(
          point: LatLng(coord[1], coord[0]),
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
            child: iconPath != null
                ? Image.asset(iconPath) 
                : const Icon(Icons.location_on, color: Colors.red, size: 30), // Cargar la imagen del icono
          ),
        ));
      }
      

      if (type == 'Polygon') {
        var coordenadas = geometry['coordinates'];
        if (coordenadas is List && coordenadas.isNotEmpty && coordenadas[0] is List) {
          List<LatLng> puntosPoligono = (coordenadas[0] as List)
              .map<LatLng>((c) => LatLng(c[1], c[0]))
              .toList();

          edificios.add(Polygon(
            points: puntosPoligono,
            color: Colors.brown.withOpacity(0.5),
            borderColor: Colors.black,
            borderStrokeWidth: 2,
          ));
        }
      }

      if (type == 'MultiPolygon') {
        var multiCoordenadas = geometry['coordinates'];
        if (multiCoordenadas is List && multiCoordenadas.isNotEmpty) {
          for (var poligono in multiCoordenadas) {
            if (poligono is List && poligono.isNotEmpty && poligono[0] is List) {
              List<LatLng> puntosPoligono = (poligono[0] as List)
                  .map<LatLng>((c) => LatLng(c[1], c[0]))
                  .toList();

              edificios.add(Polygon(
                points: puntosPoligono,
                color: Colors.brown.withOpacity(0.5),
                borderColor: Colors.black,
                borderStrokeWidth: 2,
              ));
            }
          }
        }
      }
    }
    setState(() {});
  }
  
  void calcularRutaInteractiva() {
    if (puntoInicio != null && puntoFin != null) {
      print("🔍 Buscando ruta desde $puntoInicio hasta $puntoFin");
      rutaOptima = grafoCampus.encontrarRuta(puntoInicio!, puntoFin!, modoAccesible);
      print("✅ Ruta calculada con ${rutaOptima.length} puntos.");
      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        actions: [
          IconButton(
            icon: Icon(mostrarEdificios ? Icons.layers : Icons.layers_clear),
            onPressed: () {
              setState(() {
                mostrarEdificios = !mostrarEdificios;
              });
            },
          ),
          IconButton(
            icon: Icon(mostrarMarcadores ? Icons.place : Icons.place_outlined),
            onPressed: () {
              setState(() {
                mostrarMarcadores = !mostrarMarcadores;
              });
            },
          ),
          IconButton(
            icon: Icon(modoAccesible ? Icons.accessible : Icons.accessibility_new),
            onPressed: () {
              setState(() {
                modoAccesible = !modoAccesible;
              });
            },
          )
        ],
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: LatLng(11.0194785545021, -74.85043187609091),
          initialZoom: 17,
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
          if (mostrarEdificios) PolygonLayer(polygons: edificios),
          PolylineLayer(polylines: caminos),
          PolylineLayer(polylines: [
            Polyline(points: rutaOptima, color: Colors.green, strokeWidth: 5),
          ]),
          if (mostrarMarcadores)
            MarkerLayer(markers: [
              ...puntosInteres,
            ]),
        ],
      ),
    );
  }
}
