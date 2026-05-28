import 'dart:convert';

import 'package:shelf/shelf.dart';

import '../state.dart';

Response listRoutesHandler(Request request) {
  final agencyNameById = {
    for (final a in gtfsData.agencies) a.id: a.name,
  };

  final routes = gtfsData.routes.values.map((r) {
    final patterns = routeIndex.getPatternsForRoute(r.id).map((p) {
      final firstStop = p.stopIds.isNotEmpty
          ? gtfsData.stops[p.stopIds.first]?.name
          : null;
      final lastStop = p.stopIds.isNotEmpty
          ? gtfsData.stops[p.stopIds.last]?.name
          : null;
      return {
        'id': p.id,
        'headsign': p.headsign,
        'firstStop': firstStop,
        'lastStop': lastStop,
      };
    }).toList();

    return {
      ...r.toJson(),
      // Enrichment: optional fields old clients ignore, new clients use to
      // build one entry per pattern (matching the local mode behavior).
      'agencyName':
          r.agencyId != null ? agencyNameById[r.agencyId] : null,
      'patterns': patterns,
    };
  }).toList();

  return Response.ok(
    jsonEncode({
      'routes': routes,
      'total': routes.length,
    }),
    headers: {'Content-Type': 'application/json'},
  );
}

Response getRouteHandler(Request request, String id) {
  final route = gtfsData.routes[id];
  if (route == null) {
    return Response.notFound(
      jsonEncode({'error': 'Route not found: $id'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  final pattern = routeIndex.getPattern(id);

  // Resolve geometry from shape
  List<Map<String, double>>? geometry;
  if (pattern?.shapeId != null) {
    final shape = gtfsData.shapes[pattern!.shapeId!];
    if (shape != null) {
      geometry =
          shape.points.map((p) => {'lat': p.lat, 'lon': p.lon}).toList();
    }
  }

  // Resolve stops from pattern
  List<Map<String, dynamic>>? stops;
  if (pattern != null) {
    stops = pattern.stopIds
        .map((stopId) => gtfsData.stops[stopId])
        .where((s) => s != null)
        .map((s) => {'name': s!.name, 'lat': s.lat, 'lon': s.lon})
        .toList();
  }

  return Response.ok(
    jsonEncode({
      ...route.toJson(),
      'geometry': geometry ?? [],
      'stops': stops ?? [],
    }),
    headers: {'Content-Type': 'application/json'},
  );
}
