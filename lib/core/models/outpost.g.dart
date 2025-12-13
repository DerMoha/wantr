// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outpost.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OutpostAdapter extends TypeAdapter<Outpost> {
  @override
  final int typeId = 2;

  @override
  Outpost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Outpost(
      id: fields[0] as String,
      name: fields[1] as String,
      lat: fields[2] as double,
      lng: fields[3] as double,
      type: fields[4] as OutpostType,
      level: fields[5] as int,
      builtAt: fields[6] as DateTime,
      lastCollectedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Outpost obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.lat)
      ..writeByte(3)
      ..write(obj.lng)
      ..writeByte(4)
      ..write(obj.type)
      ..writeByte(5)
      ..write(obj.level)
      ..writeByte(6)
      ..write(obj.builtAt)
      ..writeByte(7)
      ..write(obj.lastCollectedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutpostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OutpostTypeAdapter extends TypeAdapter<OutpostType> {
  @override
  final int typeId = 3;

  @override
  OutpostType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OutpostType.tradingPost;
      case 1:
        return OutpostType.warehouse;
      case 2:
        return OutpostType.workshop;
      case 3:
        return OutpostType.inn;
      case 4:
        return OutpostType.bank;
      case 5:
        return OutpostType.scoutTower;
      default:
        return OutpostType.tradingPost;
    }
  }

  @override
  void write(BinaryWriter writer, OutpostType obj) {
    switch (obj) {
      case OutpostType.tradingPost:
        writer.writeByte(0);
        break;
      case OutpostType.warehouse:
        writer.writeByte(1);
        break;
      case OutpostType.workshop:
        writer.writeByte(2);
        break;
      case OutpostType.inn:
        writer.writeByte(3);
        break;
      case OutpostType.bank:
        writer.writeByte(4);
        break;
      case OutpostType.scoutTower:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OutpostTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
