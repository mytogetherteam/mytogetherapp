import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

ImageProvider localImageProvider(XFile file) => NetworkImage(file.path);
