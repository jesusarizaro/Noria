import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'grafo.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Lista para almacenar destinos disponibles (desde GeoJSON)
  final List<Map<String, dynamic>> availableDirections = [];

  LatLng? puntoInicio;
  LatLng? puntoFin;
  List<LatLng> rutaOptima = [];
  String _location = '';
  

  // Seguimiento de la posición actual
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  // Para navegación por voz (ya existente)
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';

  // Para solicitudes GPT mediante voz
  final stt.SpeechToText _speechGPT = stt.SpeechToText();
  bool _isListeningGPT = false;
  String _lastGPTWords = '';

  // Estado de zoom actual
  double currentZoom = 17.0;

  bool mostrarEdificios = true;
  bool mostrarMarcadores = true;
  bool modoAccesible = false;
  Timer? _timer;
  String? _userName;

  @override
  void initState() {
    super.initState();
    cargarGeoJSON();
    grafoCampus.cargarDesdeGeoJSON('assets/Layers.geojson').then((_) {
      setState(() {});
    });
    _initLocation();
    _initSpeech();
    // _initSpeechGPT();
    _checkUserName();
    _updateLocationAndTime();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }
  Future<void> _checkUserName() async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? storedName = prefs.getString('userName');
      if (storedName == null) {
        // Se pregunta el nombre después de que se haya renderizado el widget
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _askUserName();
        });
      } else {
        setState(() {
          _userName = storedName;
        });
        _speakWelcomeMessage();
      }
    }
  
  // Muestra un diálogo para pedir el nombre del usuario.
  void _askUserName() {
    String tempName = "";
    showDialog(
      context: context,
      barrierDismissible: false, // No se cierra sin ingresar un nombre.
      builder: (context) {
        return AlertDialog(
          title: const Text('¿Cómo te gustaría que te llame?'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "Ingresa tu nombre"),
            onChanged: (value) {
              tempName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (tempName.trim().isNotEmpty) {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userName', tempName);
                  setState(() {
                    _userName = tempName;
                  });
                  Navigator.of(context).pop();
                  _speakWelcomeMessage();
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
  Future<void> _speakWelcomeMessage() async {
    String message = _userName != null ? 'Hola, $_userName! A dónde irémos hoy?':
    await _flutterTts.setLanguage('es-ES');
    await _flutterTts.speak(message); 
  }
  // Inicializa los servicios de localización.
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
        puntoInicio = LatLng(position.latitude, position.longitude);
      });
      if (puntoFin != null) {
        calcularRutaInteractiva();
      }
    });
  }

  // Inicializa SpeechToText para navegación.
  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
    if (available) {
      print('Speech recognition initialized');
    }
  }

  Future<void> _updateLocationAndTime() async {
    var locationStatus = await Permission.location.status;
    if (locationStatus.isDenied){
      await Permission.location.request();
    }
    if (locationStatus.isGranted){
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _location = 
            "Latitud: ${position.latitude}, Longitud: ${position.longitude}, Timestamp:${position.timestamp.toLocal().toString()}";
      });
    } else {
      setState(() {
        _location = "Location permission denied.";
      });
    }
  }
  bool isValidIP(String ipAddress){
    try {
      InternetAddress(ipAddress);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> sendUDP(double latitude, double longitude, String timestamp) async {
    try {
      final udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      String message = "Latitud:$latitude, Longitud:$longitude, Timestamp:$timestamp";
      List<int> data = utf8.encode(message);

      List<Map<String, dynamic>> destinations = [
        {'ip': '3.84.202.213', 'port': 3000},
      ];

      for (var destination in destinations) {
        udpSocket.send(
          data,
          InternetAddress(destination['ip']),
          destination['port'],
        );
        print('Datos enviados a ${destination['ip']}:${destination['port']}');
      }
      udpSocket.close();
    } catch (e) {
      print('Error al enviar datos UDP: $e');
    }
  }

  void sendData() {
    if (_timer != null) {
      _timer!.cancel();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    Geolocator.getCurrentPosition().then((position) {
      sendUDP(position.latitude, position.longitude, position.timestamp.toLocal().toString());
      });
    });
  }
  // Inicializa SpeechToText para solicitudes GPT.
  // Future<void> _initSpeechGPT() async {
  //   bool available = await _speechGPT.initialize(
  //     onStatus: (status) => print('Speech GPT status: $status'),
  //     onError: (error) => print('Speech GPT error: $error'),
  //   );
  //   if (available) {
  //     print('Speech GPT recognition initialized');
  //   }
  // }

  // Toggle para navegación por voz (ya existente).
  void _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('onStatus: $status'),
        onError: (error) => print('onError: $error'),
      );
      if (available) {
        setState(() {
          _isListening = true;
        });
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
              String command = result.recognizedWords;
              print('Final recognized (navegación): $command');
              _processVoiceCommand(command);
              setState(() {
                _isListening = false;
                _lastWords = command;
                sendData();
              });
            }
          },
        );
      }
    } else {
      setState(() {
        _isListening = false;
      });
      _speech.stop();
    }
  }

  // Toggle para solicitudes GPT por voz.
  void _toggleGPTListening() async {
    if (!_isListeningGPT) {
      bool available = await _speechGPT.initialize(
        onStatus: (status) => print('onStatus GPT: $status'),
        onError: (error) => print('onError GPT: $error'),
      );
      if (available) {
        setState(() {
          _isListeningGPT = true;
        });
        _speechGPT.listen(
          onResult: (result) {
            if (result.finalResult) {
              String command = result.recognizedWords;
              print('Final recognized for GPT: $command');
              _sendGPTRequest(command);
              setState(() {
                _isListeningGPT = false;
                _lastGPTWords = command;
              });
            }
          },
        );
      }
    } else {
      setState(() {
        _isListeningGPT = false;
      });
      _speechGPT.stop();
    }
  }

  // Procesa el comando de voz para navegación (búsqueda de destinos).
  void _processVoiceCommand(String command) {
    final lowerCommand = command.toLowerCase();
    final matched = availableDirections.firstWhere(
      (direction) => direction['name'].toString().toLowerCase().contains(lowerCommand),
      orElse: () => {},
    );
    
    if (matched.isNotEmpty) {
      setState(() {
        puntoFin = matched['latlng'];
      });
      calcularRutaInteractiva();
      _flutterTts.speak("Route calculated to ${matched['name']}.");
    } else {
      _flutterTts.speak("Destination not recognized. Please try again.");
    }
  }

  // Envía la solicitud a la API de ChatGPT y reproduce la respuesta por voz.
  Future<void> _sendGPTRequest(String prompt) async {
    // Reemplaza la URL con la de tu backend o endpoint
    final String url = 'http://3.84.202.213:2500/ask'; 
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"prompt": prompt}),
      );
      if (response.statusCode == 200) {
        print("Response body: ${response.body}");
        final data = jsonDecode(response.body);
        String gptResponse = data['response'] ?? "No se recibió la respuesta de GPT.";
        String? destino = data['destino'];
        print("Respuesta de GPT: $gptResponse, destino: $destino");
        await _flutterTts.speak(gptResponse);

        if (destino != null) {
          final matched = availableDirections.firstWhere(
            (direction) => direction['name'].toString().toLowerCase().contains(destino.toLowerCase()),
            orElse: () => {},
          );
          if (matched.isNotEmpty) {
            setState(() {
              puntoFin = matched['latlng'];
            });
            calcularRutaInteractiva();
          }
        }
      } else {
        print("Error en la API GPT: ${response.statusCode}");
        await _flutterTts.speak("Error en la respuesta de la API");
      }
    } catch (e) {
      print("Error en la solicitud GPT: $e");
      await _flutterTts.speak("Error al conectar con la API");
    }
  }

  // Carga los datos de GeoJSON y construye las capas del mapa.
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
        caminos.add(
          Polyline(points: puntosLinea, color: Colors.blue, strokeWidth: 3),
        );
      }

      if (type == 'Point') {
        final List coord = geometry['coordinates'];
        final String nombre = propiedades['name'] ?? 'Sin nombre';
        final String descripcion = propiedades['descripcion'] ?? 'Sin descripción';

        String? iconPath;
        if (propiedades["name"] == "Paso peatonal") {
          iconPath = "assets/sidewalking.png";
        } else if (propiedades["name"] == "Escaleras" || propiedades["name"] == "Escalera") {
          iconPath = "assets/stairs.png";
        } else if (propiedades["ramp"] == "yes" || propiedades["name"] == "Rampa") {
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

  // Calcula la ruta óptima usando el algoritmo del grafo.
  void calcularRutaInteractiva() {
    if (puntoInicio != null && puntoFin != null) {
      print("🔍 Buscando ruta desde $puntoInicio hasta $puntoFin");
      rutaOptima = grafoCampus.encontrarRuta(puntoInicio!, puntoFin!, modoAccesible);
      print("✅ Ruta calculada con ${rutaOptima.length} puntos.");
      setState(() {});
    }
  }

  // Dispara la navegación por voz (función básica).
  Future<void> _startVoiceNavigation() async {
    if (rutaOptima.isEmpty) {
      await _flutterTts.speak("No route has been calculated yet.");
      return;
    }
    await _flutterTts.speak("Starting voice navigation. Follow the green route.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Campus Map'),
        actions: [
          // Botón para reconocimiento de voz para navegación
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: _toggleListening,
          ),
          // Botón para reconocimiento de voz para solicitudes GPT
          IconButton(
            icon: const Icon(Icons.mic_external_on),
            onPressed: _toggleGPTListening,
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
          initialCenter: puntoInicio ?? const LatLng(11.0194785545021, -74.85043187609091),
          
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
      // Botón flotante para ver el último comando reconocido (para navegación).
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Último comando reconocido'),
              content: Text(_lastWords.isNotEmpty ? _lastWords : 'No se ha reconocido voz aún.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.text_snippet),
      ),
    );
  }
}
