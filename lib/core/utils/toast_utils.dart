import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastUtils {
  static void show(BuildContext context, String message, {ToastificationType type = ToastificationType.info}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(message),
      alignment: Alignment.bottomRight,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
      closeButton: const ToastCloseButton(
        showType: CloseButtonShowType.onHover,
      ),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      borderSide: isDark ? BorderSide.none : null,
      boxShadow: [
        BoxShadow(
          color: isDark ? Colors.black45 : Colors.black12,
          blurRadius: 8,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  static void showSuccess(BuildContext context, String message) {
    show(context, message, type: ToastificationType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context, message, type: ToastificationType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, message, type: ToastificationType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, message, type: ToastificationType.success);
  }
}
