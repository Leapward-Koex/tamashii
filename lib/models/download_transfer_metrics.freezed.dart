// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'download_transfer_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DownloadTransferSnapshot {

 String get key; TorrentStats? get stats; TorrentMetadata? get metadata; bool get isCompleted; bool get isPaused; bool get isPreparing; bool get isPolicyBlocked; String? get errorMessage;
/// Create a copy of DownloadTransferSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadTransferSnapshotCopyWith<DownloadTransferSnapshot> get copyWith => _$DownloadTransferSnapshotCopyWithImpl<DownloadTransferSnapshot>(this as DownloadTransferSnapshot, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadTransferSnapshot&&(identical(other.key, key) || other.key == key)&&(identical(other.stats, stats) || other.stats == stats)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.isPreparing, isPreparing) || other.isPreparing == isPreparing)&&(identical(other.isPolicyBlocked, isPolicyBlocked) || other.isPolicyBlocked == isPolicyBlocked)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,key,stats,metadata,isCompleted,isPaused,isPreparing,isPolicyBlocked,errorMessage);

@override
String toString() {
  return 'DownloadTransferSnapshot(key: $key, stats: $stats, metadata: $metadata, isCompleted: $isCompleted, isPaused: $isPaused, isPreparing: $isPreparing, isPolicyBlocked: $isPolicyBlocked, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $DownloadTransferSnapshotCopyWith<$Res>  {
  factory $DownloadTransferSnapshotCopyWith(DownloadTransferSnapshot value, $Res Function(DownloadTransferSnapshot) _then) = _$DownloadTransferSnapshotCopyWithImpl;
@useResult
$Res call({
 String key, TorrentStats? stats, TorrentMetadata? metadata, bool isCompleted, bool isPaused, bool isPreparing, bool isPolicyBlocked, String? errorMessage
});




}
/// @nodoc
class _$DownloadTransferSnapshotCopyWithImpl<$Res>
    implements $DownloadTransferSnapshotCopyWith<$Res> {
  _$DownloadTransferSnapshotCopyWithImpl(this._self, this._then);

  final DownloadTransferSnapshot _self;
  final $Res Function(DownloadTransferSnapshot) _then;

/// Create a copy of DownloadTransferSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? stats = freezed,Object? metadata = freezed,Object? isCompleted = null,Object? isPaused = null,Object? isPreparing = null,Object? isPolicyBlocked = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,stats: freezed == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as TorrentStats?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as TorrentMetadata?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,isPreparing: null == isPreparing ? _self.isPreparing : isPreparing // ignore: cast_nullable_to_non_nullable
as bool,isPolicyBlocked: null == isPolicyBlocked ? _self.isPolicyBlocked : isPolicyBlocked // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadTransferSnapshot].
extension DownloadTransferSnapshotPatterns on DownloadTransferSnapshot {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadTransferSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadTransferSnapshot() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadTransferSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferSnapshot():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadTransferSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferSnapshot() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  TorrentStats? stats,  TorrentMetadata? metadata,  bool isCompleted,  bool isPaused,  bool isPreparing,  bool isPolicyBlocked,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadTransferSnapshot() when $default != null:
return $default(_that.key,_that.stats,_that.metadata,_that.isCompleted,_that.isPaused,_that.isPreparing,_that.isPolicyBlocked,_that.errorMessage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  TorrentStats? stats,  TorrentMetadata? metadata,  bool isCompleted,  bool isPaused,  bool isPreparing,  bool isPolicyBlocked,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferSnapshot():
return $default(_that.key,_that.stats,_that.metadata,_that.isCompleted,_that.isPaused,_that.isPreparing,_that.isPolicyBlocked,_that.errorMessage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  TorrentStats? stats,  TorrentMetadata? metadata,  bool isCompleted,  bool isPaused,  bool isPreparing,  bool isPolicyBlocked,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferSnapshot() when $default != null:
return $default(_that.key,_that.stats,_that.metadata,_that.isCompleted,_that.isPaused,_that.isPreparing,_that.isPolicyBlocked,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadTransferSnapshot implements DownloadTransferSnapshot {
  const _DownloadTransferSnapshot({required this.key, this.stats, this.metadata, this.isCompleted = false, this.isPaused = false, this.isPreparing = false, this.isPolicyBlocked = false, this.errorMessage});
  

@override final  String key;
@override final  TorrentStats? stats;
@override final  TorrentMetadata? metadata;
@override@JsonKey() final  bool isCompleted;
@override@JsonKey() final  bool isPaused;
@override@JsonKey() final  bool isPreparing;
@override@JsonKey() final  bool isPolicyBlocked;
@override final  String? errorMessage;

/// Create a copy of DownloadTransferSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadTransferSnapshotCopyWith<_DownloadTransferSnapshot> get copyWith => __$DownloadTransferSnapshotCopyWithImpl<_DownloadTransferSnapshot>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadTransferSnapshot&&(identical(other.key, key) || other.key == key)&&(identical(other.stats, stats) || other.stats == stats)&&(identical(other.metadata, metadata) || other.metadata == metadata)&&(identical(other.isCompleted, isCompleted) || other.isCompleted == isCompleted)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.isPreparing, isPreparing) || other.isPreparing == isPreparing)&&(identical(other.isPolicyBlocked, isPolicyBlocked) || other.isPolicyBlocked == isPolicyBlocked)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,key,stats,metadata,isCompleted,isPaused,isPreparing,isPolicyBlocked,errorMessage);

@override
String toString() {
  return 'DownloadTransferSnapshot(key: $key, stats: $stats, metadata: $metadata, isCompleted: $isCompleted, isPaused: $isPaused, isPreparing: $isPreparing, isPolicyBlocked: $isPolicyBlocked, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$DownloadTransferSnapshotCopyWith<$Res> implements $DownloadTransferSnapshotCopyWith<$Res> {
  factory _$DownloadTransferSnapshotCopyWith(_DownloadTransferSnapshot value, $Res Function(_DownloadTransferSnapshot) _then) = __$DownloadTransferSnapshotCopyWithImpl;
@override @useResult
$Res call({
 String key, TorrentStats? stats, TorrentMetadata? metadata, bool isCompleted, bool isPaused, bool isPreparing, bool isPolicyBlocked, String? errorMessage
});




}
/// @nodoc
class __$DownloadTransferSnapshotCopyWithImpl<$Res>
    implements _$DownloadTransferSnapshotCopyWith<$Res> {
  __$DownloadTransferSnapshotCopyWithImpl(this._self, this._then);

  final _DownloadTransferSnapshot _self;
  final $Res Function(_DownloadTransferSnapshot) _then;

/// Create a copy of DownloadTransferSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? stats = freezed,Object? metadata = freezed,Object? isCompleted = null,Object? isPaused = null,Object? isPreparing = null,Object? isPolicyBlocked = null,Object? errorMessage = freezed,}) {
  return _then(_DownloadTransferSnapshot(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,stats: freezed == stats ? _self.stats : stats // ignore: cast_nullable_to_non_nullable
as TorrentStats?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as TorrentMetadata?,isCompleted: null == isCompleted ? _self.isCompleted : isCompleted // ignore: cast_nullable_to_non_nullable
as bool,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,isPreparing: null == isPreparing ? _self.isPreparing : isPreparing // ignore: cast_nullable_to_non_nullable
as bool,isPolicyBlocked: null == isPolicyBlocked ? _self.isPolicyBlocked : isPolicyBlocked // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$DownloadTransferItem {

 String get key; String get displayName; DownloadTransferStatus get status; double get progressFraction; int? get totalBytes; int? get receivedBytes; int? get remainingBytes; int? get downloadRate; int? get uploadRate; Duration? get eta; int? get seeds; int? get peers; String? get errorMessage;
/// Create a copy of DownloadTransferItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadTransferItemCopyWith<DownloadTransferItem> get copyWith => _$DownloadTransferItemCopyWithImpl<DownloadTransferItem>(this as DownloadTransferItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadTransferItem&&(identical(other.key, key) || other.key == key)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.status, status) || other.status == status)&&(identical(other.progressFraction, progressFraction) || other.progressFraction == progressFraction)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.remainingBytes, remainingBytes) || other.remainingBytes == remainingBytes)&&(identical(other.downloadRate, downloadRate) || other.downloadRate == downloadRate)&&(identical(other.uploadRate, uploadRate) || other.uploadRate == uploadRate)&&(identical(other.eta, eta) || other.eta == eta)&&(identical(other.seeds, seeds) || other.seeds == seeds)&&(identical(other.peers, peers) || other.peers == peers)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,key,displayName,status,progressFraction,totalBytes,receivedBytes,remainingBytes,downloadRate,uploadRate,eta,seeds,peers,errorMessage);

@override
String toString() {
  return 'DownloadTransferItem(key: $key, displayName: $displayName, status: $status, progressFraction: $progressFraction, totalBytes: $totalBytes, receivedBytes: $receivedBytes, remainingBytes: $remainingBytes, downloadRate: $downloadRate, uploadRate: $uploadRate, eta: $eta, seeds: $seeds, peers: $peers, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $DownloadTransferItemCopyWith<$Res>  {
  factory $DownloadTransferItemCopyWith(DownloadTransferItem value, $Res Function(DownloadTransferItem) _then) = _$DownloadTransferItemCopyWithImpl;
@useResult
$Res call({
 String key, String displayName, DownloadTransferStatus status, double progressFraction, int? totalBytes, int? receivedBytes, int? remainingBytes, int? downloadRate, int? uploadRate, Duration? eta, int? seeds, int? peers, String? errorMessage
});




}
/// @nodoc
class _$DownloadTransferItemCopyWithImpl<$Res>
    implements $DownloadTransferItemCopyWith<$Res> {
  _$DownloadTransferItemCopyWithImpl(this._self, this._then);

  final DownloadTransferItem _self;
  final $Res Function(DownloadTransferItem) _then;

/// Create a copy of DownloadTransferItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? displayName = null,Object? status = null,Object? progressFraction = null,Object? totalBytes = freezed,Object? receivedBytes = freezed,Object? remainingBytes = freezed,Object? downloadRate = freezed,Object? uploadRate = freezed,Object? eta = freezed,Object? seeds = freezed,Object? peers = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DownloadTransferStatus,progressFraction: null == progressFraction ? _self.progressFraction : progressFraction // ignore: cast_nullable_to_non_nullable
as double,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,receivedBytes: freezed == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int?,remainingBytes: freezed == remainingBytes ? _self.remainingBytes : remainingBytes // ignore: cast_nullable_to_non_nullable
as int?,downloadRate: freezed == downloadRate ? _self.downloadRate : downloadRate // ignore: cast_nullable_to_non_nullable
as int?,uploadRate: freezed == uploadRate ? _self.uploadRate : uploadRate // ignore: cast_nullable_to_non_nullable
as int?,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as Duration?,seeds: freezed == seeds ? _self.seeds : seeds // ignore: cast_nullable_to_non_nullable
as int?,peers: freezed == peers ? _self.peers : peers // ignore: cast_nullable_to_non_nullable
as int?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadTransferItem].
extension DownloadTransferItemPatterns on DownloadTransferItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadTransferItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadTransferItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadTransferItem value)  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadTransferItem value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String displayName,  DownloadTransferStatus status,  double progressFraction,  int? totalBytes,  int? receivedBytes,  int? remainingBytes,  int? downloadRate,  int? uploadRate,  Duration? eta,  int? seeds,  int? peers,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadTransferItem() when $default != null:
return $default(_that.key,_that.displayName,_that.status,_that.progressFraction,_that.totalBytes,_that.receivedBytes,_that.remainingBytes,_that.downloadRate,_that.uploadRate,_that.eta,_that.seeds,_that.peers,_that.errorMessage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String displayName,  DownloadTransferStatus status,  double progressFraction,  int? totalBytes,  int? receivedBytes,  int? remainingBytes,  int? downloadRate,  int? uploadRate,  Duration? eta,  int? seeds,  int? peers,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferItem():
return $default(_that.key,_that.displayName,_that.status,_that.progressFraction,_that.totalBytes,_that.receivedBytes,_that.remainingBytes,_that.downloadRate,_that.uploadRate,_that.eta,_that.seeds,_that.peers,_that.errorMessage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String displayName,  DownloadTransferStatus status,  double progressFraction,  int? totalBytes,  int? receivedBytes,  int? remainingBytes,  int? downloadRate,  int? uploadRate,  Duration? eta,  int? seeds,  int? peers,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferItem() when $default != null:
return $default(_that.key,_that.displayName,_that.status,_that.progressFraction,_that.totalBytes,_that.receivedBytes,_that.remainingBytes,_that.downloadRate,_that.uploadRate,_that.eta,_that.seeds,_that.peers,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadTransferItem implements DownloadTransferItem {
  const _DownloadTransferItem({required this.key, required this.displayName, required this.status, required this.progressFraction, this.totalBytes, this.receivedBytes, this.remainingBytes, this.downloadRate, this.uploadRate, this.eta, this.seeds, this.peers, this.errorMessage});
  

@override final  String key;
@override final  String displayName;
@override final  DownloadTransferStatus status;
@override final  double progressFraction;
@override final  int? totalBytes;
@override final  int? receivedBytes;
@override final  int? remainingBytes;
@override final  int? downloadRate;
@override final  int? uploadRate;
@override final  Duration? eta;
@override final  int? seeds;
@override final  int? peers;
@override final  String? errorMessage;

/// Create a copy of DownloadTransferItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadTransferItemCopyWith<_DownloadTransferItem> get copyWith => __$DownloadTransferItemCopyWithImpl<_DownloadTransferItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadTransferItem&&(identical(other.key, key) || other.key == key)&&(identical(other.displayName, displayName) || other.displayName == displayName)&&(identical(other.status, status) || other.status == status)&&(identical(other.progressFraction, progressFraction) || other.progressFraction == progressFraction)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.remainingBytes, remainingBytes) || other.remainingBytes == remainingBytes)&&(identical(other.downloadRate, downloadRate) || other.downloadRate == downloadRate)&&(identical(other.uploadRate, uploadRate) || other.uploadRate == uploadRate)&&(identical(other.eta, eta) || other.eta == eta)&&(identical(other.seeds, seeds) || other.seeds == seeds)&&(identical(other.peers, peers) || other.peers == peers)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,key,displayName,status,progressFraction,totalBytes,receivedBytes,remainingBytes,downloadRate,uploadRate,eta,seeds,peers,errorMessage);

@override
String toString() {
  return 'DownloadTransferItem(key: $key, displayName: $displayName, status: $status, progressFraction: $progressFraction, totalBytes: $totalBytes, receivedBytes: $receivedBytes, remainingBytes: $remainingBytes, downloadRate: $downloadRate, uploadRate: $uploadRate, eta: $eta, seeds: $seeds, peers: $peers, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$DownloadTransferItemCopyWith<$Res> implements $DownloadTransferItemCopyWith<$Res> {
  factory _$DownloadTransferItemCopyWith(_DownloadTransferItem value, $Res Function(_DownloadTransferItem) _then) = __$DownloadTransferItemCopyWithImpl;
@override @useResult
$Res call({
 String key, String displayName, DownloadTransferStatus status, double progressFraction, int? totalBytes, int? receivedBytes, int? remainingBytes, int? downloadRate, int? uploadRate, Duration? eta, int? seeds, int? peers, String? errorMessage
});




}
/// @nodoc
class __$DownloadTransferItemCopyWithImpl<$Res>
    implements _$DownloadTransferItemCopyWith<$Res> {
  __$DownloadTransferItemCopyWithImpl(this._self, this._then);

  final _DownloadTransferItem _self;
  final $Res Function(_DownloadTransferItem) _then;

/// Create a copy of DownloadTransferItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? displayName = null,Object? status = null,Object? progressFraction = null,Object? totalBytes = freezed,Object? receivedBytes = freezed,Object? remainingBytes = freezed,Object? downloadRate = freezed,Object? uploadRate = freezed,Object? eta = freezed,Object? seeds = freezed,Object? peers = freezed,Object? errorMessage = freezed,}) {
  return _then(_DownloadTransferItem(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,displayName: null == displayName ? _self.displayName : displayName // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DownloadTransferStatus,progressFraction: null == progressFraction ? _self.progressFraction : progressFraction // ignore: cast_nullable_to_non_nullable
as double,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,receivedBytes: freezed == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int?,remainingBytes: freezed == remainingBytes ? _self.remainingBytes : remainingBytes // ignore: cast_nullable_to_non_nullable
as int?,downloadRate: freezed == downloadRate ? _self.downloadRate : downloadRate // ignore: cast_nullable_to_non_nullable
as int?,uploadRate: freezed == uploadRate ? _self.uploadRate : uploadRate // ignore: cast_nullable_to_non_nullable
as int?,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as Duration?,seeds: freezed == seeds ? _self.seeds : seeds // ignore: cast_nullable_to_non_nullable
as int?,peers: freezed == peers ? _self.peers : peers // ignore: cast_nullable_to_non_nullable
as int?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$DownloadTransferSummary {

 int get trackedCount; int get liveCount; int get completedCount; int get activeCount; int get downloadingCount; int get preparingCount; int get pausedCount; int get waitingForNetworkCount; int get failedCount; double get progressFraction; bool get progressIsEstimated; int? get totalBytes; int? get receivedBytes; int? get remainingBytes; int get downloadRate; int get uploadRate; Duration? get eta;
/// Create a copy of DownloadTransferSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadTransferSummaryCopyWith<DownloadTransferSummary> get copyWith => _$DownloadTransferSummaryCopyWithImpl<DownloadTransferSummary>(this as DownloadTransferSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadTransferSummary&&(identical(other.trackedCount, trackedCount) || other.trackedCount == trackedCount)&&(identical(other.liveCount, liveCount) || other.liveCount == liveCount)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount)&&(identical(other.activeCount, activeCount) || other.activeCount == activeCount)&&(identical(other.downloadingCount, downloadingCount) || other.downloadingCount == downloadingCount)&&(identical(other.preparingCount, preparingCount) || other.preparingCount == preparingCount)&&(identical(other.pausedCount, pausedCount) || other.pausedCount == pausedCount)&&(identical(other.waitingForNetworkCount, waitingForNetworkCount) || other.waitingForNetworkCount == waitingForNetworkCount)&&(identical(other.failedCount, failedCount) || other.failedCount == failedCount)&&(identical(other.progressFraction, progressFraction) || other.progressFraction == progressFraction)&&(identical(other.progressIsEstimated, progressIsEstimated) || other.progressIsEstimated == progressIsEstimated)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.remainingBytes, remainingBytes) || other.remainingBytes == remainingBytes)&&(identical(other.downloadRate, downloadRate) || other.downloadRate == downloadRate)&&(identical(other.uploadRate, uploadRate) || other.uploadRate == uploadRate)&&(identical(other.eta, eta) || other.eta == eta));
}


@override
int get hashCode => Object.hash(runtimeType,trackedCount,liveCount,completedCount,activeCount,downloadingCount,preparingCount,pausedCount,waitingForNetworkCount,failedCount,progressFraction,progressIsEstimated,totalBytes,receivedBytes,remainingBytes,downloadRate,uploadRate,eta);

@override
String toString() {
  return 'DownloadTransferSummary(trackedCount: $trackedCount, liveCount: $liveCount, completedCount: $completedCount, activeCount: $activeCount, downloadingCount: $downloadingCount, preparingCount: $preparingCount, pausedCount: $pausedCount, waitingForNetworkCount: $waitingForNetworkCount, failedCount: $failedCount, progressFraction: $progressFraction, progressIsEstimated: $progressIsEstimated, totalBytes: $totalBytes, receivedBytes: $receivedBytes, remainingBytes: $remainingBytes, downloadRate: $downloadRate, uploadRate: $uploadRate, eta: $eta)';
}


}

/// @nodoc
abstract mixin class $DownloadTransferSummaryCopyWith<$Res>  {
  factory $DownloadTransferSummaryCopyWith(DownloadTransferSummary value, $Res Function(DownloadTransferSummary) _then) = _$DownloadTransferSummaryCopyWithImpl;
@useResult
$Res call({
 int trackedCount, int liveCount, int completedCount, int activeCount, int downloadingCount, int preparingCount, int pausedCount, int waitingForNetworkCount, int failedCount, double progressFraction, bool progressIsEstimated, int? totalBytes, int? receivedBytes, int? remainingBytes, int downloadRate, int uploadRate, Duration? eta
});




}
/// @nodoc
class _$DownloadTransferSummaryCopyWithImpl<$Res>
    implements $DownloadTransferSummaryCopyWith<$Res> {
  _$DownloadTransferSummaryCopyWithImpl(this._self, this._then);

  final DownloadTransferSummary _self;
  final $Res Function(DownloadTransferSummary) _then;

/// Create a copy of DownloadTransferSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackedCount = null,Object? liveCount = null,Object? completedCount = null,Object? activeCount = null,Object? downloadingCount = null,Object? preparingCount = null,Object? pausedCount = null,Object? waitingForNetworkCount = null,Object? failedCount = null,Object? progressFraction = null,Object? progressIsEstimated = null,Object? totalBytes = freezed,Object? receivedBytes = freezed,Object? remainingBytes = freezed,Object? downloadRate = null,Object? uploadRate = null,Object? eta = freezed,}) {
  return _then(_self.copyWith(
trackedCount: null == trackedCount ? _self.trackedCount : trackedCount // ignore: cast_nullable_to_non_nullable
as int,liveCount: null == liveCount ? _self.liveCount : liveCount // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,activeCount: null == activeCount ? _self.activeCount : activeCount // ignore: cast_nullable_to_non_nullable
as int,downloadingCount: null == downloadingCount ? _self.downloadingCount : downloadingCount // ignore: cast_nullable_to_non_nullable
as int,preparingCount: null == preparingCount ? _self.preparingCount : preparingCount // ignore: cast_nullable_to_non_nullable
as int,pausedCount: null == pausedCount ? _self.pausedCount : pausedCount // ignore: cast_nullable_to_non_nullable
as int,waitingForNetworkCount: null == waitingForNetworkCount ? _self.waitingForNetworkCount : waitingForNetworkCount // ignore: cast_nullable_to_non_nullable
as int,failedCount: null == failedCount ? _self.failedCount : failedCount // ignore: cast_nullable_to_non_nullable
as int,progressFraction: null == progressFraction ? _self.progressFraction : progressFraction // ignore: cast_nullable_to_non_nullable
as double,progressIsEstimated: null == progressIsEstimated ? _self.progressIsEstimated : progressIsEstimated // ignore: cast_nullable_to_non_nullable
as bool,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,receivedBytes: freezed == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int?,remainingBytes: freezed == remainingBytes ? _self.remainingBytes : remainingBytes // ignore: cast_nullable_to_non_nullable
as int?,downloadRate: null == downloadRate ? _self.downloadRate : downloadRate // ignore: cast_nullable_to_non_nullable
as int,uploadRate: null == uploadRate ? _self.uploadRate : uploadRate // ignore: cast_nullable_to_non_nullable
as int,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}

}


/// Adds pattern-matching-related methods to [DownloadTransferSummary].
extension DownloadTransferSummaryPatterns on DownloadTransferSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadTransferSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadTransferSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadTransferSummary value)  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadTransferSummary value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int trackedCount,  int liveCount,  int completedCount,  int activeCount,  int downloadingCount,  int preparingCount,  int pausedCount,  int waitingForNetworkCount,  int failedCount,  double progressFraction,  bool progressIsEstimated,  int? totalBytes,  int? receivedBytes,  int? remainingBytes,  int downloadRate,  int uploadRate,  Duration? eta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadTransferSummary() when $default != null:
return $default(_that.trackedCount,_that.liveCount,_that.completedCount,_that.activeCount,_that.downloadingCount,_that.preparingCount,_that.pausedCount,_that.waitingForNetworkCount,_that.failedCount,_that.progressFraction,_that.progressIsEstimated,_that.totalBytes,_that.receivedBytes,_that.remainingBytes,_that.downloadRate,_that.uploadRate,_that.eta);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int trackedCount,  int liveCount,  int completedCount,  int activeCount,  int downloadingCount,  int preparingCount,  int pausedCount,  int waitingForNetworkCount,  int failedCount,  double progressFraction,  bool progressIsEstimated,  int? totalBytes,  int? receivedBytes,  int? remainingBytes,  int downloadRate,  int uploadRate,  Duration? eta)  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferSummary():
return $default(_that.trackedCount,_that.liveCount,_that.completedCount,_that.activeCount,_that.downloadingCount,_that.preparingCount,_that.pausedCount,_that.waitingForNetworkCount,_that.failedCount,_that.progressFraction,_that.progressIsEstimated,_that.totalBytes,_that.receivedBytes,_that.remainingBytes,_that.downloadRate,_that.uploadRate,_that.eta);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int trackedCount,  int liveCount,  int completedCount,  int activeCount,  int downloadingCount,  int preparingCount,  int pausedCount,  int waitingForNetworkCount,  int failedCount,  double progressFraction,  bool progressIsEstimated,  int? totalBytes,  int? receivedBytes,  int? remainingBytes,  int downloadRate,  int uploadRate,  Duration? eta)?  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferSummary() when $default != null:
return $default(_that.trackedCount,_that.liveCount,_that.completedCount,_that.activeCount,_that.downloadingCount,_that.preparingCount,_that.pausedCount,_that.waitingForNetworkCount,_that.failedCount,_that.progressFraction,_that.progressIsEstimated,_that.totalBytes,_that.receivedBytes,_that.remainingBytes,_that.downloadRate,_that.uploadRate,_that.eta);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadTransferSummary implements DownloadTransferSummary {
  const _DownloadTransferSummary({required this.trackedCount, required this.liveCount, required this.completedCount, required this.activeCount, required this.downloadingCount, required this.preparingCount, required this.pausedCount, required this.waitingForNetworkCount, required this.failedCount, required this.progressFraction, required this.progressIsEstimated, this.totalBytes, this.receivedBytes, this.remainingBytes, required this.downloadRate, required this.uploadRate, this.eta});
  

@override final  int trackedCount;
@override final  int liveCount;
@override final  int completedCount;
@override final  int activeCount;
@override final  int downloadingCount;
@override final  int preparingCount;
@override final  int pausedCount;
@override final  int waitingForNetworkCount;
@override final  int failedCount;
@override final  double progressFraction;
@override final  bool progressIsEstimated;
@override final  int? totalBytes;
@override final  int? receivedBytes;
@override final  int? remainingBytes;
@override final  int downloadRate;
@override final  int uploadRate;
@override final  Duration? eta;

/// Create a copy of DownloadTransferSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadTransferSummaryCopyWith<_DownloadTransferSummary> get copyWith => __$DownloadTransferSummaryCopyWithImpl<_DownloadTransferSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadTransferSummary&&(identical(other.trackedCount, trackedCount) || other.trackedCount == trackedCount)&&(identical(other.liveCount, liveCount) || other.liveCount == liveCount)&&(identical(other.completedCount, completedCount) || other.completedCount == completedCount)&&(identical(other.activeCount, activeCount) || other.activeCount == activeCount)&&(identical(other.downloadingCount, downloadingCount) || other.downloadingCount == downloadingCount)&&(identical(other.preparingCount, preparingCount) || other.preparingCount == preparingCount)&&(identical(other.pausedCount, pausedCount) || other.pausedCount == pausedCount)&&(identical(other.waitingForNetworkCount, waitingForNetworkCount) || other.waitingForNetworkCount == waitingForNetworkCount)&&(identical(other.failedCount, failedCount) || other.failedCount == failedCount)&&(identical(other.progressFraction, progressFraction) || other.progressFraction == progressFraction)&&(identical(other.progressIsEstimated, progressIsEstimated) || other.progressIsEstimated == progressIsEstimated)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes)&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.remainingBytes, remainingBytes) || other.remainingBytes == remainingBytes)&&(identical(other.downloadRate, downloadRate) || other.downloadRate == downloadRate)&&(identical(other.uploadRate, uploadRate) || other.uploadRate == uploadRate)&&(identical(other.eta, eta) || other.eta == eta));
}


@override
int get hashCode => Object.hash(runtimeType,trackedCount,liveCount,completedCount,activeCount,downloadingCount,preparingCount,pausedCount,waitingForNetworkCount,failedCount,progressFraction,progressIsEstimated,totalBytes,receivedBytes,remainingBytes,downloadRate,uploadRate,eta);

@override
String toString() {
  return 'DownloadTransferSummary(trackedCount: $trackedCount, liveCount: $liveCount, completedCount: $completedCount, activeCount: $activeCount, downloadingCount: $downloadingCount, preparingCount: $preparingCount, pausedCount: $pausedCount, waitingForNetworkCount: $waitingForNetworkCount, failedCount: $failedCount, progressFraction: $progressFraction, progressIsEstimated: $progressIsEstimated, totalBytes: $totalBytes, receivedBytes: $receivedBytes, remainingBytes: $remainingBytes, downloadRate: $downloadRate, uploadRate: $uploadRate, eta: $eta)';
}


}

/// @nodoc
abstract mixin class _$DownloadTransferSummaryCopyWith<$Res> implements $DownloadTransferSummaryCopyWith<$Res> {
  factory _$DownloadTransferSummaryCopyWith(_DownloadTransferSummary value, $Res Function(_DownloadTransferSummary) _then) = __$DownloadTransferSummaryCopyWithImpl;
@override @useResult
$Res call({
 int trackedCount, int liveCount, int completedCount, int activeCount, int downloadingCount, int preparingCount, int pausedCount, int waitingForNetworkCount, int failedCount, double progressFraction, bool progressIsEstimated, int? totalBytes, int? receivedBytes, int? remainingBytes, int downloadRate, int uploadRate, Duration? eta
});




}
/// @nodoc
class __$DownloadTransferSummaryCopyWithImpl<$Res>
    implements _$DownloadTransferSummaryCopyWith<$Res> {
  __$DownloadTransferSummaryCopyWithImpl(this._self, this._then);

  final _DownloadTransferSummary _self;
  final $Res Function(_DownloadTransferSummary) _then;

/// Create a copy of DownloadTransferSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackedCount = null,Object? liveCount = null,Object? completedCount = null,Object? activeCount = null,Object? downloadingCount = null,Object? preparingCount = null,Object? pausedCount = null,Object? waitingForNetworkCount = null,Object? failedCount = null,Object? progressFraction = null,Object? progressIsEstimated = null,Object? totalBytes = freezed,Object? receivedBytes = freezed,Object? remainingBytes = freezed,Object? downloadRate = null,Object? uploadRate = null,Object? eta = freezed,}) {
  return _then(_DownloadTransferSummary(
trackedCount: null == trackedCount ? _self.trackedCount : trackedCount // ignore: cast_nullable_to_non_nullable
as int,liveCount: null == liveCount ? _self.liveCount : liveCount // ignore: cast_nullable_to_non_nullable
as int,completedCount: null == completedCount ? _self.completedCount : completedCount // ignore: cast_nullable_to_non_nullable
as int,activeCount: null == activeCount ? _self.activeCount : activeCount // ignore: cast_nullable_to_non_nullable
as int,downloadingCount: null == downloadingCount ? _self.downloadingCount : downloadingCount // ignore: cast_nullable_to_non_nullable
as int,preparingCount: null == preparingCount ? _self.preparingCount : preparingCount // ignore: cast_nullable_to_non_nullable
as int,pausedCount: null == pausedCount ? _self.pausedCount : pausedCount // ignore: cast_nullable_to_non_nullable
as int,waitingForNetworkCount: null == waitingForNetworkCount ? _self.waitingForNetworkCount : waitingForNetworkCount // ignore: cast_nullable_to_non_nullable
as int,failedCount: null == failedCount ? _self.failedCount : failedCount // ignore: cast_nullable_to_non_nullable
as int,progressFraction: null == progressFraction ? _self.progressFraction : progressFraction // ignore: cast_nullable_to_non_nullable
as double,progressIsEstimated: null == progressIsEstimated ? _self.progressIsEstimated : progressIsEstimated // ignore: cast_nullable_to_non_nullable
as bool,totalBytes: freezed == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int?,receivedBytes: freezed == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int?,remainingBytes: freezed == remainingBytes ? _self.remainingBytes : remainingBytes // ignore: cast_nullable_to_non_nullable
as int?,downloadRate: null == downloadRate ? _self.downloadRate : downloadRate // ignore: cast_nullable_to_non_nullable
as int,uploadRate: null == uploadRate ? _self.uploadRate : uploadRate // ignore: cast_nullable_to_non_nullable
as int,eta: freezed == eta ? _self.eta : eta // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}


}

/// @nodoc
mixin _$DownloadTransferReport {

 List<DownloadTransferItem> get items; DownloadTransferSummary get summary;
/// Create a copy of DownloadTransferReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DownloadTransferReportCopyWith<DownloadTransferReport> get copyWith => _$DownloadTransferReportCopyWithImpl<DownloadTransferReport>(this as DownloadTransferReport, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DownloadTransferReport&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.summary, summary) || other.summary == summary));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),summary);

@override
String toString() {
  return 'DownloadTransferReport(items: $items, summary: $summary)';
}


}

/// @nodoc
abstract mixin class $DownloadTransferReportCopyWith<$Res>  {
  factory $DownloadTransferReportCopyWith(DownloadTransferReport value, $Res Function(DownloadTransferReport) _then) = _$DownloadTransferReportCopyWithImpl;
@useResult
$Res call({
 List<DownloadTransferItem> items, DownloadTransferSummary summary
});


$DownloadTransferSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class _$DownloadTransferReportCopyWithImpl<$Res>
    implements $DownloadTransferReportCopyWith<$Res> {
  _$DownloadTransferReportCopyWithImpl(this._self, this._then);

  final DownloadTransferReport _self;
  final $Res Function(DownloadTransferReport) _then;

/// Create a copy of DownloadTransferReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? summary = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<DownloadTransferItem>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as DownloadTransferSummary,
  ));
}
/// Create a copy of DownloadTransferReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DownloadTransferSummaryCopyWith<$Res> get summary {
  
  return $DownloadTransferSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}


/// Adds pattern-matching-related methods to [DownloadTransferReport].
extension DownloadTransferReportPatterns on DownloadTransferReport {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DownloadTransferReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DownloadTransferReport() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DownloadTransferReport value)  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferReport():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DownloadTransferReport value)?  $default,){
final _that = this;
switch (_that) {
case _DownloadTransferReport() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<DownloadTransferItem> items,  DownloadTransferSummary summary)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DownloadTransferReport() when $default != null:
return $default(_that.items,_that.summary);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<DownloadTransferItem> items,  DownloadTransferSummary summary)  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferReport():
return $default(_that.items,_that.summary);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<DownloadTransferItem> items,  DownloadTransferSummary summary)?  $default,) {final _that = this;
switch (_that) {
case _DownloadTransferReport() when $default != null:
return $default(_that.items,_that.summary);case _:
  return null;

}
}

}

/// @nodoc


class _DownloadTransferReport implements DownloadTransferReport {
  const _DownloadTransferReport({required this.items, required this.summary});
  

@override final  List<DownloadTransferItem> items;
@override final  DownloadTransferSummary summary;

/// Create a copy of DownloadTransferReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DownloadTransferReportCopyWith<_DownloadTransferReport> get copyWith => __$DownloadTransferReportCopyWithImpl<_DownloadTransferReport>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DownloadTransferReport&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.summary, summary) || other.summary == summary));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),summary);

@override
String toString() {
  return 'DownloadTransferReport(items: $items, summary: $summary)';
}


}

/// @nodoc
abstract mixin class _$DownloadTransferReportCopyWith<$Res> implements $DownloadTransferReportCopyWith<$Res> {
  factory _$DownloadTransferReportCopyWith(_DownloadTransferReport value, $Res Function(_DownloadTransferReport) _then) = __$DownloadTransferReportCopyWithImpl;
@override @useResult
$Res call({
 List<DownloadTransferItem> items, DownloadTransferSummary summary
});


@override $DownloadTransferSummaryCopyWith<$Res> get summary;

}
/// @nodoc
class __$DownloadTransferReportCopyWithImpl<$Res>
    implements _$DownloadTransferReportCopyWith<$Res> {
  __$DownloadTransferReportCopyWithImpl(this._self, this._then);

  final _DownloadTransferReport _self;
  final $Res Function(_DownloadTransferReport) _then;

/// Create a copy of DownloadTransferReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? summary = null,}) {
  return _then(_DownloadTransferReport(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<DownloadTransferItem>,summary: null == summary ? _self.summary : summary // ignore: cast_nullable_to_non_nullable
as DownloadTransferSummary,
  ));
}

/// Create a copy of DownloadTransferReport
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DownloadTransferSummaryCopyWith<$Res> get summary {
  
  return $DownloadTransferSummaryCopyWith<$Res>(_self.summary, (value) {
    return _then(_self.copyWith(summary: value));
  });
}
}

// dart format on
