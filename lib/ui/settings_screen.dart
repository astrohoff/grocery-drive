import 'package:flutter/material.dart';

import '../data/cloud_accounts.dart';
import '../data/cloud_store.dart';
import '../data/loopback_oauth.dart';
import '../list_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.accounts,
    required this.onSignedIn,
    this.providerName,
    this.controller,
    this.onClose,
    super.key,
  });

  final CloudAccounts accounts;
  final VoidCallback onSignedIn;
  final String? providerName;
  final ListController? controller;
  final VoidCallback? onClose;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _error;
  var _busy = false;
  var _folders = const <CloudFolder>[];

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final controller = widget.controller;
    if (controller == null) return;
    try {
      final folders = await controller.cloud.listRootFolders();
      if (!mounted) return;
      setState(() => _folders = folders);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

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

  Future<void> _choose(CloudFolder folder) async {
    final controller = widget.controller;
    if (controller == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await controller.selectFolder(folder.id);
      final folders = await controller.cloud.listRootFolders();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _folders = folders;
      });
      if (controller.synced) widget.onClose?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  Future<void> _useGroceries() async {
    final controller = widget.controller;
    if (controller == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final folder = await controller.cloud.createRootFolder('Groceries');
      await controller.selectFolder(folder.id);
      final folders = await controller.cloud.listRootFolders();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _folders = folders;
      });
      if (controller.synced) widget.onClose?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$error';
      });
    }
  }

  Future<void> _sync() async {
    final controller = widget.controller;
    if (controller == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await controller.sync();
    if (!mounted) return;
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final googleReady = CloudAccounts.googleClientId.isNotEmpty;
    final microsoftReady = CloudAccounts.microsoftClientId.isNotEmpty;
    final controller = widget.controller;
    final activeId = controller?.cache.folderId;
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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'account-status',
                child: Text(_accountStatus(widget.providerName)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose a folder in the drive root, or use Groceries. '
                'The app syncs that folder only and creates Groceries when you use that button.',
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
                  onPressed: _busy || !googleReady
                      ? null
                      : () => _signIn('google'),
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
              const SizedBox(height: 24),
              Text('Folder', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (controller == null)
                const Text('Sign in to choose a folder.')
              else ...[
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'create-groceries-folder',
                  button: true,
                  child: FilledButton(
                    onPressed: _busy ? null : _useGroceries,
                    child: const Text('Use Groceries folder'),
                  ),
                ),
                for (final folder in _folders)
                  Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: 'folder:${folder.name}',
                    button: true,
                    child: ListTile(
                      title: Text(folder.name),
                      subtitle: folder.id == activeId
                          ? const Text('Current folder')
                          : null,
                      onTap: _busy ? null : () => _choose(folder),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'settings-sync',
                button: true,
                child: TextButton(
                  onPressed: controller == null || _busy ? null : _sync,
                  child: const Text('Sync now'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!),
              ],
              const SizedBox(height: 24),
              Text('About', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Grocery Drive is released under the MIT License.'),
              const Text('Copyright (c) 2026 astrohoff'),
            ],
          ),
        ),
      ),
    );
  }
}

String _accountStatus(String? provider) {
  if (provider == 'google') return 'Signed in to Google Drive';
  if (provider == 'microsoft') return 'Signed in to OneDrive';
  return 'Not signed in';
}
