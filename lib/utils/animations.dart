import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// iOS 风格动画工具类
class IosAnimations {
  // ========== 页面路由动画 ==========

  /// iOS 风格从右侧滑入的路由动画
  static Route<T> slideFromRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// iOS 风格从底部弹出的模态动画
  static Route<T> presentFromBottom<T>(Widget page) {
    return PageRouteBuilder<T>(
      opaque: false,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// iOS 风格淡入动画
  static Route<T> fadeIn<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
  }

  // ========== 列表动画 ==========

  /// iOS 风格列表项插入动画
  static Widget listItemAnimation({
    required Widget child,
    required Animation<double> animation,
    bool fromBottom = true,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: fromBottom ? const Offset(0.0, 0.3) : const Offset(0.3, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  // ========== 按钮动画 ==========

  /// iOS 风格按钮点击缩放动画
  static Widget scaleOnTap({
    required Widget child,
    required VoidCallback? onTap,
    double scale = 0.95,
  }) {
    return _ScaleButton(
      onTap: onTap,
      scale: scale,
      child: child,
    );
  }

  // ========== 开关动画 ==========

  /// iOS 风格开关切换动画
  static Widget animatedSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return AnimatedSwitcher(
      duration: duration,
      child: CupertinoSwitch(
        key: ValueKey(value),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

/// 点击缩放按钮
class _ScaleButton extends StatefulWidget {
  const _ScaleButton({
    required this.child,
    required this.onTap,
    this.scale = 0.95,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: widget.scale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// iOS 风格动画列表
class IosAnimatedList extends StatefulWidget {
  const IosAnimatedList({
    super.key,
    required this.children,
    this.padding,
    this.scrollDirection = Axis.vertical,
  });

  final List<Widget> children;
  final EdgeInsets? padding;
  final Axis scrollDirection;

  @override
  State<IosAnimatedList> createState() => _IosAnimatedListState();
}

class _IosAnimatedListState extends State<IosAnimatedList>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );
    _animations = _controllers.map((controller) {
      return CurvedAnimation(
        parent: controller,
        curve: Curves.easeOutCubic,
      );
    }).toList();

    // 依次播放动画
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: widget.padding,
      scrollDirection: widget.scrollDirection,
      children: List.generate(widget.children.length, (index) {
        return IosAnimations.listItemAnimation(
          child: widget.children[index],
          animation: _animations[index],
        );
      }),
    );
  }
}

/// iOS 风格 Hero 动画包装
class IosHeroAnimation extends StatelessWidget {
  const IosHeroAnimation({
    super.key,
    required this.tag,
    required this.child,
  });

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: (
        flightContext,
        animation,
        flightDirection,
        fromHeroContext,
        toHeroContext,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + 0.2 * animation.value,
              child: Opacity(
                opacity: 0.5 + 0.5 * animation.value,
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      child: child,
    );
  }
}
