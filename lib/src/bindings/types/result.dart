import 'dart:ffi';

import '../../ffi/fff.g.dart';
import 'string.dart';

/// Decodes an envelope returned by [invoke] and releases it after decoding.
///
/// Any separately allocated payload must be copied and released by the
/// operation-specific binding. [fff_free_result] only releases the envelope.
T decodeFffResult<T>(
  Pointer<FffResult> Function() invoke, {
  required T Function(FffResult envelope) decodeSuccess,
  required String operationName,
}) {
  final pointer = invoke();
  if (pointer == nullptr) {
    throw StateError('FFF returned a null result for $operationName');
  }
  // Ownership starts once invoke returns a non-null pointer. Release the
  // envelope even if success decoding throws.
  try {
    final envelope = pointer.ref;
    if (!envelope.success) {
      final error = envelope.error;
      final message = error == nullptr
          ? 'Unknown native error'
          : error.toDartString();
      throw FffException(operationName, message);
    }
    return decodeSuccess(envelope);
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
