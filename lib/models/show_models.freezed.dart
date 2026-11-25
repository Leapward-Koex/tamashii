// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'show_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookmarkedShowInfo {

 String get imageUrl; int get releaseDayOfWeek; String get showName;@JsonKey(name: 'jikanId') int? get malId; BookmarkedShowSource get source;
/// Create a copy of BookmarkedShowInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookmarkedShowInfoCopyWith<BookmarkedShowInfo> get copyWith => _$BookmarkedShowInfoCopyWithImpl<BookmarkedShowInfo>(this as BookmarkedShowInfo, _$identity);

  /// Serializes this BookmarkedShowInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookmarkedShowInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookmarkedShowInfo&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.releaseDayOfWeek, _this.releaseDayOfWeek) || other.releaseDayOfWeek == _this.releaseDayOfWeek)&&(identical(other.showName, _this.showName) || other.showName == _this.showName)&&(identical(other.malId, _this.malId) || other.malId == _this.malId)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookmarkedShowInfo;
  return Object.hash(runtimeType,_this.imageUrl,_this.releaseDayOfWeek,_this.showName,_this.malId,_this.source);
}

@override
String toString() {
  final _this = this as BookmarkedShowInfo;
  return 'BookmarkedShowInfo(imageUrl: ${_this.imageUrl}, releaseDayOfWeek: ${_this.releaseDayOfWeek}, showName: ${_this.showName}, malId: ${_this.malId}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $BookmarkedShowInfoCopyWith<$Res>  {
  factory $BookmarkedShowInfoCopyWith(BookmarkedShowInfo value, $Res Function(BookmarkedShowInfo) _then) = _$BookmarkedShowInfoCopyWithImpl;
@useResult
$Res call({
 String imageUrl, int releaseDayOfWeek, String showName,@JsonKey(name: 'jikanId') int? malId, BookmarkedShowSource source
});




}
/// @nodoc
class _$BookmarkedShowInfoCopyWithImpl<$Res>
    implements $BookmarkedShowInfoCopyWith<$Res> {
  _$BookmarkedShowInfoCopyWithImpl(this._self, this._then);

  final BookmarkedShowInfo _self;
  final $Res Function(BookmarkedShowInfo) _then;

/// Create a copy of BookmarkedShowInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? imageUrl = null,Object? releaseDayOfWeek = null,Object? showName = null,Object? malId = freezed,Object? source = null,}) {
  return _then(BookmarkedShowInfo(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,releaseDayOfWeek: null == releaseDayOfWeek ? _self.releaseDayOfWeek : releaseDayOfWeek // ignore: cast_nullable_to_non_nullable
as int,showName: null == showName ? _self.showName : showName // ignore: cast_nullable_to_non_nullable
as String,malId: freezed == malId ? _self.malId : malId // ignore: cast_nullable_to_non_nullable
as int?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as BookmarkedShowSource,
  ));
}

}


/// Adds pattern-matching-related methods to [BookmarkedShowInfo].
extension BookmarkedShowInfoPatterns on BookmarkedShowInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookmarkedShowInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookmarkedShowInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookmarkedShowInfo value)  $default,){
final _that = this;
switch (_that) {
case _BookmarkedShowInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookmarkedShowInfo value)?  $default,){
final _that = this;
switch (_that) {
case _BookmarkedShowInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String imageUrl,  int releaseDayOfWeek,  String showName, @JsonKey(name: 'jikanId')  int? malId,  BookmarkedShowSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookmarkedShowInfo() when $default != null:
return $default(_that.imageUrl,_that.releaseDayOfWeek,_that.showName,_that.malId,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String imageUrl,  int releaseDayOfWeek,  String showName, @JsonKey(name: 'jikanId')  int? malId,  BookmarkedShowSource source)  $default,) {final _that = this;
switch (_that) {
case _BookmarkedShowInfo():
return $default(_that.imageUrl,_that.releaseDayOfWeek,_that.showName,_that.malId,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String imageUrl,  int releaseDayOfWeek,  String showName, @JsonKey(name: 'jikanId')  int? malId,  BookmarkedShowSource source)?  $default,) {final _that = this;
switch (_that) {
case _BookmarkedShowInfo() when $default != null:
return $default(_that.imageUrl,_that.releaseDayOfWeek,_that.showName,_that.malId,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookmarkedShowInfo extends BookmarkedShowInfo {
  const _BookmarkedShowInfo({required this.imageUrl, required this.releaseDayOfWeek, required this.showName, @JsonKey(name: 'jikanId') this.malId, this.source = BookmarkedShowSource.subsplease}): super._();
  factory _BookmarkedShowInfo.fromJson(Map<String, dynamic> json) => _$BookmarkedShowInfoFromJson(json);

@override final  String imageUrl;
@override final  int releaseDayOfWeek;
@override final  String showName;
@override@JsonKey(name: 'jikanId') final  int? malId;
@override@JsonKey() final  BookmarkedShowSource source;

/// Create a copy of BookmarkedShowInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookmarkedShowInfoCopyWith<_BookmarkedShowInfo> get copyWith => __$BookmarkedShowInfoCopyWithImpl<_BookmarkedShowInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookmarkedShowInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookmarkedShowInfo&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.releaseDayOfWeek, releaseDayOfWeek) || other.releaseDayOfWeek == releaseDayOfWeek)&&(identical(other.showName, showName) || other.showName == showName)&&(identical(other.malId, malId) || other.malId == malId)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,imageUrl,releaseDayOfWeek,showName,malId,source);
}

@override
String toString() {
    return 'BookmarkedShowInfo(imageUrl: $imageUrl, releaseDayOfWeek: $releaseDayOfWeek, showName: $showName, malId: $malId, source: $source)';
}


}

/// @nodoc
abstract mixin class _$BookmarkedShowInfoCopyWith<$Res> implements $BookmarkedShowInfoCopyWith<$Res> {
  factory _$BookmarkedShowInfoCopyWith(_BookmarkedShowInfo value, $Res Function(_BookmarkedShowInfo) _then) = __$BookmarkedShowInfoCopyWithImpl;
@override @useResult
$Res call({
 String imageUrl, int releaseDayOfWeek, String showName,@JsonKey(name: 'jikanId') int? malId, BookmarkedShowSource source
});




}
/// @nodoc
class __$BookmarkedShowInfoCopyWithImpl<$Res>
    implements _$BookmarkedShowInfoCopyWith<$Res> {
  __$BookmarkedShowInfoCopyWithImpl(this._self, this._then);

  final _BookmarkedShowInfo _self;
  final $Res Function(_BookmarkedShowInfo) _then;

/// Create a copy of BookmarkedShowInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? imageUrl = null,Object? releaseDayOfWeek = null,Object? showName = null,Object? malId = freezed,Object? source = null,}) {
  return _then(_BookmarkedShowInfo(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,releaseDayOfWeek: null == releaseDayOfWeek ? _self.releaseDayOfWeek : releaseDayOfWeek // ignore: cast_nullable_to_non_nullable
as int,showName: null == showName ? _self.showName : showName // ignore: cast_nullable_to_non_nullable
as String,malId: freezed == malId ? _self.malId : malId // ignore: cast_nullable_to_non_nullable
as int?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as BookmarkedShowSource,
  ));
}


}

// dart format on
