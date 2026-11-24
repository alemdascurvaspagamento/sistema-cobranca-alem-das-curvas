import 'apple_store_base.dart';
import 'apple_store_stub.dart' if (dart.library.io) 'apple_store_io.dart' as impl;

export 'apple_store_base.dart';

/// A loja da Apple do app (só funciona de verdade no iPhone/iPad com a compra ligada).
final AppleStoreBase appleStore = impl.createAppleStore();
