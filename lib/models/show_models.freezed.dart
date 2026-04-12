// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'show_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookmarkedShowInfo {

 String get imageUrl; int get releaseDayOfWeek; String get showName; int? get jikanId; BookmarkedShowSource get source;
/// Create a copy of BookmarkedShowInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookmarkedShowInfoCopyWith<BookmarkedShowInfo> get copyWith => _$BookmarkedShowInfoCopyWithImpl<BookmarkedShowInfo>(this as BookmarkedShowInfo, _$identity);

  /// Serializes this BookmarkedShowInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookmarkedShowInfo&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.releaseDayOfWeek, releaseDayOfWeek) || other.releaseDayOfWeek == releaseDayOfWeek)&&(identical(other.showName, showName) || other.showName == showName)&&(identical(other.jikanId, jikanId) || other.jikanId == jikanId)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,imageUrl,releaseDayOfWeek,showName,jikanId,source);

@override
String toString() {
  return 'BookmarkedShowInfo(imageUrl: $imageUrl, releaseDayOfWeek: $releaseDayOfWeek, showName: $showName, jikanId: $jikanId, source: $source)';
}


}

/// @nodoc
abstract mixin class $BookmarkedShowInfoCopyWith<$Res>  {
  factory $BookmarkedShowInfoCopyWith(BookmarkedShowInfo value, $Res Function(BookmarkedShowInfo) _then) = _$BookmarkedShowInfoCopyWithImpl;
@useResult
$Res call({
 String imageUrl, int releaseDayOfWeek, String showName, int? jikanId, BookmarkedShowSource source
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
@pragma('vm:prefer-inline') @override $Res call({Object? imageUrl = null,Object? releaseDayOfWeek = null,Object? showName = null,Object? jikanId = freezed,Object? source = null,}) {
  return _then(_self.copyWith(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,releaseDayOfWeek: null == releaseDayOfWeek ? _self.releaseDayOfWeek : releaseDayOfWeek // ignore: cast_nullable_to_non_nullable
as int,showName: null == showName ? _self.showName : showName // ignore: cast_nullable_to_non_nullable
as String,jikanId: freezed == jikanId ? _self.jikanId : jikanId // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String imageUrl,  int releaseDayOfWeek,  String showName,  int? jikanId,  BookmarkedShowSource source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookmarkedShowInfo() when $default != null:
return $default(_that.imageUrl,_that.releaseDayOfWeek,_that.showName,_that.jikanId,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String imageUrl,  int releaseDayOfWeek,  String showName,  int? jikanId,  BookmarkedShowSource source)  $default,) {final _that = this;
switch (_that) {
case _BookmarkedShowInfo():
return $default(_that.imageUrl,_that.releaseDayOfWeek,_that.showName,_that.jikanId,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String imageUrl,  int releaseDayOfWeek,  String showName,  int? jikanId,  BookmarkedShowSource source)?  $default,) {final _that = this;
switch (_that) {
case _BookmarkedShowInfo() when $default != null:
return $default(_that.imageUrl,_that.releaseDayOfWeek,_that.showName,_that.jikanId,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookmarkedShowInfo extends BookmarkedShowInfo {
  const _BookmarkedShowInfo({required this.imageUrl, required this.releaseDayOfWeek, required this.showName, this.jikanId, this.source = BookmarkedShowSource.subsplease}): super._();
  factory _BookmarkedShowInfo.fromJson(Map<String, dynamic> json) => _$BookmarkedShowInfoFromJson(json);

@override final  String imageUrl;
@override final  int releaseDayOfWeek;
@override final  String showName;
@override final  int? jikanId;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookmarkedShowInfo&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.releaseDayOfWeek, releaseDayOfWeek) || other.releaseDayOfWeek == releaseDayOfWeek)&&(identical(other.showName, showName) || other.showName == showName)&&(identical(other.jikanId, jikanId) || other.jikanId == jikanId)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,imageUrl,releaseDayOfWeek,showName,jikanId,source);

@override
String toString() {
  return 'BookmarkedShowInfo(imageUrl: $imageUrl, releaseDayOfWeek: $releaseDayOfWeek, showName: $showName, jikanId: $jikanId, source: $source)';
}


}

/// @nodoc
abstract mixin class _$BookmarkedShowInfoCopyWith<$Res> implements $BookmarkedShowInfoCopyWith<$Res> {
  factory _$BookmarkedShowInfoCopyWith(_BookmarkedShowInfo value, $Res Function(_BookmarkedShowInfo) _then) = __$BookmarkedShowInfoCopyWithImpl;
@override @useResult
$Res call({
 String imageUrl, int releaseDayOfWeek, String showName, int? jikanId, BookmarkedShowSource source
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
@override @pragma('vm:prefer-inline') $Res call({Object? imageUrl = null,Object? releaseDayOfWeek = null,Object? showName = null,Object? jikanId = freezed,Object? source = null,}) {
  return _then(_BookmarkedShowInfo(
imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,releaseDayOfWeek: null == releaseDayOfWeek ? _self.releaseDayOfWeek : releaseDayOfWeek // ignore: cast_nullable_to_non_nullable
as int,showName: null == showName ? _self.showName : showName // ignore: cast_nullable_to_non_nullable
as String,jikanId: freezed == jikanId ? _self.jikanId : jikanId // ignore: cast_nullable_to_non_nullable
as int?,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as BookmarkedShowSource,
  ));
}


}

// dart format on
