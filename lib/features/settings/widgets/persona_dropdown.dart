import 'package:flutter/material.dart';

import '../../../l10n/localization_manager.dart';
import '../../../models/chat.dart';

/// Dropdown widget for selecting chat persona
class PersonaDropdown extends StatelessWidget {
  final ChatPersona currentValue;
  final ValueChanged<ChatPersona> onChanged;

  const PersonaDropdown({
    super.key,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            localized.personaAssistant,
            style: const TextStyle(fontSize: 20),
          ),
          DropdownButton<String>(
            value: currentValue.name,
            items: ChatPersona.values
                .map<String>((ChatPersona value) => value.name)
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(value.toUpperCase()),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                onChanged(ChatPersona.values.byName(newValue));
              }
            },
          ),
        ],
      ),
    );
  }
}
