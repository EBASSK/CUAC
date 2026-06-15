import 'package:flutter/material.dart';
import '../models/prediction.dart';
import '../config/theme.dart';

class PredictionCard extends StatelessWidget {
  final Prediction prediction;
  final int rank; // 1, 2, 3
  final bool isMainPrediction;

  const PredictionCard({
    Key? key,
    required this.prediction,
    required this.rank,
    this.isMainPrediction = false,
  }) : super(key: key);

  Color _getConfidenceColor() {
    if (prediction.confidence >= 0.8) {
      return AppTheme.secondary; // Verde
    } else if (prediction.confidence >= 0.5) {
      return AppTheme.accent; // Naranja
    } else {
      return Colors.red.withOpacity(0.7); // Rojo
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isMainPrediction) {
      return _buildMainCard();
    } else {
      return _buildAlternativeCard();
    }
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.1),
            AppTheme.secondary.withOpacity(0.1),
          ],
        ),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.3),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Icono y nombre
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      prediction.category,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Confianza circular
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getConfidenceColor().withOpacity(0.1),
              border: Border.all(
                color: _getConfidenceColor(),
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${prediction.getConfidencePercent()}%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(),
                    ),
                  ),
                  const Text(
                    'Confianza',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Ranking
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getConfidenceColor().withOpacity(0.2),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getConfidenceColor(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Nombre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prediction.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  prediction.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Confianza
          Text(
            '${prediction.getConfidencePercent()}%',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _getConfidenceColor(),
            ),
          ),
        ],
      ),
    );
  }
}
