enum CastDeviceType {
  dlna,
  roku,
}

class CastDevice {
  final String id;
  final String name;
  final String host;
  final CastDeviceType type;
  final dynamic originalDevice; // Pode guardar o objeto original (ex: UPnP device, CastDevice)

  const CastDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.type,
    this.originalDevice,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CastDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  String get typeName {
    switch (type) {
      case CastDeviceType.dlna:
        return 'Smart TV (DLNA)';
      case CastDeviceType.roku:
        return 'Roku TV';
    }
  }
}
