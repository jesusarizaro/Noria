import 'dart:convert';
// import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


class Nodo {
  final LatLng posicion;
  final List<Conexion> conexiones = [];
  final bool esEscalera;
  final bool esRampa;

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
      nodos[clave] = Nodo(LatLng(lat, lon), esEscalera:esEscalera, esRampa: esRampa);
    }
    return nodos[clave]!;
  }

Future<void> cargarDesdeGeoJSON(String ruta) async {
    final datos = jsonDecode(await rootBundle.loadString(ruta));

    for (var feature in datos['features']) {
      final geometry = feature['geometry'];
      final properties = feature['properties'] ?? {};
      final type = geometry['type'];

      if (type == 'LineString') {
        var coords = geometry['coordinates'];

        for (int i = 0; i < coords.length - 1; i++) {
          var coordInicio = coords[i];
          var coordFin = coords[i + 1];

          Nodo inicio = _obtenerOCrearNodo(coordInicio[1], coordInicio[0]);
          Nodo fin = _obtenerOCrearNodo(coordFin[1], coordFin[0]);

          double distancia = Distance().as(LengthUnit.Meter, inicio.posicion, fin.posicion);

          inicio.conexiones.add(Conexion(fin, distancia));
          fin.conexiones.add(Conexion(inicio, distancia));
        }
      }

      if (type == 'Point') {
        var coord = geometry['coordinates'];
        bool esEscalera = properties['name'] == 'Escalera' || properties['name'] == 'Escaleras';
        bool esRampa = properties['ramp'] == 'yes' || properties['name'] == 'Rampa';
        _obtenerOCrearNodo(coord[1], coord[0], esEscalera: esEscalera, esRampa: esRampa);
      }
    }
  }
  List<LatLng> encontrarRuta(LatLng inicio, LatLng fin, bool modoAccesible) {
    final nodoInicio = _nodoMasCercano(inicio);
    final nodoFin = _nodoMasCercano(fin);

    final distancias = <Nodo, double>{};
    final anteriores = <Nodo, Nodo?>{};
    final pendientes = <Nodo>[];

    for (var nodo in nodos.values) {
      distancias[nodo] = double.infinity;
      anteriores[nodo] = null;
      pendientes.add(nodo);
    }

    distancias[nodoInicio] = 0;

    while (pendientes.isNotEmpty) {
      pendientes.sort((a, b) => distancias[a]!.compareTo(distancias[b]!));
      Nodo actual = pendientes.removeAt(0);

      if (actual == nodoFin) break;

      for (var conexion in actual.conexiones) {
        if (modoAccesible && conexion.destino.esEscalera) continue; // Evita escaleras si el modo accesible está activado

        double alt = distancias[actual]! + conexion.distancia;
        if (alt < distancias[conexion.destino]!) {
          distancias[conexion.destino] = alt;
          anteriores[conexion.destino] = actual;
        }
      }
    }

    List<LatLng> ruta = [];
    Nodo? paso = nodoFin;

    while (paso != null) {
      ruta.insert(0, paso.posicion);
      paso = anteriores[paso];
    }

    print("📍 Ruta encontrada con ${ruta.length} puntos.");
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

  