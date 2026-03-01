import 'package:flutter/material.dart';
import '../../../models/chat.dart';
import '../../l10n/localization_manager.dart';

class PersonaDropdown extends StatelessWidget {
  final ChatPersona value;
  final ValueChanged<ChatPersona> onChanged;

  const PersonaDropdown({
    super.key,
    required this.value,
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
          DropdownButton<ChatPersona>(
            value: value,
            items: ChatPersona.values.map<DropdownMenuItem<ChatPersona>>((
              ChatPersona value,
            ) {
              return DropdownMenuItem<ChatPersona>(
                value: value,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(value.name.toUpperCase()),
                ),
              );
            }).toList(),
            onChanged: (ChatPersona? newValue) {
              if (newValue != null) onChanged(newValue);
            },
          ),
        ],
      ),
    );
  }
}
