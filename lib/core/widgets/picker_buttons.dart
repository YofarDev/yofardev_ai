import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../res/app_constants.dart';
import 'glassmorphic/glassmorphic_icon_button.dart';

class PickerButtons extends StatelessWidget {
  final Function(File? file) onImageSelected;

  const PickerButtons({super.key, required this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!kIsWeb)
          GlassmorphicIconButton(
            icon: Icons.image_outlined,
            onPressed: _onGalleryPickerButtonPressed,
          ),
        const SizedBox(width: 8),
        GlassmorphicIconButton(
          icon: Icons.camera_alt_outlined,
          onPressed: _onTakePhotoButtonPressed,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

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
