import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Encerra a sessão depois de um tempo sem uso.
///
/// Conta como uso: tocar, rolar, mover o mouse e digitar. Se o app ficar em
/// segundo plano (outra aba, celular bloqueado) por mais que o limite, a sessão
/// também é encerrada ao voltar.
class IdleGuard extends StatefulWidget {
  const IdleGuard({
    super.key,
    required this.child,
    required this.onTimeout,
    this.timeout = const Duration(minutes: 30),
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTimeout;
  final Duration timeout;
  final bool enabled;

  @override
  State<IdleGuard> createState() => _IdleGuardState();
}

class _IdleGuardState extends State<IdleGuard> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _last = DateTime.now();
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HardwareKeyboard.instance.addHandler(_onKey);
    _restart();
  }

  @override
  void didUpdateWidget(IdleGuard old) {
    super.didUpdateWidget(old);
    if (old.enabled != widget.enabled || old.timeout != widget.timeout) _restart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _onKey(KeyEvent _) {
    _activity();
    return false;
  }

  void _restart() {
    _timer?.cancel();
    _last = DateTime.now();
    if (widget.enabled) _timer = Timer(widget.timeout, _fire);
  }

  void _activity() {
    // Evita recriar o cronômetro a cada movimento do mouse.
    if (DateTime.now().difference(_last) < const Duration(seconds: 5)) return;
    _restart();
  }

  void _fire() {
    if (_fired || !mounted || !widget.enabled) return;
    _fired = true;
    widget.onTimeout();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(_last) >= widget.timeout) {
        _fire();
      } else {
        _activity();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _activity(),
        onPointerMove: (_) => _activity(),
        onPointerHover: (_) => _activity(),
        onPointerSignal: (_) => _activity(),
        child: widget.child,
      );
}
