part of 'sidebar.dart';

extension SidebarEnvironmentsExt on _SidebarState {
  Widget _buildEnvironmentItem(EnvironmentModel env) {
    final isSelected =
        ref.watch(requestProvider).url == 'postlens://environment/${env.id}';

    return HoverContainer(
      builder: (isHovered) => Container(
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: InkWell(
          onTap: () {
            final req = HttpRequestModel(
              id: env.id,
              url: 'postlens://environment/${env.id}',
              method: 'ENV',
              name: env.name,
            );
            if (widget.onRequestTap != null) {
              widget.onRequestTap!(req);
            } else {
              ref.read(requestProvider.notifier).loadRequest(req);
            }
          },
          borderRadius: BorderRadius.circular(6),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.only(left: 8, right: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: (isSelected || isHovered)
                  ? Colors.grey.withValues(alpha: 0.15)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.server,
                  size: 12,
                  color: Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    env.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Visibility(
                  visible: isHovered,
                  child: _buildEnvironmentActions(env),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnvironmentActions(EnvironmentModel env) {
    return Builder(
      builder: (popupContext) => PopupMenuButton<String>(
        tooltip: 'More actions',
        offset: const Offset(0, 24),
        constraints: const BoxConstraints(),
        padding: EdgeInsets.zero,
        splashRadius: 16,
        onOpened: () {
          final state =
              popupContext.findAncestorStateOfType<HoverContainerState>();
          state?.setPopupOpen(true);
        },
        onCanceled: () {
          final state =
              popupContext.findAncestorStateOfType<HoverContainerState>();
          state?.setPopupOpen(false);
        },
        onSelected: (value) async {
          final state =
              popupContext.findAncestorStateOfType<HoverContainerState>();
          state?.setPopupOpen(false);

          if (value == 'duplicate') {
            final duplicated = env.copyWith(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: '${env.name} Copy',
            );
            await ref
                .read(environmentsProvider.notifier)
                .addEnvironment(duplicated);
          } else if (value == 'delete') {
            await ref
                .read(environmentsProvider.notifier)
                .deleteEnvironment(env.id);
          } else if (value == 'rename') {
            _showRenameEnvironmentDialog(context, env);
          }
        },
        itemBuilder: (context) {
          final t = ref.watch(translationsProvider);
          return [
            PopupMenuItem(
              value: 'duplicate',
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t['duplicate'] ?? 'Duplicate',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t['delete'] ?? 'Delete',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
            PopupMenuItem(
              value: 'rename',
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                t['rename'] ?? 'Rename',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ];
        },
        child: const Padding(
          padding: EdgeInsets.all(4.0),
          child: FaIcon(
            FontAwesomeIcons.ellipsis,
            size: 13,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  void _showRenameEnvironmentDialog(
      BuildContext context, EnvironmentModel environment) {
    final t = ref.watch(translationsProvider);
    final controller = TextEditingController(text: environment.name);

    AppOverlayDialogs.showModalLike(
      context: context,
      barrierLabel: 'Rename Environment',
      builder: (context) => Dialog(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${t['rename'] ?? 'Rename'} ${t['environment'] ?? 'Environment'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const FaIcon(
                        FontAwesomeIcons.xmark,
                        size: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['name'] ?? 'Name',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        t['cancel'] ?? 'Cancel',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final name = controller.text.trim();
                        if (name.isEmpty) return;

                        await ref
                            .read(environmentsProvider.notifier)
                            .updateEnvironment(
                              environment.copyWith(name: name),
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                      ),
                      child: Text(
                        t['save'] ?? 'Save',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
