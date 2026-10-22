import 'dart:io';

import 'package:flutter/material.dart';

class ImageFullScreen extends StatelessWidget {
  final String imagePath;
  const ImageFullScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Hero(tag: imagePath, child: Image.file(File(imagePath))),
      ),
    );
  }
}
