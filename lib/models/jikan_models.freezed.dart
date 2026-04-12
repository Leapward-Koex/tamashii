// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'jikan_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JikanAnimeSearchResult {

@JsonKey(name: 'mal_id') int get malId; String get title;@JsonKey(name: 'title_english') String? get titleEnglish; String? get type; int? get episodes;@JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson) String get imageUrl;
/// Create a copy of JikanAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JikanAnimeSearchResultCopyWith<JikanAnimeSearchResult> get copyWith => _$JikanAnimeSearchResultCopyWithImpl<JikanAnimeSearchResult>(this as JikanAnimeSearchResult, _$identity);

  /// Serializes this JikanAnimeSearchResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JikanAnimeSearchResult&&(identical(other.malId, malId) || other.malId == malId)&&(identical(other.title, title) || other.title == title)&&(identical(other.titleEnglish, titleEnglish) || other.titleEnglish == titleEnglish)&&(identical(other.type, type) || other.type == type)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,malId,title,titleEnglish,type,episodes,imageUrl);

@override
String toString() {
  return 'JikanAnimeSearchResult(malId: $malId, title: $title, titleEnglish: $titleEnglish, type: $type, episodes: $episodes, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class $JikanAnimeSearchResultCopyWith<$Res>  {
  factory $JikanAnimeSearchResultCopyWith(JikanAnimeSearchResult value, $Res Function(JikanAnimeSearchResult) _then) = _$JikanAnimeSearchResultCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'mal_id') int malId, String title,@JsonKey(name: 'title_english') String? titleEnglish, String? type, int? episodes,@JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson) String imageUrl
});




}
/// @nodoc
class _$JikanAnimeSearchResultCopyWithImpl<$Res>
    implements $JikanAnimeSearchResultCopyWith<$Res> {
  _$JikanAnimeSearchResultCopyWithImpl(this._self, this._then);

  final JikanAnimeSearchResult _self;
  final $Res Function(JikanAnimeSearchResult) _then;

/// Create a copy of JikanAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? malId = null,Object? title = null,Object? titleEnglish = freezed,Object? type = freezed,Object? episodes = freezed,Object? imageUrl = null,}) {
  return _then(_self.copyWith(
malId: null == malId ? _self.malId : malId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,titleEnglish: freezed == titleEnglish ? _self.titleEnglish : titleEnglish // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,episodes: freezed == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [JikanAnimeSearchResult].
extension JikanAnimeSearchResultPatterns on JikanAnimeSearchResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JikanAnimeSearchResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JikanAnimeSearchResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JikanAnimeSearchResult value)  $default,){
final _that = this;
switch (_that) {
case _JikanAnimeSearchResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JikanAnimeSearchResult value)?  $default,){
final _that = this;
switch (_that) {
case _JikanAnimeSearchResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'mal_id')  int malId,  String title, @JsonKey(name: 'title_english')  String? titleEnglish,  String? type,  int? episodes, @JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson)  String imageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JikanAnimeSearchResult() when $default != null:
return $default(_that.malId,_that.title,_that.titleEnglish,_that.type,_that.episodes,_that.imageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'mal_id')  int malId,  String title, @JsonKey(name: 'title_english')  String? titleEnglish,  String? type,  int? episodes, @JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson)  String imageUrl)  $default,) {final _that = this;
switch (_that) {
case _JikanAnimeSearchResult():
return $default(_that.malId,_that.title,_that.titleEnglish,_that.type,_that.episodes,_that.imageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'mal_id')  int malId,  String title, @JsonKey(name: 'title_english')  String? titleEnglish,  String? type,  int? episodes, @JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson)  String imageUrl)?  $default,) {final _that = this;
switch (_that) {
case _JikanAnimeSearchResult() when $default != null:
return $default(_that.malId,_that.title,_that.titleEnglish,_that.type,_that.episodes,_that.imageUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JikanAnimeSearchResult extends JikanAnimeSearchResult {
  const _JikanAnimeSearchResult({@JsonKey(name: 'mal_id') required this.malId, required this.title, @JsonKey(name: 'title_english') this.titleEnglish, this.type, this.episodes, @JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson) this.imageUrl = ''}): super._();
  factory _JikanAnimeSearchResult.fromJson(Map<String, dynamic> json) => _$JikanAnimeSearchResultFromJson(json);

@override@JsonKey(name: 'mal_id') final  int malId;
@override final  String title;
@override@JsonKey(name: 'title_english') final  String? titleEnglish;
@override final  String? type;
@override final  int? episodes;
@override@JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson) final  String imageUrl;

/// Create a copy of JikanAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JikanAnimeSearchResultCopyWith<_JikanAnimeSearchResult> get copyWith => __$JikanAnimeSearchResultCopyWithImpl<_JikanAnimeSearchResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JikanAnimeSearchResultToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JikanAnimeSearchResult&&(identical(other.malId, malId) || other.malId == malId)&&(identical(other.title, title) || other.title == title)&&(identical(other.titleEnglish, titleEnglish) || other.titleEnglish == titleEnglish)&&(identical(other.type, type) || other.type == type)&&(identical(other.episodes, episodes) || other.episodes == episodes)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,malId,title,titleEnglish,type,episodes,imageUrl);

@override
String toString() {
  return 'JikanAnimeSearchResult(malId: $malId, title: $title, titleEnglish: $titleEnglish, type: $type, episodes: $episodes, imageUrl: $imageUrl)';
}


}

/// @nodoc
abstract mixin class _$JikanAnimeSearchResultCopyWith<$Res> implements $JikanAnimeSearchResultCopyWith<$Res> {
  factory _$JikanAnimeSearchResultCopyWith(_JikanAnimeSearchResult value, $Res Function(_JikanAnimeSearchResult) _then) = __$JikanAnimeSearchResultCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'mal_id') int malId, String title,@JsonKey(name: 'title_english') String? titleEnglish, String? type, int? episodes,@JsonKey(name: 'images', fromJson: _jikanImageUrlFromJson, toJson: _jikanImageUrlToJson) String imageUrl
});




}
/// @nodoc
class __$JikanAnimeSearchResultCopyWithImpl<$Res>
    implements _$JikanAnimeSearchResultCopyWith<$Res> {
  __$JikanAnimeSearchResultCopyWithImpl(this._self, this._then);

  final _JikanAnimeSearchResult _self;
  final $Res Function(_JikanAnimeSearchResult) _then;

/// Create a copy of JikanAnimeSearchResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? malId = null,Object? title = null,Object? titleEnglish = freezed,Object? type = freezed,Object? episodes = freezed,Object? imageUrl = null,}) {
  return _then(_JikanAnimeSearchResult(
malId: null == malId ? _self.malId : malId // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,titleEnglish: freezed == titleEnglish ? _self.titleEnglish : titleEnglish // ignore: cast_nullable_to_non_nullable
as String?,type: freezed == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String?,episodes: freezed == episodes ? _self.episodes : episodes // ignore: cast_nullable_to_non_nullable
as int?,imageUrl: null == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
