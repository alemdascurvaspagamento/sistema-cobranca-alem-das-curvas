import '../billing/billing_engine.dart';
import '../billing/billing_store.dart';

/// Para onde vão as mudanças feitas no app quando há uma conta conectada.
///
/// A [BillingStore] chama estes métodos depois de cada alteração. Na
/// demonstração não há canal (nada é gravado). Com login, a implementação
/// em `cloud.dart` grava no Supabase.
abstract class CloudSink {
  void saveClient(StudentPlan p);

  /// Atendimentos de um cliente que mudaram: [upserts] gravar, [deletes] apagar (datas aaaa-mm-dd).
  void syncSessions(String clientId, Map<String, LessonRecord> upserts, List<String> deletes);

  void addPayment(String clientId, DateTime month, PaymentEntry entry);
  void deletePayment(String id);

  void saveHoliday(Holiday h);
  void deleteHoliday(String id);

  void saveExpense(Expense e);
  void deleteExpense(String id);
  void payExpense(String expenseId, DateTime month, DateTime paidOn);
  void unpayExpense(String expenseId, DateTime month);

  void addIncome(ExtraIncome e);
  void deleteIncome(String id);

  /// Atualiza só os campos informados do perfil (regras, meta, Pix, profissão...).
  void saveProfile(Map<String, Object?> fields);
}
