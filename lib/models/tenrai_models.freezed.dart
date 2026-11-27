// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tenrai_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TenraiAnimeSearchResult {

@JsonKey(name: 'mal_id') int get malId; String get title;@JsonKey(name: 'title_english') String? get titleEnglish; String? get type; int? get episodes;@JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson) String get imageUrl;@JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false) String? get largeImageUrl;
/// Create a copy of TenraiAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TenraiAnimeSearchResultCopyWith<TenraiAnimeSearchResult> get copyWith => _$TenraiAnimeSearchResultCopyWithImpl<TenraiAnimeSearchResult>(this as TenraiAnimeSearchResult, _$identity);

  /// Serializes this TenraiAnimeSearchResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TenraiAnimeSearchResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TenraiAnimeSearchResult&&(identical(other.malId, _this.malId) || other.malId == _this.malId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.titleEnglish, _this.titleEnglish) || other.titleEnglish == _this.titleEnglish)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.episodes, _this.episodes) || other.episodes == _this.episodes)&&(identical(other.imageUrl, _this.imageUrl) || other.imageUrl == _this.imageUrl)&&(identical(other.largeImageUrl, _this.largeImageUrl) || other.largeImageUrl == _this.largeImageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TenraiAnimeSearchResult;
  return Object.hash(runtimeType,_this.malId,_this.title,_this.titleEnglish,_this.type,_this.episodes,_this.imageUrl,_this.largeImageUrl);
}

@override
String toString() {
  final _this = this as TenraiAnimeSearchResult;
  return 'TenraiAnimeSearchResult(malId: ${_this.malId}, title: ${_this.title}, titleEnglish: ${_this.titleEnglish}, type: ${_this.type}, episodes: ${_this.episodes}, imageUrl: ${_this.imageUrl}, largeImageUrl: ${_this.largeImageUrl})';
}


}

/// @nodoc
abstract mixin class $TenraiAnimeSearchResultCopyWith<$Res>  {
  factory $TenraiAnimeSearchResultCopyWith(TenraiAnimeSearchResult value, $Res Function(TenraiAnimeSearchResult) _then) = _$TenraiAnimeSearchResultCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'mal_id') int malId, String title,@JsonKey(name: 'title_english') String? titleEnglish, String? type, int? episodes,@JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson) String imageUrl,@JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false) String? largeImageUrl
});




}
/// @nodoc
class _$TenraiAnimeSearchResultCopyWithImpl<$Res>
    implements $TenraiAnimeSearchResultCopyWith<$Res> {
  _$TenraiAnimeSearchResultCopyWithImpl(this._self, this._then);

  final TenraiAnimeSearchResult _self;
  final $Res Function(TenraiAnimeSearchResult) _then;

/// Create a copy of TenraiAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? malId = null,Object? title = null,Object? titleEnglish = freezed,Object? type = freezed,Object? episodes = freezed,Object? imageUrl = null,Object? largeImageUrl = freezed,}) {
  return _then(TenraiAnimeSearchResult(
malId: null == malId ? _self.malId : malId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,titleEnglish: freezed == titleEnglish ? _self.titleEnglish : titleEnglish // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,episodes: freezed == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,largeImageUrl: freezed == largeImageUrl ? _self.largeImageUrl : largeImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TenraiAnimeSearchResult].
extension TenraiAnimeSearchResultPatterns on TenraiAnimeSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TenraiAnimeSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TenraiAnimeSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TenraiAnimeSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _TenraiAnimeSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TenraiAnimeSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _TenraiAnimeSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'mal_id')  int malId,  String title, @JsonKey(name: 'title_english')  String? titleEnglish,  String? type,  int? episodes, @JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson)  String imageUrl, @JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false)  String? largeImageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TenraiAnimeSearchResult() when $default != null:
return $default(_that.malId,_that.title,_that.titleEnglish,_that.type,_that.episodes,_that.imageUrl,_that.largeImageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'mal_id')  int malId,  String title, @JsonKey(name: 'title_english')  String? titleEnglish,  String? type,  int? episodes, @JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson)  String imageUrl, @JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false)  String? largeImageUrl)  $default,) {final _that = this;
switch (_that) {
case _TenraiAnimeSearchResult():
return $default(_that.malId,_that.title,_that.titleEnglish,_that.type,_that.episodes,_that.imageUrl,_that.largeImageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'mal_id')  int malId,  String title, @JsonKey(name: 'title_english')  String? titleEnglish,  String? type,  int? episodes, @JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson)  String imageUrl, @JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false)  String? largeImageUrl)?  $default,) {final _that = this;
switch (_that) {
case _TenraiAnimeSearchResult() when $default != null:
return $default(_that.malId,_that.title,_that.titleEnglish,_that.type,_that.episodes,_that.imageUrl,_that.largeImageUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TenraiAnimeSearchResult extends TenraiAnimeSearchResult {
  const _TenraiAnimeSearchResult({@JsonKey(name: 'mal_id') required this.malId, required this.title, @JsonKey(name: 'title_english') this.titleEnglish, this.type, this.episodes, @JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson) this.imageUrl = '', @JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false) this.largeImageUrl}): super._();
  factory _TenraiAnimeSearchResult.fromJson(Map<String, dynamic> json) => _$TenraiAnimeSearchResultFromJson(json);

@override@JsonKey(name: 'mal_id') final  int malId;
@override final  String title;
@override@JsonKey(name: 'title_english') final  String? titleEnglish;
@override final  String? type;
@override final  int? episodes;
@override@JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson) final  String imageUrl;
@override@JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false) final  String? largeImageUrl;

