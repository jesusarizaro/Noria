import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'grafo.dart';

void main() => runApp(const CampusMapApp());

class CampusMapApp extends StatelessWidget {
  const CampusMapApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: CampusMapScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({Key? key}) : super(key: key);

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController mapController = MapController();
  final List<Polyline> caminos = [];
  final List<Marker> puntosInteres = [];
  final List<Polygon> edificios = [];
  final GrafoCampus grafoCampus = GrafoCampus();

  // List to store available directions from markers.
  final List<Map<String, dynamic>> availableDirections = [];

  LatLng? puntoInicio;
  LatLng? puntoFin;
  List<LatLng> rutaOptima = [];

  // For tracking the current location.
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // For voice navigation.
  final FlutterTts _flutterTts = FlutterTts();

  // Maintain a state variable for the current zoom.
  double currentZoom = 17.0;

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
    _initLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _currentPosition = await Geolocator.getCurrentPosition();
    setState(() {
      puntoInicio = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      ),
    ).listen((Position position) {
      setState(() {
        _currentPosition = position;
        // Update the GPS marker's location.
        puntoInicio = LatLng(position.latitude, position.longitude);
      });
      // Recalculate the route if a destination is set.
      if (puntoFin != null) {
        calcularRutaInteractiva();
      }
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
        final puntosLinea = coords
            .map<LatLng>((c) => LatLng(c[1], c[0]))
            .toList();
        caminos.add(
          Polyline(points: puntosLinea, color: Colors.blue, strokeWidth: 3),
        );
      }

      if (type == 'Point') {
        final List coord = geometry['coordinates'];
        final String nombre = propiedades['name'] ?? 'Sin nombre';
        final String descripcion =
            propiedades['descripcion'] ?? 'Sin descripción';

        String? iconPath;
        if (propiedades["name"] == "Paso peatonal") {
          iconPath = "assets/sidewalking.png";
        } else if (propiedades["name"] == "Escaleras" ||
            propiedades["name"] == "Escalera") {
          iconPath = "assets/stairs.png";
        } else if (propiedades["ramp"] == "yes" ||
            propiedades["name"] == "Rampa") {
          iconPath = "assets/ramp.png";
        }

        
        final marker = Marker(
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
                : const Icon(Icons.location_on, color: Colors.red, size: 30),
          ),
        );
        puntosInteres.add(marker);

        
        availableDirections.add({
          'name': nombre,
          'description': descripcion,
          'latlng': LatLng(coord[1], coord[0]),
        });
      }

      if (type == 'Polygon') {
        var coordenadas = geometry['coordinates'];
        if (coordenadas is List &&
            coordenadas.isNotEmpty &&
            coordenadas[0] is List) {
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
            if (poligono is List &&
                poligono.isNotEmpty &&
                poligono[0] is List) {
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

  void _showAvailableDirections() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: availableDirections.length,
          itemBuilder: (context, index) {
            final direction = availableDirections[index];
            return ListTile(
              title: Text(direction['name']),
              subtitle: Text(direction['description']),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  puntoFin = direction['latlng'];
                });
                calcularRutaInteractiva();
                _flutterTts.speak("Route calculated to ${direction['name']}. Starting voice navigation.");
              },
            );
          },
        );
      },
    );
  }

  // Basic voice navigation trigger.
  Future<void> _startVoiceNavigation() async {
    if (rutaOptima.isEmpty) {
      await _flutterTts.speak("No route has been calculated yet.");
      return;
    }
    await _flutterTts.speak("Starting voice navigation. Follow the green route.");
    // Aquí se puede implementar la navegación por voz paso a paso.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showAvailableDirections,
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over),
            onPressed: _startVoiceNavigation,
          ),
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
          ),
        ],
      ),
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: puntoInicio ?? LatLng(11.0194785545021, -74.85043187609091),
          onTap: (tapPosition, puntoTocado) {
            setState(() {
              if (puntoInicio == null || (puntoInicio != null && puntoFin != null)) {
                puntoFin = null;
                if (_currentPosition != null) {
                  puntoInicio = LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  );
                } else {
                  puntoInicio = puntoTocado;
                }
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
          PolylineLayer(
            polylines: [
              Polyline(points: rutaOptima, color: Colors.green, strokeWidth: 5),
            ],
          ),
          MarkerLayer(
            markers: [
              if (_currentPosition != null)
                Marker(
                  point: LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.circle, color: Colors.purple, size: 40),
                ),
              if (mostrarMarcadores) ...puntosInteres,
            ],
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //   },
      //   child: const Icon(Icons.my_location),
      // ),
    );
  }
}
