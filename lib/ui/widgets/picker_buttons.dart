import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../res/app_constants.dart';

class PickerButtons extends StatelessWidget {
  final Function(File? file) onImageSelected;

  const PickerButtons({
    super.key,
    required this.onImageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!kIsWeb)
          _buildIconButton(Icons.image_outlined, _onGalleryPickerButtonPressed),
        const SizedBox(width: 8),
        _buildIconButton(Icons.camera_alt_outlined, _onTakePhotoButtonPressed),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) => InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.7),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Icon(
            icon,
            size: 24,
          ),
        ),
      );

  void _onTakePhotoButtonPressed() async {
    await ImagePicker()
        .pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: AppConstants.pickedImageMaxWidth,
      maxHeight: AppConstants.pickedImageMaxHeight,
    )
        .then((XFile? photo) {
      _onImageSelected(photo);
    });
  }

  void _onGalleryPickerButtonPressed() async {
    final ImagePicker picker = ImagePicker();
    await picker
        .pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: AppConstants.pickedImageMaxWidth,
      maxHeight: AppConstants.pickedImageMaxHeight,
    )
        .then((XFile? photo) {
      _onImageSelected(photo);
    });
  }

  void _onImageSelected(XFile? file) async {
    if (file == null) {
      onImageSelected(null);
      return;
    }
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String fileName = path.basename(file.path);
    final File savedImage = File('${appDir.path}/$fileName');
    await File(file.path).copy(savedImage.path);
    onImageSelected(savedImage);
  }
}
