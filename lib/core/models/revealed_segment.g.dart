// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revealed_segment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RevealedSegmentAdapter extends TypeAdapter<RevealedSegment> {
  @override
  final int typeId = 4;

  @override
  RevealedSegment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RevealedSegment(
      id: fields[0] as String,
      streetId: fields[1] as String,
      streetName: fields[2] as String?,
      startLat: fields[3] as double,
      startLng: fields[4] as double,
      endLat: fields[5] as double,
      endLng: fields[6] as double,
      timesWalked: fields[7] as int,
      firstDiscoveredAt: fields[8] as DateTime,
      lastWalkedAt: fields[9] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, RevealedSegment obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.streetId)
      ..writeByte(2)
      ..write(obj.streetName)
      ..writeByte(3)
      ..write(obj.startLat)
      ..writeByte(4)
      ..write(obj.startLng)
      ..writeByte(5)
      ..write(obj.endLat)
      ..writeByte(6)
      ..write(obj.endLng)
      ..writeByte(7)
      ..write(obj.timesWalked)
      ..writeByte(8)
      ..write(obj.firstDiscoveredAt)
      ..writeByte(9)
      ..write(obj.lastWalkedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RevealedSegmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
