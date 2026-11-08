import 'package:flutter/material.dart';

/// 只負責輸入姓名，控制器生命週期由這個 Dialog 自己管理。
class NameEditorDialog extends StatefulWidget {
  const NameEditorDialog({
    required this.initialName,
    required this.initialKeywords,
    super.key,
  });

  final String initialName;
  final List<String> initialKeywords;

  @override
  State<NameEditorDialog> createState() => _NameEditorDialogState();
}

class _NameEditorDialogState extends State<NameEditorDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _keywordsController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _keywordsController = TextEditingController(
      text: widget.initialKeywords.join(', '),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _keywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.initialName.isEmpty ? '設定姓名' : '修改姓名'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: '姓名／區域名稱',
                hintText: '例如：王小明',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _keywordsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '搜尋關鍵字',
                hintText: '以逗號或中文逗號分隔，例如：資訊組，A-01, 小明',
                helperText: '支援 , 和 ，；符合任一關鍵字即可搜尋',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(<String, Object>{
              'name': _controller.text.trim(),
              'keywords': _keywordsController.text
                  .split(RegExp(r'[,，;；\n]+'))
                  .map((keyword) => keyword.trim())
                  .where((keyword) => keyword.isNotEmpty)
                  .toSet()
                  .toList(),
            });
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}
