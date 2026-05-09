import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

Widget buildWebImage(String imageUrl, BoxFit fit) {
  final viewId = 'web-img-${imageUrl.hashCode}';
  
  try {
    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) {
        final img = html.ImageElement()
          ..src = imageUrl
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..style.outline = 'none';
        
        if (fit == BoxFit.cover) {
          img.style.objectFit = 'cover';
        } else if (fit == BoxFit.contain) {
          img.style.objectFit = 'contain';
        } else if (fit == BoxFit.fill) {
          img.style.objectFit = 'fill';
        }
        
        return img;
      },
    );
  } catch (e) {
    // Factory already registered, ignore.
  }

  return HtmlElementView(viewType: viewId);
}
