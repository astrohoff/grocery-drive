import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/aisle.dart';
import '../domain/item.dart';
import '../domain/quantity.dart';
import '../list_controller.dart';

class ListScreen extends StatelessWidget {
  const ListScreen({required this.controller, this.onSettings, super.key});

  final ListController controller;
  final VoidCallback? onSettings;

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
              if (onSettings != null)
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  label: 'open-settings',
                  button: true,
                  child: IconButton(
                    onPressed: onSettings,
                    icon: const Icon(Icons.settings),
                  ),
                ),
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
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  if (!controller.synced)
                    Semantics(
                      container: true,
                      explicitChildNodes: true,
                      label: 'sync-banner',
                      child: const ListTile(title: Text('Not synced')),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    child: _AddField(controller: controller),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        for (final group in groups) ...[
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: _AisleHeaderDelegate(group.aisle.name),
                          ),
                          SliverList(
                            delegate: SliverChildListDelegate([
                              for (final item in group.items)
                                _ItemRow(
                                  item: item,
                                  onToggle: () => controller.toggle(item.name),
                                  onEdit: () => _edit(context, item.name),
                                  onDelete: () =>
                                      controller.deleteItem(item.name),
                                ),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, String name) async {
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _ItemDialog(line: name),
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
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    widget.controller.addItem(composeItemLine(_name.text, _quantity.text));
    _name.clear();
    _quantity.clear();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _name.clear();
          _quantity.clear();
        },
      },
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'add-item-field',
              textField: true,
              child: TextField(
                controller: _name,
                focusNode: _focus,
                autofocus: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Add an item'),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          SizedBox(
            width: 112,
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'add-quantity-field',
              textField: true,
              child: TextField(
                controller: _quantity,
                autofocus: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(hintText: 'Qty'),
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'submit-add',
            button: true,
            child: IconButton(onPressed: _submit, icon: const Icon(Icons.add)),
          ),
        ],
      ),
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
    final muted = Theme.of(context).colorScheme.onSurface
        .withValues(alpha: 0.5);
    final name = itemName(item.name);
    final quantity = quantityLabel(item.name);
    final style = TextStyle(
      decoration: item.checked
          ? TextDecoration.lineThrough
          : TextDecoration.none,
      color: item.checked ? muted : null,
    );
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
            child: SizedBox(
              height: 56,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(name, style: style),
              ),
            ),
          ),
        ),
        if (quantity.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(quantity, style: style),
          ),
        _ItemMenu(name: item.name, onEdit: onEdit, onDelete: onDelete),
      ],
    );
  }
}

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({
    required this.name,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'item-menu:$name',
      button: true,
      child: IconButton(
        onPressed: () => _open(context),
        icon: const Icon(Icons.more_vert),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (box is! RenderBox || overlay is! RenderBox || !box.hasSize) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        origin & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: 'edit',
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'edit:$name',
            button: true,
            child: const Text('Edit'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'delete:$name',
            button: true,
            child: const Text('Delete'),
          ),
        ),
      ],
    );
    if (!context.mounted || selected == null) return;
    // showMenu pops its route before this runs. The next frame can open a dialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      if (selected == 'edit') onEdit();
      if (selected == 'delete') onDelete();
    });
  }
}

class _AisleHeaderDelegate extends SliverPersistentHeaderDelegate {
  _AisleHeaderDelegate(this.name);

  final String name;

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'aisle:$name',
        header: true,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(name, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _AisleHeaderDelegate oldDelegate) {
    return oldDelegate.name != name;
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.line});

  final String line;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final TextEditingController _name = TextEditingController(
    text: itemName(widget.line),
  );
  late final TextEditingController _quantity = TextEditingController(
    text: quantityLabel(widget.line),
  );

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _submit() =>
      Navigator.pop(context, composeItemLine(_name.text, _quantity.text));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit item'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'edit-item-field',
            textField: true,
            child: TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Item'),
              onSubmitted: (_) => _submit(),
            ),
          ),
          Semantics(
            container: true,
            explicitChildNodes: true,
            label: 'edit-quantity-field',
            textField: true,
            child: TextField(
              controller: _quantity,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Qty'),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Save')),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
