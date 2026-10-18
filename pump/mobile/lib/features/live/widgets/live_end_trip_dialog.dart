import 'package:flutter/material.dart';
import '../../../theme/marg_tokens.dart';

class LiveEndTripDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const LiveEndTripDialog({super.key, required this.onConfirm});

  static Future<bool?> show(BuildContext context, {required VoidCallback onConfirm}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => LiveEndTripDialog(onConfirm: onConfirm),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.lg)),
      title: Text('End Trip?', style: MargText.headline.copyWith(color: c.label)),
      content: Text(
        'Are you sure you want to exit live trip guidance?',
        style: MargText.body.copyWith(color: c.label2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel', style: MargText.body.copyWith(color: c.label2)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, true);
            onConfirm();
          },
          child: Text('End Trip', style: MargText.body.copyWith(color: c.red, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
