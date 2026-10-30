import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lembra, na conta da pessoa, se o cartão "Comece por aqui" já foi fechado
/// e se ela já abriu as cobranças. Assim vale no celular e no computador.
class StartGuide extends ChangeNotifier {
  StartGuide._();
  static final instance = StartGuide._();

  static const _closedKey = 'cf_start_guide_closed';
  static const _billingKey = 'cf_start_guide_billing';

  bool? _closed, _seenBilling;

  Map<String, dynamic> get _meta {
    try {
      return Supabase.instance.client.auth.currentUser?.userMetadata ?? const {};
    } catch (_) {
      return const {}; // demonstração ou testes, sem nuvem
    }
  }

  bool get closed => _closed ?? _meta[_closedKey] == true;
  bool get seenBilling => _seenBilling ?? _meta[_billingKey] == true;

  Future<void> close() => _save(closed: true);
  Future<void> markBillingSeen() => seenBilling ? Future.value() : _save(seenBilling: true);

  /// Volta a mostrar o guia (Configurações).
  Future<void> showAgain() => _save(closed: false, seenBilling: false);

  Future<void> _save({bool? closed, bool? seenBilling}) async {
    if (closed != null) _closed = closed;
    if (seenBilling != null) _seenBilling = seenBilling;
    notifyListeners();
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(data: {
        if (closed != null) _closedKey: closed,
        if (seenBilling != null) _billingKey: seenBilling,
      }));
    } catch (_) {
      // Sem conexão ou na demonstração: fica lembrado enquanto o app estiver aberto.
    }
  }
}
