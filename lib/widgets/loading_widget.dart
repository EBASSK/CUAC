import 'package:flutter/material.dart';
import '../config/theme.dart';

class LoadingWidget extends StatefulWidget {
  final String message;
  final double progress;

  const LoadingWidget({
    Key? key,
    this.message = 'Procesando imagen...',
    this.progress = 0.0,
  }) : super(key: key);

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Spinner animado
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primary,
              ),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(height: 20),
          // Mensaje
          Text(
            widget.message,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),
          // Progress bar
          if (widget.progress > 0)
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: widget.progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.secondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          // Porcentaje
          if (widget.progress > 0)
            Text(
              '${(widget.progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
        ],
      ),
    );
  }
}

// Widget para loading simple
class SimpleLoadingWidget extends StatelessWidget {
  final String? message;

  const SimpleLoadingWidget({
    Key? key,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primary.withOpacity(0.7),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 15),
            Text(
              message!,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
