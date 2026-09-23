/// Internal library for FFF's idiomatic Dart API.
///
/// Feature parts share private native handles without exposing them publicly.
library;

import 'dart:ffi' show Finalizable;
import 'dart:io' show FileSystemEntity;

import '../bindings/file_finder.dart' as bindings;
import '../bindings/search.dart' as search_bindings;
import '../bindings/search_directories.dart' as directory_search_bindings;
import '../bindings/types/result.dart' show FffException;
import '../bindings/types/search.dart'
    show
        DirectorySearchOptions,
        DirectorySearchResult,
        SearchOptions,
        SearchResult;

export '../bindings/types/result.dart' show FffException;
export '../bindings/types/search.dart'
    show
        DirectoryItem,
        DirectorySearchOptions,
        DirectorySearchResult,
        FileItem,
        SearchOptions,
        SearchResult,
        SearchScore;
export '../bindings/types/search_location.dart'
    show
        SearchLineLocation,
        SearchLocation,
        SearchPositionLocation,
        SearchRangeLocation;

part 'file_finder.dart';
