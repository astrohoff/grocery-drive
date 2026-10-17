import 'package:flutter/material.dart';

import '../domain/aisle.dart';
import '../domain/item.dart';
import '../list_controller.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({required this.controller, super.key});

  final ListController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final groups = _groups(controller);
        return Scaffold(
          appBar: AppBar(
            title: Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'list-switcher',
              button: true,
              child: InkWell(
                onTap: () => _openSwitcher(context),
                child: Text(controller.title),
              ),
            ),
            actions: [
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'clear-completed',
                button: true,
                child: TextButton(
                  onPressed: controller.items.any((item) => item.checked)
                      ? controller.clearCompleted
                      : null,
                  child: const Text('Clear'),
                ),
              ),
              Semantics(
                container: true,
                explicitChildNodes: true,
                label: 'sync-now',
                button: true,
                child: IconButton(
                  onPressed: controller.sync,
                  icon: const Icon(Icons.sync),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (!controller.synced)
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'sync-banner',
                  child: ListTile(title: Text('Not synced')),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: _AddField(controller: controller),
              ),
              Expanded(
                child: ListView(
                  children: [
                    for (final group in groups) ...[
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        label: 'aisle:${group.aisle.name}',
                        header: true,
                        child: ListTile(title: Text(group.aisle.name)),
                      ),
                      for (final item in group.items)
                        _ItemRow(
                          item: item,
                          onToggle: () => controller.toggle(item.name),
                          onEdit: () => _edit(context, item.name),
                          onDelete: () => controller.deleteItem(item.name),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, String name) async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(
        title: 'Edit item',
        initial: name,
        fieldLabel: 'edit-item-field',
      ),
    );
    if (next != null) controller.renameItem(name, next);
  }

  Future<void> _openSwitcher(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SwitcherSheet(controller: controller),
    );
  }
}

class _SwitcherSheet extends StatefulWidget {
  const _SwitcherSheet({required this.controller});

  final ListController controller;

  @override
  State<_SwitcherSheet> createState() => _SwitcherSheetState();
}

class _SwitcherSheetState extends State<_SwitcherSheet> {
  final _createController = TextEditingController();

  @override
  void dispose() {
    _createController.dispose();
    super.dispose();
  }

  Future<void> _create(String raw) async {
    await widget.controller.createList(raw);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'create-list-field',
                  textField: true,
                  child: TextField(
                    controller: _createController,
                    decoration: const InputDecoration(hintText: 'New list'),
                    textInputAction: TextInputAction.done,
                    onSubmitted: _create,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    label: 'create-list',
                    button: true,
                    child: TextButton(
                      onPressed: () => _create(_createController.text),
                      child: const Text('Create'),
                    ),
                  ),
                ),
                for (final list in controller.lists)
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          label: 'open-list:${list.name}',
                          button: true,
                          child: TextButton(
                            onPressed: () {
                              controller.openList(list.id);
                              Navigator.pop(context);
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(list.name),
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        label: 'rename-list:${list.name}',
                        button: true,
                        child: IconButton(
                          onPressed: () async {
                            final next = await showDialog<String>(
                              context: context,
                              builder: (context) => _NameDialog(
                                title: 'Rename list',
                                initial: list.name,
                                fieldLabel: 'rename-list-field',
                              ),
                            );
                            if (next != null) {
                              await controller.renameList(list.id, next);
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.edit),
                        ),
                      ),
                      Semantics(
                        container: true,
                        explicitChildNodes: true,
                        label: 'delete-list:${list.name}',
                        button: true,
                        child: IconButton(
                          onPressed: () => controller.deleteList(list.id),
                          icon: const Icon(Icons.delete),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddField extends StatefulWidget {
  const _AddField({required this.controller});

  final ListController controller;

  @override
  State<_AddField> createState() => _AddFieldState();
}

class _AddFieldState extends State<_AddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.controller.addItem(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'add-item-field',
            textField: true,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Add an item'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'submit-add',
          button: true,
          child: IconButton(
            onPressed: _submit,
            icon: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Item item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Row(
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'check:${item.name}',
          button: true,
          child: ExcludeSemantics(
            child: Checkbox(value: item.checked, onChanged: (_) => onToggle()),
          ),
        ),
        Expanded(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'item:${item.name}',
            child: Text(
              item.name,
              style: TextStyle(
                decoration: item.checked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: item.checked ? muted : null,
              ),
            ),
          ),
        ),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'edit:${item.name}',
          button: true,
          child: IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
          ),
        ),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'delete:${item.name}',
          button: true,
          child: IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
          ),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.initial,
    required this.fieldLabel,
  });

  final String title;
  final String initial;
  final String fieldLabel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.fieldLabel,
        textField: true,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _AisleGroup {
  const _AisleGroup(this.aisle, this.items);

  final Aisle aisle;
  final List<Item> items;
}

List<_AisleGroup> _groups(ListController controller) {
  final buckets = <String, List<Item>>{};
  for (final item in controller.items) {
    final id = controller.categorizer.idFor(item.name);
    buckets.putIfAbsent(id, () => []).add(item);
  }
  return [
    for (final aisle in controller.categorizer.aisles)
      if (buckets[aisle.id]?.isNotEmpty ?? false)
        _AisleGroup(aisle, buckets[aisle.id]!),
  ];
}

