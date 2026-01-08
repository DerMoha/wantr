// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 5;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings()
      .._gpsModeIndex = fields[0] as int?
      .._showDebugInfo = fields[1] as bool?
      .._wifiOnlySync = fields[2] as bool?
      .._hasSeenOnboarding = fields[3] as bool?;
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj._gpsModeIndex)
      ..writeByte(1)
      ..write(obj._showDebugInfo)
      ..writeByte(2)
      ..write(obj._wifiOnlySync)
      ..writeByte(3)
      ..write(obj._hasSeenOnboarding);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
