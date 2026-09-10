import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'auth_user.dart';

const _lime = Color(0xffd9ff6a);
const _ink = Color(0xff062d29);

Future<void> showAccountSheet({
  required BuildContext context,
  required AuthService auth,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _ink,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => AccountSheet(auth: auth),
  );
}

class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key, required this.auth});
  final AuthService auth;

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  bool _busy = false;
  bool _apple = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.auth.appleAvailable.then((available) {
      if (mounted) {
        setState(() => _apple = available);
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        setState(() => _busy = false);
      }
    } on AuthCanceled {
      if (mounted) {
        setState(() => _busy = false);
      }
    } on AuthFailure catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Sign-in failed. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.user;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('ACCOUNT',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _lime,
                    fontSize: 10,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Text(
              user == null ? 'PLAY AS GUEST' : user.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1.05),
            ),
            const SizedBox(height: 8),
            Text(
              user == null
                  ? 'Sign in to keep this run attached to you.\nBest score still saves on this phone.'
                  : [
                      if (user.email != null && user.email!.isNotEmpty)
                        user.email!,
                      'Signed in with ${user.providerLabel}',
                    ].join('\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70, height: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 22),
            if (user == null) ...[
              _AuthButton(
                label: 'CONTINUE WITH GOOGLE',
                icon: Icons.g_mobiledata,
                enabled: !_busy,
                onPressed: () => _run(widget.auth.signInWithGoogle),
              ),
              if (_apple) ...[
                const SizedBox(height: 10),
                _AuthButton(
                  label: 'CONTINUE WITH APPLE',
                  icon: Icons.apple,
                  enabled: !_busy,
                  onPressed: () => _run(widget.auth.signInWithApple),
                ),
              ],
            ] else
              _AuthButton(
                label: 'SIGN OUT',
                icon: Icons.logout,
                enabled: !_busy,
                filled: false,
                onPressed: () => _run(widget.auth.signOut),
              ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xffff777a), fontSize: 12, height: 1.4)),
            ],
            const SizedBox(height: 16),
            const Text('Guest play stays available. No email is required.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white54)),
          ],
        ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.enabled,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ],
      ),
    );
    if (filled) {
      return SizedBox(
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _lime,
            foregroundColor: _ink,
            disabledBackgroundColor: _lime.withValues(alpha: .4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: enabled ? onPressed : null,
          child: child,
        ),
      );
    }
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          side: const BorderSide(color: Colors.white24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: enabled ? onPressed : null,
        child: child,
      ),
    );
  }
}
