import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Image picker button for attaching images
/// Extracted from ai_text_input.dart (358 → 50 lines)
class ImagePickerButton extends StatelessWidget {
  final Function(String imagePath) onImagePicked;

  const ImagePickerButton({
    super.key,
    required this.onImagePicked,
  });

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        onImagePicked(image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.image),
      onPressed: _pickImage,
      tooltip: 'Attach image',
    );
  }
}
