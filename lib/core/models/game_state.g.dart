// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_state.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GameStateAdapter extends TypeAdapter<GameState> {
  @override
  final int typeId = 0;

  @override
  GameState read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GameState(
      playerId: fields[0] as String,
      playerName: fields[1] as String,
      level: fields[2] as int,
      xp: fields[3] as int,
      gold: fields[4] as int,
      discoveryPoints: fields[5] as int,
      tradeGoods: fields[6] as int,
      influence: fields[7] as int,
      energy: fields[8] as int,
      materials: fields[9] as int,
      totalDistanceWalked: fields[10] as double,
      streetsDiscovered: fields[11] as int,
      outpostsBuilt: fields[12] as int,
      tradesCompleted: fields[13] as int,
      createdAt: fields[14] as DateTime,
      lastActiveAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, GameState obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.playerId)
      ..writeByte(1)
      ..write(obj.playerName)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.xp)
      ..writeByte(4)
      ..write(obj.gold)
      ..writeByte(5)
      ..write(obj.discoveryPoints)
      ..writeByte(6)
      ..write(obj.tradeGoods)
      ..writeByte(7)
      ..write(obj.influence)
      ..writeByte(8)
      ..write(obj.energy)
      ..writeByte(9)
      ..write(obj.materials)
      ..writeByte(10)
      ..write(obj.totalDistanceWalked)
      ..writeByte(11)
      ..write(obj.streetsDiscovered)
      ..writeByte(12)
      ..write(obj.outpostsBuilt)
      ..writeByte(13)
      ..write(obj.tradesCompleted)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.lastActiveAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameStateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
