import 'package:flutter/material.dart';

class StatisticsSelector extends StatelessWidget {
  final String value;
  final List<Map<String, String>> options;
  final Function(String?) onChanged;

  const StatisticsSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: 'Seleccionar Estadística',
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
        filled: true,
        fillColor:
            Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
      ),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      dropdownColor: Theme.of(context).colorScheme.surface,
      icon: Icon(Icons.arrow_drop_down,
          color: Theme.of(context).colorScheme.primary),
      items: options.map((option) {
        return DropdownMenuItem(
          value: option['value'],
          child: Text(option['label']!),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
