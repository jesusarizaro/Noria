import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mapa Interactivo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MapaInteractivoScreen(),
    );
  }
}

class MapaInteractivoScreen extends StatefulWidget {
  @override
  _MapaInteractivoScreenState createState() => _MapaInteractivoScreenState();
}

class _MapaInteractivoScreenState extends State<MapaInteractivoScreen> {
  final String mapaPath = "assets/mapa.png";
  List<Map<String, dynamic>> puntosInteres = [];
  bool modoAgregarPuntos = false;
  bool mostrarMarcadores = true;
  TransformationController _transformationController = TransformationController();
  final GlobalKey _mapaKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _cargarPuntosGuardados();
    _transformationController.addListener(() {
    if (_transformationController.value.getMaxScaleOnAxis() <= 1.0) {
      _resetMapa();
    }
  });
  }
  void _resetMapa() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _cargarPuntosGuardados() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("puntos_interes");
    if (data != null) {
      setState(() {
        puntosInteres = List<Map<String, dynamic>>.from(jsonDecode(data));
      });
    }
  }

  Future<void> _guardarPuntos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("puntos_interes", jsonEncode(puntosInteres));
  }

  void _toggleModoAgregar() {
    setState(() {
      modoAgregarPuntos = !modoAgregarPuntos;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(modoAgregarPuntos
            ? "Modo agregar activado: toca el mapa para añadir un punto"
            : "Modo agregar desactivado"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _toggleMostrarMarcadores() {
    setState(() {
      mostrarMarcadores = !mostrarMarcadores;
    });
  }

  void _agregarPunto(TapDownDetails details) async {
    if (!modoAgregarPuntos) return;

    final RenderBox renderBox = _mapaKey.currentContext!.findRenderObject() as RenderBox;
    final Offset localOffset = renderBox.globalToLocal(details.globalPosition);
    final Offset transformedOffset = _transformationController.toScene(localOffset);

    TextEditingController _textController = TextEditingController();

    String? nombrePunto = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Agregar Punto"),
          content: TextField(
            controller: _textController,
            decoration: InputDecoration(hintText: "Nombre del punto"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text("Cancelar"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_textController.text),
              child: Text("Guardar"),
            ),
          ],
        );
      },
    );

    if (nombrePunto != null && nombrePunto.isNotEmpty) {
      setState(() {
        puntosInteres.add({
          "x": transformedOffset.dx,
          "y": transformedOffset.dy,
          "info": nombrePunto,
          "locked": false // Nuevo campo para bloqueo del marcador
        });
      });

      _guardarPuntos();
    }
  }

  void _moverPunto(int index, Offset newOffset) {
    if (puntosInteres[index]["locked"] == true) return; // No permite mover si está bloqueado

    setState(() {
      puntosInteres[index]["x"] = newOffset.dx;
      puntosInteres[index]["y"] = newOffset.dy;
    });
    _guardarPuntos();
  }

  void _toggleBloqueoPunto(int index) {
  setState(() {
    puntosInteres[index]["locked"] = !(puntosInteres[index]["locked"] ?? false);
  });
  _guardarPuntos();
}


  void _mostrarInfo(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Información del Punto"),
          content: Text(puntosInteres[index]["info"]),
          actions: [
            TextButton(
              onPressed: () => _toggleBloqueoPunto(index),
              child: Text((puntosInteres[index]["locked"] ?? false) 
                  ? "Desbloquear marcador" 
                  : "Bloquear marcador"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cerrar"),
            ),
          ],
        );
      },
    );
  }

  void _mostrarListaPuntos() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(10),
          height: 300,
          child: Column(
            children: [
              Text("Lista de Puntos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Expanded(
                child: ListView.builder(
                  itemCount: puntosInteres.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(puntosInteres[index]["info"]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          _eliminarPunto(index);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _eliminarPunto(int index) {
    setState(() {
      puntosInteres.removeAt(index);
    });
    _guardarPuntos();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Mapa Interactivo")),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "btnMostrar",
            onPressed: _toggleMostrarMarcadores,
            child: Icon(mostrarMarcadores ? Icons.visibility : Icons.visibility_off),
            backgroundColor: Colors.orange,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btnLista",
            onPressed: _mostrarListaPuntos,
            child: Icon(Icons.list),
            backgroundColor: Colors.green,
          ),
          SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "btnAgregar",
            onPressed: _toggleModoAgregar,
            child: Icon(modoAgregarPuntos ? Icons.cancel : Icons.add_location),
            backgroundColor: modoAgregarPuntos ? Colors.red : Colors.blue,
          ),
        ],
      ),
      body: GestureDetector(
        onTapDown: _agregarPunto,
        child: InteractiveViewer(
          transformationController: _transformationController,
          boundaryMargin: EdgeInsets.all(20.0),
          minScale: 1.0,
          maxScale: 5.0,
          child: Stack(
            children: [
              Image.asset(mapaPath, key: _mapaKey, fit: BoxFit.contain, width: double.infinity),
              if (mostrarMarcadores)
                ...puntosInteres.asMap().entries.map((entry) {
                  int index = entry.key;
                  var punto = entry.value;
                  return Positioned(
                    left: punto["x"],
                    top: punto["y"],
                    child: GestureDetector(
                      onLongPress: () {
                        _mostrarInfo(index);
                      },
                      onPanUpdate: (details) {
                        _moverPunto(index, Offset(punto["x"] + details.delta.dx, punto["y"] + details.delta.dy));
                      },
                      child: Icon(
                        Icons.location_pin,
                        color: (punto["locked"] ?? false) ? Colors.grey : Colors.red,

                        size: 30,
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