/// Create a copy of TenraiAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TenraiAnimeSearchResultCopyWith<_TenraiAnimeSearchResult> get copyWith => __$TenraiAnimeSearchResultCopyWithImpl<_TenraiAnimeSearchResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TenraiAnimeSearchResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TenraiAnimeSearchResult&&(identical(other.malId, malId) || other.malId == malId)&&(identical(other.title, title) || other.title == title)&&(identical(other.titleEnglish, titleEnglish) || other.titleEnglish == titleEnglish)&&(identical(other.type, type) || other.type == type)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&(identical(other.largeImageUrl, largeImageUrl) || other.largeImageUrl == largeImageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,malId,title,titleEnglish,type,episodes,imageUrl,largeImageUrl);
}

@override
String toString() {
    return 'TenraiAnimeSearchResult(malId: $malId, title: $title, titleEnglish: $titleEnglish, type: $type, episodes: $episodes, imageUrl: $imageUrl, largeImageUrl: $largeImageUrl)';
}


}

/// @nodoc
abstract mixin class _$TenraiAnimeSearchResultCopyWith<$Res> implements $TenraiAnimeSearchResultCopyWith<$Res> {
  factory _$TenraiAnimeSearchResultCopyWith(_TenraiAnimeSearchResult value, $Res Function(_TenraiAnimeSearchResult) _then) = __$TenraiAnimeSearchResultCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'mal_id') int malId, String title,@JsonKey(name: 'title_english') String? titleEnglish, String? type, int? episodes,@JsonKey(name: 'images', fromJson: _tenraiImageUrlFromJson, toJson: _tenraiImageUrlToJson) String imageUrl,@JsonKey(readValue: _readTenraiLargeImageUrl, includeIfNull: false) String? largeImageUrl
});




}
/// @nodoc
class __$TenraiAnimeSearchResultCopyWithImpl<$Res>
    implements _$TenraiAnimeSearchResultCopyWith<$Res> {
  __$TenraiAnimeSearchResultCopyWithImpl(this._self, this._then);

  final _TenraiAnimeSearchResult _self;
  final $Res Function(_TenraiAnimeSearchResult) _then;

/// Create a copy of TenraiAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? malId = null,Object? title = null,Object? titleEnglish = freezed,Object? type = freezed,Object? episodes = freezed,Object? imageUrl = null,Object? largeImageUrl = freezed,}) {
  return _then(_TenraiAnimeSearchResult(
malId: null == malId ? _self.malId : malId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,titleEnglish: freezed == titleEnglish ? _self.titleEnglish : titleEnglish // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,episodes: freezed == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,largeImageUrl: freezed == largeImageUrl ? _self.largeImageUrl : largeImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
