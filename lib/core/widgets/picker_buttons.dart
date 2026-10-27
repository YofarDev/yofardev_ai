import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../res/app_constants.dart';
import 'app_icon_button.dart';

class PickerButtons extends StatelessWidget {
  final Function(File? file) onImageSelected;

  const PickerButtons({super.key, required this.onImageSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!kIsWeb)
          AppIconButton(
            onPressed: _onGalleryPickerButtonPressed,
            icon: Icons.image_outlined,
          ),

        if (Platform.isAndroid || Platform.isIOS)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: AppIconButton(
              onPressed: _onTakePhotoButtonPressed,
              icon: Icons.camera_alt_outlined,
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _onTakePhotoButtonPressed() async {
    onImageSelected(await pickImageFile(fromCamera: true));
  }

  void _onGalleryPickerButtonPressed() async {
    onImageSelected(await pickImageFile());
  }
}

/// Lets the user pick a photo from the gallery (or take one with the camera
/// when [fromCamera]), downscaled to the app's max picked-image size, and
/// copies it into the app documents directory. Null when cancelled.
Future<File?> pickImageFile({bool fromCamera = false}) async {
  final XFile? file = await ImagePicker().pickImage(
    source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 75,
    maxWidth: AppConstants.pickedImageMaxWidth,
    maxHeight: AppConstants.pickedImageMaxHeight,
  );
  if (file == null) {
    return null;
  }
  final Directory appDir = await getApplicationDocumentsDirectory();
  final String fileName = path.basename(file.path);
  final File savedImage = File('${appDir.path}/$fileName');
  await File(file.path).copy(savedImage.path);
  return savedImage;
}
