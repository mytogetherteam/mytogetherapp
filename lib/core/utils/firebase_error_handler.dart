import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../localization/app_translations.dart';

class FirebaseErrorHandler {
  static String getMessage(BuildContext context, dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-phone-number':
          return context.tr('firebase.invalid_phone');
        case 'too-many-requests':
          return context.tr('firebase.too_many_requests');
        case 'invalid-verification-code':
          return context.tr('firebase.invalid_code');
        case 'invalid-verification-id':
        case 'session-expired':
          return context.tr('firebase.session_expired');
        case 'network-request-failed':
          return context.tr('firebase.network_error');
        case 'user-disabled':
          return context.tr('firebase.user_disabled');
        default:
          return error.message ?? context.tr('firebase.unknown_error');
      }
    }
    
    // For non-Firebase errors or string exceptions
    return error.toString();
  }
}
