// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovered_street.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DiscoveredStreetAdapter extends TypeAdapter<DiscoveredStreet> {
  @override
  final int typeId = 1;

  @override
  DiscoveredStreet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DiscoveredStreet(
      id: fields[0] as String,
      startLat: fields[1] as double,
      startLng: fields[2] as double,
      endLat: fields[3] as double,
      endLng: fields[4] as double,
      streetName: fields[5] as String?,
      timesWalked: fields[6] as int,
      firstDiscoveredAt: fields[7] as DateTime?,
      lastWalkedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DiscoveredStreet obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startLat)
      ..writeByte(2)
      ..write(obj.startLng)
      ..writeByte(3)
      ..write(obj.endLat)
      ..writeByte(4)
      ..write(obj.endLng)
      ..writeByte(5)
      ..write(obj.streetName)
      ..writeByte(6)
      ..write(obj.timesWalked)
      ..writeByte(7)
      ..write(obj.firstDiscoveredAt)
      ..writeByte(8)
      ..write(obj.lastWalkedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredStreetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
