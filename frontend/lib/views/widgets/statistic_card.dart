import 'package:flutter/material.dart';

class StatisticCard extends StatelessWidget {
  final String title;
  final Widget content;
  final IconData? icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? height;
  final bool? expanded;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const StatisticCard({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.iconColor,
    this.backgroundColor,
    this.height,
    this.expanded = true,
    this.margin = const EdgeInsets.only(bottom: 16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final card = Card(
      elevation: isDarkMode ? 4 : 2,
      margin: margin,
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
              color: backgroundColor ??
                  (isDarkMode
                      ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                      : Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3)),
              border: Border(
                bottom: BorderSide(
                  color: isDarkMode
                      ? Theme.of(context).dividerColor
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                          color: isDarkMode ? Colors.white : null,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          expanded == true
              ? Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    width: double.infinity,
                    color: isDarkMode ? Theme.of(context).cardColor : null,
                    child: content,
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(16.0),
                  width: double.infinity,
                  height: height,
                  color: isDarkMode ? Theme.of(context).cardColor : null,
                  child: content,
                ),
        ],
      ),
    );

    // Wrap with InkWell if onTap is provided
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}

// Simple statistic value card for displaying key metrics
class StatisticValueCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const StatisticValueCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = color ?? Theme.of(context).colorScheme.primary;
    final bgColor = backgroundColor ??
        (isDarkMode ? cardColor.withOpacity(0.15) : cardColor.withOpacity(0.1));

    final card = Card(
      elevation: isDarkMode ? 4 : 2,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(isDarkMode ? 0.3 : 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDarkMode ? Colors.white : cardColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : cardColor,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.9)
                        : Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.color
                            ?.withOpacity(0.7),
                  ),
            ),
          ],
        ),
      ),
    );

    // Wrap with InkWell if onTap is provided
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }
}
