// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'show_catalog_match.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShowCatalogTarget {

 String get title; String? get episode; String? get page; bool get forceReleaseScope; int? get savedMalId; String? get savedImageUrl;
/// Create a copy of ShowCatalogTarget
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShowCatalogTargetCopyWith<ShowCatalogTarget> get copyWith => _$ShowCatalogTargetCopyWithImpl<ShowCatalogTarget>(this as ShowCatalogTarget, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ShowCatalogTarget;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShowCatalogTarget&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.episode, _this.episode) || other.episode == _this.episode)&&(identical(other.page, _this.page) || other.page == _this.page)&&(identical(other.forceReleaseScope, _this.forceReleaseScope) || other.forceReleaseScope == _this.forceReleaseScope)&&(identical(other.savedMalId, _this.savedMalId) || other.savedMalId == _this.savedMalId)&&(identical(other.savedImageUrl, _this.savedImageUrl) || other.savedImageUrl == _this.savedImageUrl));
}


@override
int get hashCode {
  final _this = this as ShowCatalogTarget;
  return Object.hash(runtimeType,_this.title,_this.episode,_this.page,_this.forceReleaseScope,_this.savedMalId,_this.savedImageUrl);
}

@override
String toString() {
  final _this = this as ShowCatalogTarget;
  return 'ShowCatalogTarget(title: ${_this.title}, episode: ${_this.episode}, page: ${_this.page}, forceReleaseScope: ${_this.forceReleaseScope}, savedMalId: ${_this.savedMalId}, savedImageUrl: ${_this.savedImageUrl})';
}


}

/// @nodoc
abstract mixin class $ShowCatalogTargetCopyWith<$Res>  {
  factory $ShowCatalogTargetCopyWith(ShowCatalogTarget value, $Res Function(ShowCatalogTarget) _then) = _$ShowCatalogTargetCopyWithImpl;
@useResult
$Res call({
 String title, String? episode, String? page, bool forceReleaseScope, int? savedMalId, String? savedImageUrl
});




}
/// @nodoc
class _$ShowCatalogTargetCopyWithImpl<$Res>
    implements $ShowCatalogTargetCopyWith<$Res> {
  _$ShowCatalogTargetCopyWithImpl(this._self, this._then);

  final ShowCatalogTarget _self;
  final $Res Function(ShowCatalogTarget) _then;

/// Create a copy of ShowCatalogTarget
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? episode = freezed,Object? page = freezed,Object? forceReleaseScope = null,Object? savedMalId = freezed,Object? savedImageUrl = freezed,}) {
  return _then(ShowCatalogTarget(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as String?,page: freezed == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as String?,forceReleaseScope: null == forceReleaseScope ? _self.forceReleaseScope : forceReleaseScope // ignore: cast_nullable_to_non_nullable
as bool,savedMalId: freezed == savedMalId ? _self.savedMalId : savedMalId // ignore: cast_nullable_to_non_nullable
as int?,savedImageUrl: freezed == savedImageUrl ? _self.savedImageUrl : savedImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ShowCatalogTarget].
extension ShowCatalogTargetPatterns on ShowCatalogTarget {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShowCatalogTarget value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShowCatalogTarget() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShowCatalogTarget value)  $default,){
final _that = this;
switch (_that) {
case _ShowCatalogTarget():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShowCatalogTarget value)?  $default,){
final _that = this;
switch (_that) {
case _ShowCatalogTarget() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  String? episode,  String? page,  bool forceReleaseScope,  int? savedMalId,  String? savedImageUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShowCatalogTarget() when $default != null:
return $default(_that.title,_that.episode,_that.page,_that.forceReleaseScope,_that.savedMalId,_that.savedImageUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  String? episode,  String? page,  bool forceReleaseScope,  int? savedMalId,  String? savedImageUrl)  $default,) {final _that = this;
switch (_that) {
case _ShowCatalogTarget():
return $default(_that.title,_that.episode,_that.page,_that.forceReleaseScope,_that.savedMalId,_that.savedImageUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  String? episode,  String? page,  bool forceReleaseScope,  int? savedMalId,  String? savedImageUrl)?  $default,) {final _that = this;
switch (_that) {
case _ShowCatalogTarget() when $default != null:
return $default(_that.title,_that.episode,_that.page,_that.forceReleaseScope,_that.savedMalId,_that.savedImageUrl);case _:
  return null;

}
}

}

/// @nodoc


class _ShowCatalogTarget extends ShowCatalogTarget {
  const _ShowCatalogTarget({required this.title, this.episode, this.page, this.forceReleaseScope = false, this.savedMalId, this.savedImageUrl}): super._();
  

@override final  String title;
@override final  String? episode;
@override final  String? page;
@override@JsonKey() final  bool forceReleaseScope;
@override final  int? savedMalId;
@override final  String? savedImageUrl;

/// Create a copy of ShowCatalogTarget
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShowCatalogTargetCopyWith<_ShowCatalogTarget> get copyWith => __$ShowCatalogTargetCopyWithImpl<_ShowCatalogTarget>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShowCatalogTarget&&(identical(other.title, title) || other.title == title)&&(identical(other.episode, episode) || other.episode == episode)&&(identical(other.page, page) || other.page == page)&&(identical(other.forceReleaseScope, forceReleaseScope) || other.forceReleaseScope == forceReleaseScope)&&(identical(other.savedMalId, savedMalId) || other.savedMalId == savedMalId)&&(identical(other.savedImageUrl, savedImageUrl) || other.savedImageUrl == savedImageUrl));
}


@override
int get hashCode {
    return Object.hash(runtimeType,title,episode,page,forceReleaseScope,savedMalId,savedImageUrl);
}

@override
String toString() {
    return 'ShowCatalogTarget(title: $title, episode: $episode, page: $page, forceReleaseScope: $forceReleaseScope, savedMalId: $savedMalId, savedImageUrl: $savedImageUrl)';
}


}

