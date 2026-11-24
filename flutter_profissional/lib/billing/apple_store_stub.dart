import 'apple_store_base.dart';

class _NoAppleStore extends AppleStoreBase {
  @override
  bool get available => false;
  @override
  bool get busy => false;
  @override
  String? get error => 'A compra pela Apple só existe no app do iPhone e do iPad.';
  @override
  String? get notice => null;
  @override
  String? priceOf(String productId) => null;
  @override
  Future<void> load() async {}
  @override
  Future<void> buy(String productId) async {}
  @override
  Future<void> restore() async {}
}

AppleStoreBase createAppleStore() => _NoAppleStore();
