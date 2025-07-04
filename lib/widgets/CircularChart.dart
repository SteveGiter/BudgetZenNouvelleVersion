import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../colors/app_colors.dart';
import '../services/firebase/firestore.dart';

class CircularChart extends StatefulWidget {
  const CircularChart({super.key, required this.userId, required this.selectedMonth});

  final String userId;
  final int selectedMonth;

  @override
  State<CircularChart> createState() => _CircularChartState();
}

class _CircularChartState extends State<CircularChart> {
  final FirestoreService _firestoreService = FirestoreService();
  int touchedIndex = -1;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (!_initialized) {
      _initialized = true;
      _firestoreService.createOrUpdateStatistiques(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatisticsStream(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildStatisticsStream(bool isDarkMode) {
    return StreamBuilder<double>(
      stream: _firestoreService.streamTotalDepensesByMonth(widget.userId, widget.selectedMonth),
      builder: (context, depensesSnapshot) {
        if (depensesSnapshot.hasError) {
          return const Center(child: Text('Erreur de chargement des dépenses'));
        }

        return StreamBuilder<double>(
          stream: _firestoreService.streamTotalRevenusByMonth(widget.userId, widget.selectedMonth),
          builder: (context, revenusSnapshot) {
            if (revenusSnapshot.hasError) {
              return const Center(child: Text('Erreur de chargement des revenus'));
            }

            return StreamBuilder<double>(
              stream: _firestoreService.streamTotalEpargnesByMonth(widget.userId, widget.selectedMonth),
              builder: (context, epargnesSnapshot) {
                if (epargnesSnapshot.hasError) {
                  return const Center(child: Text('Erreur de chargement des épargnes'));
                }

                return StreamBuilder<double>(
                  stream: _firestoreService.streamMontantDisponible(widget.userId),
                  builder: (context, montantDisponibleSnapshot) {
                    if (montantDisponibleSnapshot.hasError) {
                      return const Center(child: Text('Erreur de chargement du solde'));
                    }

                    final totalDepenses = depensesSnapshot.data ?? 0.0;
                    final totalRevenus = revenusSnapshot.data ?? 0.0;
                    final totalEpargnes = epargnesSnapshot.data ?? 0.0;
                    final montantDisponible = montantDisponibleSnapshot.data ?? 0.0;

                    if (totalDepenses == 0.0 && totalRevenus == 0.0 && totalEpargnes == 0.0) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Tooltip(
                              message: 'Aucune statistique disponible',
                              child: Image.asset(
                                isDarkMode
                                  ? 'assets/noStatisticsImage.png'
                                  : 'assets/noStatisticsImage.png',
                                width: 200,
                                height: 200,
                                color: isDarkMode ? Colors.white.withOpacity(0.7) : null,
                                colorBlendMode: isDarkMode ? BlendMode.modulate : null,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.error,
                                    size: 50,
                                    color: isDarkMode ? AppColors.darkErrorColor : AppColors.errorColor,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Ajoutez des transactions pour voir vos statistiques !",
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? AppColors.darkSecondaryTextColor : AppColors.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return _buildChartAndSummary(totalDepenses, totalRevenus, totalEpargnes, montantDisponible, isDarkMode);
                    }
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChartAndSummary(double totalDepenses, double totalRevenus, double totalEpargnes, double montantDisponible, bool isDarkMode) {
    final total = totalDepenses + totalRevenus + totalEpargnes;
    final isRevenueOnly = totalDepenses == 0 && totalEpargnes == 0 && totalRevenus > 0;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 0,
                  centerSpaceRadius: 60,
                  sections: showingSections(totalDepenses, totalRevenus, totalEpargnes, isDarkMode),
                ),
              ),
              if (isRevenueOnly)
                Text(
                  '100%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? AppColors.darkTextColor : Colors.black,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildLegend(isDarkMode),
        const SizedBox(height: 20),
        _buildMonthlySummary(totalDepenses, totalRevenus, totalEpargnes, montantDisponible, isDarkMode),
      ],
    );
  }

  List<PieChartSectionData> showingSections(double depenses, double revenus, double epargnes, bool isDarkMode) {
    final total = depenses + revenus + epargnes;
    final sections = <PieChartSectionData>[];

    // Compter le nombre de sections non nulles
    final nonZeroSections = [
      depenses > 0,
      revenus > 0,
      epargnes > 0,
    ].where((x) => x).length;

    // Si une seule section est non nulle, on n'affiche pas le titre
    final showTitles = nonZeroSections > 1;

    // Section Dépenses
    if (depenses > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.red.shade400,
          value: depenses,
          title: showTitles && total > 0 ? '${(depenses / total * 100).toStringAsFixed(1)}%' : '',
          radius: touchedIndex == sections.length ? 30 : 25,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
          showTitle: showTitles,
        ),
      );
    }

    // Section Revenus
    if (revenus > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.green.shade400,
          value: revenus,
          title: showTitles && total > 0 ? '${(revenus / total * 100).toStringAsFixed(1)}%' : '',
          radius: touchedIndex == sections.length ? 30 : 25,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
          showTitle: showTitles,
        ),
      );
    }

    // Section Épargnes
    if (epargnes > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.blue.shade400,
          value: epargnes,
          title: showTitles && total > 0 ? '${(epargnes / total * 100).toStringAsFixed(1)}%' : '',
          radius: touchedIndex == sections.length ? 30 : 25,
          titleStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
          showTitle: showTitles,
        ),
      );
    }

    // Si aucune section, ajouter un placeholder
    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: 1,
          title: '',
          radius: 25,
          showTitle: false,
        ),
      );
    }

    return sections;
  }

  Widget _buildLegend(bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem('Dépenses', Colors.red.shade400, isDarkMode),
        _buildLegendItem('Revenus', Colors.green.shade400, isDarkMode),
        _buildLegendItem('Épargnes', Colors.blue.shade400, isDarkMode),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlySummary(double depenses, double revenus, double epargnes, double montantDisponible, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mois de ${_getMonthName(widget.selectedMonth)} ${DateTime.now().year}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.darkTextColor : Colors.black,
          ),
        ),
        const SizedBox(height: 10),
        Column(
          children: [
            _buildSummaryItem('Dépenses totales', depenses, Colors.red.shade400, isDarkMode),
            _buildSummaryItem('Revenus totaux', revenus, Colors.green.shade400, isDarkMode),
            _buildSummaryItem('Épargnes totales', epargnes, Colors.blue.shade400, isDarkMode),
            _buildSummaryItem('Solde disponible', montantDisponible, Colors.green.shade600, isDarkMode),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, double value, Color color, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDarkMode ? AppColors.darkTextColor : Colors.black,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)} FCFA',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }
}