/// @nodoc
abstract mixin class _$ShowCatalogTargetCopyWith<$Res> implements $ShowCatalogTargetCopyWith<$Res> {
  factory _$ShowCatalogTargetCopyWith(_ShowCatalogTarget value, $Res Function(_ShowCatalogTarget) _then) = __$ShowCatalogTargetCopyWithImpl;
@override @useResult
$Res call({
 String title, String? episode, String? page, bool forceReleaseScope, int? savedMalId, String? savedImageUrl
});




}
/// @nodoc
class __$ShowCatalogTargetCopyWithImpl<$Res>
    implements _$ShowCatalogTargetCopyWith<$Res> {
  __$ShowCatalogTargetCopyWithImpl(this._self, this._then);

  final _ShowCatalogTarget _self;
  final $Res Function(_ShowCatalogTarget) _then;

/// Create a copy of ShowCatalogTarget
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? episode = freezed,Object? page = freezed,Object? forceReleaseScope = null,Object? savedMalId = freezed,Object? savedImageUrl = freezed,}) {
  return _then(_ShowCatalogTarget(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,episode: freezed == episode ? _self.episode : episode // ignore: cast_nullable_to_non_nullable
as String?,page: freezed == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as String?,forceReleaseScope: null == forceReleaseScope ? _self.forceReleaseScope : forceReleaseScope // ignore: cast_nullable_to_non_nullable
as bool,savedMalId: freezed == savedMalId ? _self.savedMalId : savedMalId // ignore: cast_nullable_to_non_nullable
as int?,savedImageUrl: freezed == savedImageUrl ? _self.savedImageUrl : savedImageUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ShowCatalogMatch {

 TenraiAnimeSearchResult? get entry; List<TenraiAnimeSearchResult> get candidates; bool get userSelected; bool get releaseOnly; String? get evidence;
/// Create a copy of ShowCatalogMatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShowCatalogMatchCopyWith<ShowCatalogMatch> get copyWith => _$ShowCatalogMatchCopyWithImpl<ShowCatalogMatch>(this as ShowCatalogMatch, _$identity);

  /// Serializes this ShowCatalogMatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ShowCatalogMatch;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShowCatalogMatch&&(identical(other.entry, _this.entry) || other.entry == _this.entry)&&const DeepCollectionEquality().equals(other.candidates, _this.candidates)&&(identical(other.userSelected, _this.userSelected) || other.userSelected == _this.userSelected)&&(identical(other.releaseOnly, _this.releaseOnly) || other.releaseOnly == _this.releaseOnly)&&(identical(other.evidence, _this.evidence) || other.evidence == _this.evidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ShowCatalogMatch;
  return Object.hash(runtimeType,_this.entry,const DeepCollectionEquality().hash(_this.candidates),_this.userSelected,_this.releaseOnly,_this.evidence);
}

@override
String toString() {
  final _this = this as ShowCatalogMatch;
  return 'ShowCatalogMatch(entry: ${_this.entry}, candidates: ${_this.candidates}, userSelected: ${_this.userSelected}, releaseOnly: ${_this.releaseOnly}, evidence: ${_this.evidence})';
}


}

/// @nodoc
abstract mixin class $ShowCatalogMatchCopyWith<$Res>  {
  factory $ShowCatalogMatchCopyWith(ShowCatalogMatch value, $Res Function(ShowCatalogMatch) _then) = _$ShowCatalogMatchCopyWithImpl;
@useResult
$Res call({
 TenraiAnimeSearchResult? entry, List<TenraiAnimeSearchResult> candidates, bool userSelected, bool releaseOnly, String? evidence
});


$TenraiAnimeSearchResultCopyWith<$Res>? get entry;

}
/// @nodoc
class _$ShowCatalogMatchCopyWithImpl<$Res>
    implements $ShowCatalogMatchCopyWith<$Res> {
  _$ShowCatalogMatchCopyWithImpl(this._self, this._then);

  final ShowCatalogMatch _self;
  final $Res Function(ShowCatalogMatch) _then;

/// Create a copy of ShowCatalogMatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entry = freezed,Object? candidates = null,Object? userSelected = null,Object? releaseOnly = null,Object? evidence = freezed,}) {
  return _then(ShowCatalogMatch(
entry: freezed == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as TenraiAnimeSearchResult?,candidates: null == candidates ? _self.candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<TenraiAnimeSearchResult>,userSelected: null == userSelected ? _self.userSelected : userSelected // ignore: cast_nullable_to_non_nullable
as bool,releaseOnly: null == releaseOnly ? _self.releaseOnly : releaseOnly // ignore: cast_nullable_to_non_nullable
as bool,evidence: freezed == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ShowCatalogMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TenraiAnimeSearchResultCopyWith<$Res>? get entry {
    if (_self.entry == null) {
    return null;
  }

  return $TenraiAnimeSearchResultCopyWith<$Res>(_self.entry!, (value) {
    return _then(_self.copyWith(entry: value));
  });
}
}


/// Adds pattern-matching-related methods to [ShowCatalogMatch].
extension ShowCatalogMatchPatterns on ShowCatalogMatch {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShowCatalogMatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShowCatalogMatch() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShowCatalogMatch value)  $default,){
final _that = this;
switch (_that) {
case _ShowCatalogMatch():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShowCatalogMatch value)?  $default,){
final _that = this;
switch (_that) {
case _ShowCatalogMatch() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TenraiAnimeSearchResult? entry,  List<TenraiAnimeSearchResult> candidates,  bool userSelected,  bool releaseOnly,  String? evidence)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShowCatalogMatch() when $default != null:
return $default(_that.entry,_that.candidates,_that.userSelected,_that.releaseOnly,_that.evidence);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TenraiAnimeSearchResult? entry,  List<TenraiAnimeSearchResult> candidates,  bool userSelected,  bool releaseOnly,  String? evidence)  $default,) {final _that = this;
switch (_that) {
case _ShowCatalogMatch():
return $default(_that.entry,_that.candidates,_that.userSelected,_that.releaseOnly,_that.evidence);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TenraiAnimeSearchResult? entry,  List<TenraiAnimeSearchResult> candidates,  bool userSelected,  bool releaseOnly,  String? evidence)?  $default,) {final _that = this;
switch (_that) {
case _ShowCatalogMatch() when $default != null:
return $default(_that.entry,_that.candidates,_that.userSelected,_that.releaseOnly,_that.evidence);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ShowCatalogMatch implements ShowCatalogMatch {
  const _ShowCatalogMatch({this.entry,  List<TenraiAnimeSearchResult> candidates = const <TenraiAnimeSearchResult>[], this.userSelected = false, this.releaseOnly = false, this.evidence}): _candidates = candidates;
  factory _ShowCatalogMatch.fromJson(Map<String, dynamic> json) => _$ShowCatalogMatchFromJson(json);

@override final  TenraiAnimeSearchResult? entry;
 final  List<TenraiAnimeSearchResult> _candidates;
@override@JsonKey() List<TenraiAnimeSearchResult> get candidates {
  if (_candidates is EqualUnmodifiableListView) return _candidates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_candidates);
}

@override@JsonKey() final  bool userSelected;
@override@JsonKey() final  bool releaseOnly;
@override final  String? evidence;

/// Create a copy of ShowCatalogMatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShowCatalogMatchCopyWith<_ShowCatalogMatch> get copyWith => __$ShowCatalogMatchCopyWithImpl<_ShowCatalogMatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShowCatalogMatchToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShowCatalogMatch&&(identical(other.entry, entry) || other.entry == entry)&&const DeepCollectionEquality().equals(other.candidates, _candidates)&&(identical(other.userSelected, userSelected) || other.userSelected == userSelected)&&(identical(other.releaseOnly, releaseOnly) || other.releaseOnly == releaseOnly)&&(identical(other.evidence, evidence) || other.evidence == evidence));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,entry,const DeepCollectionEquality().hash(_candidates),userSelected,releaseOnly,evidence);
}

@override
String toString() {
    return 'ShowCatalogMatch(entry: $entry, candidates: $candidates, userSelected: $userSelected, releaseOnly: $releaseOnly, evidence: $evidence)';
}


}

/// @nodoc
abstract mixin class _$ShowCatalogMatchCopyWith<$Res> implements $ShowCatalogMatchCopyWith<$Res> {
  factory _$ShowCatalogMatchCopyWith(_ShowCatalogMatch value, $Res Function(_ShowCatalogMatch) _then) = __$ShowCatalogMatchCopyWithImpl;
@override @useResult
$Res call({
 TenraiAnimeSearchResult? entry, List<TenraiAnimeSearchResult> candidates, bool userSelected, bool releaseOnly, String? evidence
});


@override $TenraiAnimeSearchResultCopyWith<$Res>? get entry;

}
/// @nodoc
class __$ShowCatalogMatchCopyWithImpl<$Res>
    implements _$ShowCatalogMatchCopyWith<$Res> {
  __$ShowCatalogMatchCopyWithImpl(this._self, this._then);

  final _ShowCatalogMatch _self;
  final $Res Function(_ShowCatalogMatch) _then;

/// Create a copy of ShowCatalogMatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entry = freezed,Object? candidates = null,Object? userSelected = null,Object? releaseOnly = null,Object? evidence = freezed,}) {
  return _then(_ShowCatalogMatch(
entry: freezed == entry ? _self.entry : entry // ignore: cast_nullable_to_non_nullable
as TenraiAnimeSearchResult?,candidates: null == candidates ? _self._candidates : candidates // ignore: cast_nullable_to_non_nullable
as List<TenraiAnimeSearchResult>,userSelected: null == userSelected ? _self.userSelected : userSelected // ignore: cast_nullable_to_non_nullable
as bool,releaseOnly: null == releaseOnly ? _self.releaseOnly : releaseOnly // ignore: cast_nullable_to_non_nullable
as bool,evidence: freezed == evidence ? _self.evidence : evidence // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ShowCatalogMatch
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TenraiAnimeSearchResultCopyWith<$Res>? get entry {
    if (_self.entry == null) {
    return null;
  }

  return $TenraiAnimeSearchResultCopyWith<$Res>(_self.entry!, (value) {
    return _then(_self.copyWith(entry: value));
  });
}
}

// dart format on
