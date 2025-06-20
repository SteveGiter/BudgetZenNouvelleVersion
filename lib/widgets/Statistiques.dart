import 'package:flutter/material.dart';
import '../colors/app_colors.dart';
import '../services/firebase/firestore.dart';

class Statistiques extends StatefulWidget {
  const Statistiques({super.key, required this.userId});

  final String userId;

  @override
  State<Statistiques> createState() => _StatistiquesState();
}

class _StatistiquesState extends State<Statistiques> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart,
                color: isDarkMode ? AppColors.darkSecondaryColor : Colors.blue.shade800,
                size: 50,
              ),
              const SizedBox(width: 10),
              Text(
                'Statistiques',
                style: TextStyle(
                  fontSize: 20,
                  color: isDarkMode ? AppColors.darkSecondaryColor : Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder(
            stream: _firestoreService.streamTotalDepenses(widget.userId),
            builder: (context, depensesSnapshot) {
              return StreamBuilder(
                stream: _firestoreService.streamTotalRevenus(widget.userId),
                builder: (context, revenusSnapshot) {
                  final totalDepenses = depensesSnapshot.data ?? 0.0;
                  final totalRevenus = revenusSnapshot.data ?? 0.0;

                  if (totalDepenses == 0.0 && totalRevenus == 0.0) {
                    return Center(
                      child: Tooltip(
                        message: 'Aucune statistique disponible',
                        child: Image.asset(
                          'assets/noStatisticsImage.png',
                          width: 200,
                          height: 200,
                          color: isDarkMode ? AppColors.darkIconColor : null,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.error,
                              size: 50,
                              color: isDarkMode
                                  ? AppColors.darkErrorColor
                                  : AppColors.errorColor,
                            );
                          },
                        ),
                      ),
                    );
                  } else {
                    return _buildStatisticsChart(totalDepenses, totalRevenus, isDarkMode);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsChart(double depenses, double revenus, bool isDarkMode) {
    final maxValue = depenses > revenus ? depenses : revenus;
    final depensesHeight = depenses / maxValue * 150;
    final revenusHeight = revenus / maxValue * 150;

    return Column(
      children: [
        Text(
          'Mois de ${_getCurrentMonth()} ${DateTime.now().year}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              children: [
                Container(
                  width: 60,
                  height: depensesHeight,
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Dépenses',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                  ),
                ),
                Text(
                  '${depenses.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                  ),
                ),
              ],
            ),
            Column(
              children: [
                Container(
                  width: 60,
                  height: revenusHeight,
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Revenus',
                  style: TextStyle(
                    color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                  ),
                ),
                Text(
                  '${revenus.toStringAsFixed(2)} €',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),
        Text(
          'Année ${DateTime.now().year}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildYearlyStat('Dépenses', depenses, Colors.red.shade400, isDarkMode),
            _buildYearlyStat('Revenus', revenus, Colors.green.shade400, isDarkMode),
          ],
        ),
      ],
    );
  }

  Widget _buildYearlyStat(String label, double value, Color color, bool isDarkMode) {
    return Column(
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
        ),
        Text(
          '${value.toStringAsFixed(2)} €',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
        ),
      ],
    );
  }

  String _getCurrentMonth() {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[DateTime.now().month - 1];
  }
}