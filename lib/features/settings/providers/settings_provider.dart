import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

final locationPermissionProvider = FutureProvider<LocationPermission>((ref) {
  return Geolocator.checkPermission();
});
