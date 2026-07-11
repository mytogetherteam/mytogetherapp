import 'package:flutter/material.dart';
import 'package:mytogetherapp/features/chat/data/services/chat_unread_controller.dart';

class ChatShakeAnimator extends StatefulWidget {
  final int? orderId;
  final Widget child;

  const ChatShakeAnimator({
    super.key,
    required this.orderId,
    required this.child,
  });

  @override
  State<ChatShakeAnimator> createState() => _ChatShakeAnimatorState();
}

class _ChatShakeAnimatorState extends State<ChatShakeAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    if (widget.orderId != null) {
      final notifier = ChatUnreadController.instance.notifierFor(widget.orderId!);
      _lastCount = notifier.value;
      notifier.addListener(_onCountChanged);
    }
  }

  void _onCountChanged() {
    if (!mounted || widget.orderId == null) return;
    final notifier = ChatUnreadController.instance.notifierFor(widget.orderId!);
    final newCount = notifier.value;
    if (newCount > _lastCount) {
      _shakeController.forward(from: 0.0);
    }
    _lastCount = newCount;
  }

  @override
  void didUpdateWidget(ChatShakeAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      if (oldWidget.orderId != null) {
        ChatUnreadController.instance
            .notifierFor(oldWidget.orderId!)
            .removeListener(_onCountChanged);
      }
      if (widget.orderId != null) {
        final notifier = ChatUnreadController.instance.notifierFor(widget.orderId!);
        _lastCount = notifier.value;
        notifier.addListener(_onCountChanged);
      }
    }
  }

  @override
  void dispose() {
    if (widget.orderId != null) {
      ChatUnreadController.instance
          .notifierFor(widget.orderId!)
          .removeListener(_onCountChanged);
    }
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
