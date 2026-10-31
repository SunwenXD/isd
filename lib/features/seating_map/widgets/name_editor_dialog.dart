import 'package:flutter/material.dart';

/// 只負責輸入姓名，控制器生命週期由這個 Dialog 自己管理。
class NameEditorDialog extends StatefulWidget {
  const NameEditorDialog({
    required this.initialName,
    super.key,
  });

  final String initialName;

  @override
  State<NameEditorDialog> createState() => _NameEditorDialogState();
}

class _NameEditorDialogState extends State<NameEditorDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName.isEmpty ? '設定姓名' : '修改姓名'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        decoration: const InputDecoration(
          labelText: '姓名',
          hintText: '請輸入姓名',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          Navigator.of(context).pop(value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: const Text('確認'),
        ),
      ],
    );
  }
}
