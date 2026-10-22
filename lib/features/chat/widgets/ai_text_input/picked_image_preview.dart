import 'dart:io';

import 'package:flutter/material.dart';

/// Widget displaying a preview of a selected image
class PickedImagePreview extends StatelessWidget {
  const PickedImagePreview({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          width: 100,
          height: 100,
        ),
      ),
    );
  }
}
