import 'package:flutter/material.dart';

class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // This is the content that will be shown in the dialog
    return _buildLegendContent(context, theme, isDarkMode);
  }

  // Extracted content to be reusable in a dialog
  Widget _buildLegendContent(
      BuildContext context, ThemeData theme, bool isDarkMode) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tier labels with colors
        Padding(
          padding: const EdgeInsets.only(
              top: 8.0, bottom: 16.0), // Added bottom padding
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTierLabel('S', Colors.red.shade400, isDarkMode, theme),
              _buildTierLabel('A', Colors.orange.shade300, isDarkMode, theme),
              _buildTierLabel('B', Colors.amber.shade300, isDarkMode, theme),
              _buildTierLabel('C', Colors.green.shade300, isDarkMode, theme),
              _buildTierLabel('D', Colors.blue.shade200, isDarkMode, theme),
            ],
          ),
        ),

        // Description
        Padding(
          padding: const EdgeInsets.only(top: 0.0), // Adjusted padding
          child: Text(
            'Las categorías se clasifican según su nivel de afluencia de personas. S es el nivel más alto, D el más bajo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              // fontStyle: FontStyle.italic, // Optionally remove italic
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // This is the original Card structure, which might be used if the legend is displayed directly
  Widget buildCardVersion(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ranking de Actividad',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildLegendContent(context, theme, isDarkMode),
          ],
        ),
      ),
    );
  }

  Widget _buildTierLabel(
      String tier, Color color, bool isDarkMode, ThemeData theme) {
    // Added theme
    final textColor =
        color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              tier,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tier == 'S'
              ? 'Alto'
              : tier == 'A'
                  ? 'Bueno'
                  : tier == 'B'
                      ? 'Medio'
                      : tier == 'C'
                          ? 'Bajo'
                          : 'Mínimo',
          style: theme.textTheme.bodySmall?.copyWith(
            // Using theme for consistency
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
