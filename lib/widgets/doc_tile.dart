import 'package:flutter/material.dart';

import '../models/text_doc.dart';
import '../utils/date_format.dart';

class DocTile extends StatelessWidget {
  const DocTile({
    super.key,
    required this.doc,
    required this.preview,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final TextDoc doc;
  final String preview;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = doc.isTst
        ? '${doc.config.groups.length} 个隐藏组'
        : '纯文本';
    return ListTile(
      onTap: onTap,
      isThreeLine: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(
          doc.isTst ? Icons.quiz_outlined : Icons.description_outlined,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
      title: Row(
        children: [
          _KindBadge(isTst: doc.isTst),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            preview.isEmpty ? '（空白文稿）' : preview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$meta · ${formatDocDate(doc.updatedAt)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        tooltip: '更多操作',
        onSelected: (value) {
          if (value == 'rename') onRename();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => const [
          PopupMenuItem<String>(
            value: 'rename',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.drive_file_rename_outline),
              title: Text('重命名'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline),
              title: Text('删除'),
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.isTst});

  final bool isTst;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isTst ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isTst ? 'TST' : 'TXT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: isTst ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
