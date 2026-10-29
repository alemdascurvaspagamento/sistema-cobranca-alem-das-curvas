import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cf_theme.dart';
import 'legal.dart';

/// Entrar com e-mail e senha, e recuperar a senha por e-mail.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onBack, this.notice, this.startSignup = false});

  /// Abre direto no cadastro (criar conta grátis).
  final bool startSignup;
  final VoidCallback onBack;

  /// Aviso no topo (ex.: saída automática por inatividade).
  final String? notice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool forgot = false;
  late bool signup = widget.startSignup;
  final password2 = TextEditingController();
  bool hide = true;
  bool accepted = false;
  String? error;
  String? info;

  GoTrueClient get auth => Supabase.instance.client.auth;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    password2.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());

  Future<void> _signIn() async {
    if (!_emailOk || password.text.isEmpty) {
      setState(() => error = 'Digite seu e-mail e sua senha.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await auth.signInWithPassword(email: email.text.trim(), password: password.text);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() => error = msg.contains('invalid') || msg.contains('credentials')
          ? 'E-mail ou senha incorretos.'
          : msg.contains('confirm')
              ? 'Confirme seu e-mail antes de entrar (veja a caixa de entrada).'
              : 'Não foi possível entrar agora. Tente de novo em instantes.');
    } catch (_) {
      setState(() => error = 'Sem conexão. Confira a internet e tente de novo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _signUp() async {
    if (!_emailOk) {
      setState(() => error = 'Digite um e-mail válido.');
      return;
    }
    if (password.text.length < 8) {
      setState(() => error = 'A senha precisa ter pelo menos 8 caracteres.');
      return;
    }
    if (password.text != password2.text) {
      setState(() => error = 'As duas senhas precisam ser iguais.');
      return;
    }
    if (!accepted) {
      setState(() => error = 'Para criar a conta, marque que leu os termos de uso e a política de privacidade.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      final res = await auth.signUp(
        email: email.text.trim(),
        password: password.text,
        emailRedirectTo: kIsWeb ? Uri.base.origin : null,
        data: {'terms_version': legalVersion, 'terms_accepted_at': DateTime.now().toUtc().toIso8601String()},
      );
      if (res.session == null && mounted) {
        setState(() => info = 'Quase lá! Enviamos um e-mail para ${email.text.trim()}. '
            'Abra o link para confirmar e depois entre aqui com sua senha.');
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      setState(() => error = msg.contains('already') || msg.contains('registered')
          ? 'Este e-mail já tem conta. Entre ou use "Esqueci minha senha".'
          : msg.contains('not allowed') || msg.contains('disabled')
              ? 'O cadastro de novas contas ainda não está aberto.'
              : msg.contains('password')
                  ? 'Escolha uma senha mais forte (letras e números, 8 ou mais caracteres).'
                  : 'Não foi possível criar a conta agora. Tente de novo em instantes.');
    } catch (_) {
      setState(() => error = 'Sem conexão. Confira a internet e tente de novo.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _sendReset() async {
    if (!_emailOk) {
      setState(() => error = 'Digite o e-mail da sua conta.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await auth.resetPasswordForEmail(email.text.trim(), redirectTo: Uri.base.origin);
      setState(() => info = 'Enviamos um link para ${email.text.trim()}. Abra o e-mail e crie uma nova senha.');
    } catch (_) {
      setState(() => error = 'Não foi possível enviar o e-mail agora. Tente de novo em instantes.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CF.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Voltar',
                      color: Colors.white,
                      onPressed: forgot ? () => setState(() => forgot = false) : widget.onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(forgot ? 'Recuperar senha' : (signup ? 'Criar conta grátis' : 'Entrar no Coach Flow'),
                      style: CF.score(40, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(
                    forgot
                        ? 'Digite o e-mail da sua conta. Você recebe um link para criar uma senha nova.'
                        : signup
                            ? '14 dias com tudo liberado, sem cartão. Depois você escolhe um plano, '
                                'a partir de R\$ 29,90 por mês.'
                            : 'Use o e-mail e a senha da sua conta.',
                    style: CF.body(16, color: Colors.white70, height: 1.4),
                  ),
                  if (widget.notice != null && !forgot) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: CF.lap, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.lock_clock_rounded, color: CF.ink),
                        const SizedBox(width: 10),
                        Expanded(child: Text(widget.notice!, style: CF.body(15, color: CF.ink, weight: FontWeight.w600))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: CF.surface, borderRadius: BorderRadius.circular(22)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: forgot ? TextInputAction.done : TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'E-mail'),
                        onChanged: (_) => setState(() => error = null),
                      ),
                      if (!forgot) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: password,
                          obscureText: hide,
                          autofillHints: signup ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!signup) _signIn();
                          },
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            suffixIcon: IconButton(
                              tooltip: hide ? 'Mostrar senha' : 'Esconder senha',
                              onPressed: () => setState(() => hide = !hide),
                              icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                            ),
                          ),
                          onChanged: (_) => setState(() => error = null),
                        ),
                        if (signup) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: password2,
                            obscureText: hide,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _signUp(),
                            decoration: const InputDecoration(labelText: 'Repita a senha'),
                            onChanged: (_) => setState(() => error = null),
                          ),
                          const SizedBox(height: 8),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Checkbox(
                              value: accepted,
                              onChanged: (v) => setState(() {
                                accepted = v ?? false;
                                error = null;
                              }),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                                  Text('Li e aceito os ', style: CF.body(14, color: CF.muted)),
                                  InkWell(
                                    onTap: () => openLegal(context, LegalDoc.terms),
                                    child: Text('Termos de uso', style: CF.body(14, color: CF.blue, weight: FontWeight.w700)),
                                  ),
                                  Text(' e a ', style: CF.body(14, color: CF.muted)),
                                  InkWell(
                                    onTap: () => openLegal(context, LegalDoc.privacy),
                                    child: Text('Política de privacidade', style: CF.body(14, color: CF.blue, weight: FontWeight.w700)),
                                  ),
                                  Text('.', style: CF.body(14, color: CF.muted)),
                                ]),
                              ),
                            ),
                          ]),
                        ],
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
                      ],
                      if (info != null) ...[
                        const SizedBox(height: 12),
                        Text(info!, style: CF.body(15, color: CF.green, weight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : (forgot ? _sendReset : (signup ? _signUp : _signIn)),
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                        child: Text(busy
                            ? 'Aguarde...'
                            : (forgot ? 'Enviar link' : (signup ? 'Criar minha conta' : 'Entrar'))),
                      ),
                      if (!forgot)
                        TextButton(
                          onPressed: () => setState(() {
                            signup = !signup;
                            error = null;
                            info = null;
                          }),
                          child: Text(signup ? 'Já tenho conta: entrar' : 'Ainda não tenho conta: criar grátis'),
                        ),
                      if (!forgot && !signup)
                        TextButton(
                          onPressed: () => setState(() {
                            forgot = true;
                            error = null;
                            info = null;
                          }),
                          child: const Text('Esqueci minha senha'),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Criar uma senha nova depois de abrir o link de recuperação.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final p1 = TextEditingController();
  final p2 = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    p1.dispose();
    p2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (p1.text.length < 8) {
      setState(() => error = 'Use pelo menos 8 caracteres.');
      return;
    }
    if (p1.text != p2.text) {
      setState(() => error = 'As duas senhas precisam ser iguais.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: p1.text));
      widget.onDone();
    } catch (_) {
      setState(() => error = 'Não foi possível salvar a senha. O link pode ter expirado; peça outro.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: CF.ink,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Crie sua nova senha', style: CF.score(40, color: Colors.white)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: CF.surface, borderRadius: BorderRadius.circular(22)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(controller: p1, obscureText: true, decoration: const InputDecoration(labelText: 'Nova senha')),
                      const SizedBox(height: 12),
                      TextField(controller: p2, obscureText: true, decoration: const InputDecoration(labelText: 'Repita a nova senha')),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: CF.body(15, color: CF.red, weight: FontWeight.w600)),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : _save,
                        child: Text(busy ? 'Salvando...' : 'Salvar senha e entrar'),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
