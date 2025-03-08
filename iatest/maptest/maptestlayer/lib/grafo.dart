import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

class Nodo {
  final LatLng posicion;
  List<Conexion> conexiones = [];
  bool esEscalera;
  bool esRampa;

  Nodo(this.posicion, {this.esEscalera = false, this.esRampa = false});
}

class Conexion {
  final Nodo destino;
  final double distancia;

  Conexion(this.destino, this.distancia);
}

class GrafoCampus {
  final Map<String, Nodo> nodos = {};

  Nodo _obtenerOCrearNodo(double lat, double lon, {bool esEscalera = false, bool esRampa = false}) {
    String clave = '$lat,$lon';
    if (!nodos.containsKey(clave)) {
      nodos[clave] = Nodo(LatLng(lat, lon), esEscalera: esEscalera, esRampa: esRampa);
    }
    return nodos[clave]!;
  }

  Future<void> cargarDesdeGeoJSON(String ruta) async {
    final datos = jsonDecode(await rootBundle.loadString(ruta));

    for (var feature in datos['features']) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] ?? {};
      final type = geometry['type'];

      bool esEscalera = properties.containsKey('name') &&
          (properties['name'].toLowerCase().contains('escalera') ||
          properties['name'].toLowerCase().contains('escaleras'));

      bool esRampa = properties.containsKey('ramp') && properties['ramp'] == 'yes';

      if (type == 'LineString') {
        var coords = geometry['coordinates'];

        for (int i = 0; i < coords.length - 1; i++) {
          var coordInicio = coords[i];
          var coordFin = coords[i + 1];

          Nodo inicio = _obtenerOCrearNodo(coordInicio[1], coordInicio[0], esEscalera: esEscalera, esRampa: esRampa);
          Nodo fin = _obtenerOCrearNodo(coordFin[1], coordFin[0], esEscalera: esEscalera, esRampa: esRampa);

          double distancia = Distance().as(LengthUnit.Meter, inicio.posicion, fin.posicion);

          inicio.conexiones.add(Conexion(fin, distancia));
          fin.conexiones.add(Conexion(inicio, distancia));
        }
      }

      if (type == 'Point') {
        var coord = geometry['coordinates'];
        _obtenerOCrearNodo(coord[1], coord[0], esEscalera: esEscalera, esRampa: esRampa);
      }
    }

    print("✅ Grafo cargado con ${nodos.length} nodos.");
  }


List<LatLng> encontrarRuta(LatLng inicio, LatLng fin, bool modoAccesible) {
  final nodoInicio = _nodoMasCercano(inicio);
  final nodoFin = _nodoMasCercano(fin);

  // 🔹 Crear un nuevo grafo sin nodos de escaleras si modo accesible está activado
  final Map<String, Nodo> grafoTemporal = {};

  for (var clave in nodos.keys) {
    var nodo = nodos[clave]!;
    if (modoAccesible && nodo.esEscalera) {
      print("🚫 Nodo escalera eliminado temporalmente: ${nodo.posicion}");
      continue; // No agregamos este nodo al grafo temporal
    }
    grafoTemporal[clave] = Nodo(nodo.posicion, esEscalera: nodo.esEscalera, esRampa: nodo.esRampa);
  }

  // 🔹 Reconstruir las conexiones sin escaleras
  for (var clave in grafoTemporal.keys) {
    Nodo nodo = grafoTemporal[clave]!;
    for (var conexion in nodos[clave]!.conexiones) {
      if (grafoTemporal.containsKey('${conexion.destino.posicion.latitude},${conexion.destino.posicion.longitude}')) {
        nodo.conexiones.add(Conexion(
          grafoTemporal['${conexion.destino.posicion.latitude},${conexion.destino.posicion.longitude}']!,
          conexion.distancia,
        ));
      }
    }
  }

  // 🔹 Asegurar que los nodos de inicio y fin existen en el grafo temporal
  if (!grafoTemporal.containsKey('${nodoInicio.posicion.latitude},${nodoInicio.posicion.longitude}') ||
      !grafoTemporal.containsKey('${nodoFin.posicion.latitude},${nodoFin.posicion.longitude}')) {
    print("❌ No se encontró una ruta accesible sin escaleras.");
    return [];
  }

  // 🔹 Aplicar algoritmo de búsqueda en el grafo temporal
  final distancias = <Nodo, double>{};
  final anteriores = <Nodo, Nodo?>{};
  final pendientes = <Nodo>[];

  for (var nodo in grafoTemporal.values) {
    distancias[nodo] = double.infinity;
    anteriores[nodo] = null;
    pendientes.add(nodo);
  }

  distancias[grafoTemporal['${nodoInicio.posicion.latitude},${nodoInicio.posicion.longitude}']!] = 0;

  while (pendientes.isNotEmpty) {
    pendientes.sort((a, b) => distancias[a]!.compareTo(distancias[b]!));
    Nodo actual = pendientes.removeAt(0);

    if (actual.posicion == nodoFin.posicion) break;

    for (var conexion in actual.conexiones) {
      double alt = distancias[actual]! + conexion.distancia;
      if (alt < distancias[conexion.destino]!) {
        distancias[conexion.destino] = alt;
        anteriores[conexion.destino] = actual;
      }
    }
  }

  // 🔹 Construir la ruta final
  List<LatLng> ruta = [];
  Nodo? paso = grafoTemporal['${nodoFin.posicion.latitude},${nodoFin.posicion.longitude}'];

  while (paso != null) {
    ruta.insert(0, paso.posicion);
    paso = anteriores[paso];
  }

  print("📍 Ruta accesible final con ${ruta.length} puntos.");
  return ruta;
}

  Nodo _nodoMasCercano(LatLng punto) {
    Nodo? cercano;
    double minDistancia = double.infinity;

    for (var nodo in nodos.values) {
      double distancia = Distance().as(LengthUnit.Meter, punto, nodo.posicion);
      if (distancia < minDistancia) {
        cercano = nodo;
        minDistancia = distancia;
      }
    }

    return cercano ?? nodos.values.first;
  }
}
