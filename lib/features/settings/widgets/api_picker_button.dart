import 'package:flutter/material.dart';

import '../../../ui/pages/settings/llm/llm_selection_page.dart';
import '../../../ui/widgets/constrained_width.dart';

/// Button to navigate to LLM API selection page
class ApiPickerButton extends StatelessWidget {
  const ApiPickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: const Text('Api Picker'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<dynamic>(
            builder: (BuildContext context) =>
                const ConstrainedWidth(child: LlmSelectionPage()),
          ),
        );
      },
    );
  }
}
