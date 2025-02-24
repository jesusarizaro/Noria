import 'dart:convert';
// import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class Nodo {
  final LatLng posicion;
  final List<Conexion> conexiones = [];

  Nodo(this.posicion);
}

class Conexion {
  final Nodo destino;
  final double distancia;

  Conexion(this.destino, this.distancia);
}

class GrafoCampus {
  final Map<String, Nodo> nodos = {};

  Nodo _obtenerOCrearNodo(double lat, double lon) {
    String clave = '$lat,$lon';
    if (!nodos.containsKey(clave)) {
      nodos[clave] = Nodo(LatLng(lat, lon));
    }
    return nodos[clave]!;
  }

  Future<void> cargarDesdeGeoJSON(String ruta) async {
    final datos = jsonDecode(await rootBundle.loadString(ruta));

    for (var feature in datos['features']) {
      if (feature['geometry']['type'] == 'LineString') {
        var coords = feature['geometry']['coordinates'];

        for (int i = 0; i < coords.length - 1; i++) {
          var coordInicio = coords[i];
          var coordFin = coords[i + 1];

          Nodo inicio = _obtenerOCrearNodo(coordInicio[1], coordInicio[0]);
          Nodo fin = _obtenerOCrearNodo(coordFin[1], coordFin[0]);

          double distancia = Distance()
              .as(LengthUnit.Meter, inicio.posicion, fin.posicion);

          inicio.conexiones.add(Conexion(fin, distancia));
          fin.conexiones.add(Conexion(inicio, distancia));
        }
      }
    }
  }

  List<LatLng> encontrarRuta(LatLng inicio, LatLng fin) {
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

      for (var vecino in actual.conexiones) {
        double alt = distancias[actual]! + vecino.distancia;
        if (alt < distancias[vecino.destino]!) {
          distancias[vecino.destino] = alt;
          anteriores[vecino.destino] = actual;
        }
      }
    }

    List<LatLng> ruta = [];
    Nodo? paso = nodoFin;

    while (paso != null) {
      ruta.insert(0, paso.posicion);
      paso = anteriores[paso];
    }

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

    return cercano!;
  }
}
