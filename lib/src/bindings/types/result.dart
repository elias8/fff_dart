import 'dart:ffi';

import '../../ffi/fff.g.dart';
import 'string.dart';

/// Decodes an envelope and always releases it after [onSuccess] returns.
///
/// The callback must release any separately allocated payload it reads. Each
/// payload has its own native deallocator, so it cannot be released here.
T decodeFffResult<T>(
  Pointer<FffResult> Function() executor, {
  required T Function(FffResult result) onSuccess,
  required String operation,
}) {
  final pointer = executor();
  if (pointer == nullptr) {
    throw StateError('FFF returned a null result for $operation');
  }
  // Ownership starts once executor returns a non-null pointer. Release the
  // envelope even if decoding or the success callback throws.
  try {
    final result = pointer.ref;
    if (!result.success) {
      final error = result.error;
      final message = error == nullptr
          ? 'Unknown native error'
          : error.toDartString();
      throw FffException(operation, message);
    }
    return onSuccess(result);
  } finally {
    fff_free_result(pointer);
  }
}

/// Accepts a successful result whose envelope has no payload to decode.
void ignoreResult(FffResult _) {}

/// A failure returned by the native FFF library.
final class const FffException(final String operation, final String message)
    implements Exception {
  @override
  String toString() => 'FffException($operation): $message';
}
