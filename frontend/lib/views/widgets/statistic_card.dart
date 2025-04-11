import 'package:flutter/material.dart';

class StatisticCard extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData? icon;
  final Color? iconColor;

  const StatisticCard({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                if (icon != null)
                  Icon(
                    icon,
                    color: iconColor ?? Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                if (icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              width: double.infinity,
              child: SafeArea(
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
