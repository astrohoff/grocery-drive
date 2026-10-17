import 'package:flutter/material.dart';

import '../data/cloud_accounts.dart';
import '../data/loopback_oauth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.accounts,
    required this.onSignedIn,
    this.onClose,
    super.key,
  });

  final CloudAccounts accounts;
  final VoidCallback onSignedIn;
  final VoidCallback? onClose;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _error;
  var _busy = false;

  Future<void> _signIn(String provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.accounts.signIn(provider);
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onSignedIn();
    } on SignInCancelled {
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final googleReady = CloudAccounts.googleClientId.isNotEmpty;
    final microsoftReady = CloudAccounts.microsoftClientId.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: widget.onClose != null,
        leading: widget.onClose == null
            ? null
            : IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Sign in to Google Drive or OneDrive. The app keeps one folder '
            'named Groceries and creates it if it is missing.',
          ),
          if (!googleReady || !microsoftReady) ...[
            const SizedBox(height: 16),
            const Text(
              'A missing button needs a client id compiled in with '
              '--dart-define. See docs/oauth_setup.md.',
            ),
          ],
          const SizedBox(height: 16),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'sign-in-google',
            button: true,
            child: FilledButton(
              onPressed: _busy || !googleReady ? null : () => _signIn('google'),
              child: const Text('Sign in with Google'),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'sign-in-microsoft',
            button: true,
            child: FilledButton(
              onPressed: _busy || !microsoftReady
                  ? null
                  : () => _signIn('microsoft'),
              child: const Text('Sign in with Microsoft'),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'sign-out',
            button: true,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      await widget.accounts.signOut();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      widget.onSignedIn();
                    },
              child: const Text('Sign out'),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 16), Text(_error!)],
        ],
      ),
    );
  }
}
