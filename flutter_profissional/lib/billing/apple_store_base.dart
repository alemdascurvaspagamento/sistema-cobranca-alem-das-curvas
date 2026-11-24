import 'package:flutter/foundation.dart';

/// Loja da Apple vista pelo app. A versão de verdade só existe no iPhone/iPad
/// (apple_store_io.dart); no navegador e nos testes há uma versão vazia.
abstract class AppleStoreBase extends ChangeNotifier {
  /// A App Store respondeu e há planos para mostrar.
  bool get available;

  /// Compra ou restauração em andamento.
  bool get busy;

  /// Último problema, em palavras simples (ou null).
  String? get error;

  /// Último aviso bom (ex.: "Assinatura ativa").
  String? get notice;

  /// Preço como a App Store mostra (ex.: "R$ 39,90"), ou null se ainda não carregou.
  String? priceOf(String productId);

  Future<void> load();
  Future<void> buy(String productId);
  Future<void> restore();
}
