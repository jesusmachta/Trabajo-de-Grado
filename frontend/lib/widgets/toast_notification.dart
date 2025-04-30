import 'package:flutter/material.dart';

enum NotificationType { success, error, info, warning }

class ToastNotification extends StatefulWidget {
  final String message;
  final NotificationType type;
  final VoidCallback onDismiss;
  final Duration duration;

  const ToastNotification({
    Key? key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.duration = const Duration(seconds: 2),
  }) : super(key: key);

  @override
  State<ToastNotification> createState() => _ToastNotificationState();
}

class _ToastNotificationState extends State<ToastNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();

    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismissNotification();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismissNotification() {
    _animationController.reverse().then((_) {
      widget.onDismiss();
    });
  }

  IconData _getIconForType() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.info:
        return Icons.info_outline;
    }
  }

  Color _getColorForType() {
    switch (widget.type) {
      case NotificationType.success:
        return Colors.green.shade700;
      case NotificationType.error:
        return Colors.red.shade700;
      case NotificationType.warning:
        return Colors.orange.shade700;
      case NotificationType.info:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Color(0xFF323232) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          constraints: const BoxConstraints(
            maxWidth: 400,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 56,
                  color: _getColorForType(),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        _getIconForType(),
                        color: _getColorForType(),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: isDark ? Colors.white70 : Colors.black54,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        visualDensity: VisualDensity.compact,
                        onPressed: _dismissNotification,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToastService {
  static OverlayEntry? _currentNotification;

  static void show({
    required BuildContext context,
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Dismiss any existing notification first
    dismiss();

    // Create the new overlay entry
    _currentNotification = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 16,
        right: 16,
        child: ToastNotification(
          message: message,
          type: type,
          duration: duration,
          onDismiss: dismiss,
        ),
      ),
    );

    // Insert the overlay
    Overlay.of(context).insert(_currentNotification!);
  }

  static void dismiss() {
    _currentNotification?.remove();
    _currentNotification = null;
  }

  static void showSuccess(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: NotificationType.success,
    );
  }

  static void showError(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: NotificationType.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: NotificationType.info,
    );
  }

  static void showWarning(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: NotificationType.warning,
    );
  }
}
