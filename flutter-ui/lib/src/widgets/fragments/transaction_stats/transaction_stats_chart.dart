import 'package:ahorro_ui/src/models/currencies.dart';
import 'package:ahorro_ui/src/providers/transaction_stats_provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TransactionStatsChart extends StatelessWidget {
  const TransactionStatsChart({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionStatsProvider>();
    final data = provider.data?.items ?? []; // Get the transaction stats items
    final isLoading = provider.loading;
    final typeLabel = provider.selectedTypeLabel;
    final chartType = provider.selectedChartType;

    debugPrint(
      'TransactionStatsChart: data length = ${data.length}, isLoading = $isLoading, chartType = $chartType',
    );

    // Consistent container for all states
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(
        8.0,
      ), // Reduced padding to give more chart space
      child: RefreshIndicator(
        onRefresh: () async {
          // Trigger a manual refresh
          await provider.refresh();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                height:
                    constraints.maxHeight +
                    1, // Make it slightly taller to enable scrolling for refresh
                width: constraints.maxWidth,
                child: SizedBox(
                  height: constraints
                      .maxHeight, // Chart takes exact available height
                  width: constraints.maxWidth,
                  child: _buildChartContent(
                    isLoading,
                    data,
                    typeLabel,
                    chartType,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartContent(
    bool isLoading,
    List data,
    String selectedTypeLabel,
    ChartType chartType,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Validate and prepare chart data with proper error handling
    final validData = data.where((item) {
      return item.amount > 0 &&
          item.label.isNotEmpty &&
          item.amount.isFinite &&
          !item.amount.isNaN;
    }).toList();

    if (validData.isEmpty) {
      return const Center(child: Text('No valid data to display'));
    }

    var chartDataList = validData.map((item) {
      return _ChartData(
        item.label,
        item.amount / 100,
        formatAmountInt(item.amount, item.currency),
      );
    }).toList();

    var total = validData.fold<int>(
      0,
      (sum, item) => sum + (item.amount as int),
    );

    try {
      debugPrint('Attempting to create Syncfusion Chart with type: $chartType');

      switch (chartType) {
        case ChartType.pie:
          return _buildPieChart(
            selectedTypeLabel,
            total,
            validData,
            chartDataList,
          );
        case ChartType.donut:
          return _buildDonutChart(
            selectedTypeLabel,
            total,
            validData,
            chartDataList,
          );
        case ChartType.bar:
          return _buildBarChart(
            selectedTypeLabel,
            total,
            validData,
            chartDataList,
          );
        case ChartType.line:
          return _buildLineChart(
            selectedTypeLabel,
            total,
            validData,
            chartDataList,
          );
      }
    } catch (e) {
      debugPrint('Error creating Syncfusion Chart: $e');
      return Center(child: Text('Error: $e'));
    }
  }

  SfCircularChart _buildPieChart(
    String selectedTypeLabel,
    int total,
    List<dynamic> validData,
    List<_ChartData> chartDataList,
  ) {
    return SfCircularChart(
      title: ChartTitle(
        text:
            'Total $selectedTypeLabel: ${formatAmountInt(total, validData.first.currency)}',
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap, // Enable multiline legend
        textStyle: TextStyle(fontSize: 10), // Smaller font for more space
        itemPadding: 4, // Reduced padding for more space
        padding: 8, // Padding around the legend
      ),
      series: <CircularSeries>[
        PieSeries<_ChartData, String>(
          dataSource: chartDataList,
          xValueMapper: (_ChartData data, _) => data.label,
          yValueMapper: (_ChartData data, _) => data.amount,
          dataLabelMapper: (_ChartData data, _) =>
              data.formattedAmount, // Show only amount, not category
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ), // Smaller font
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '10%', // Shorter connector lines
            ),
            margin: EdgeInsets.all(2), // Reduce margin around labels
          ),
          enableTooltip: true,
          animationDuration: 1000,
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y', // Shows "Category: Amount"
        textStyle: const TextStyle(fontSize: 12),
        canShowMarker: true,
        header: '', // Remove header to save space
      ),
    );
  }

  SfCircularChart _buildDonutChart(
    String selectedTypeLabel,
    int total,
    List<dynamic> validData,
    List<_ChartData> chartDataList,
  ) {
    return SfCircularChart(
      title: ChartTitle(
        text:
            'Total $selectedTypeLabel: ${formatAmountInt(total, validData.first.currency)}',
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      legend: const Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.wrap,
        textStyle: TextStyle(fontSize: 10),
        itemPadding: 4,
        padding: 8,
      ),
      series: <CircularSeries>[
        DoughnutSeries<_ChartData, String>(
          dataSource: chartDataList,
          xValueMapper: (_ChartData data, _) => data.label,
          yValueMapper: (_ChartData data, _) => data.amount,
          dataLabelMapper: (_ChartData data, _) => data.formattedAmount,
          innerRadius: '50%', // Creates the donut hole
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            labelPosition: ChartDataLabelPosition.outside,
            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            connectorLineSettings: ConnectorLineSettings(
              type: ConnectorType.curve,
              length: '10%',
            ),
            margin: EdgeInsets.all(2),
          ),
          enableTooltip: true,
          animationDuration: 1000,
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y',
        textStyle: const TextStyle(fontSize: 12),
        canShowMarker: true,
        header: '',
      ),
    );
  }

  SfCartesianChart _buildBarChart(
    String selectedTypeLabel,
    int total,
    List<dynamic> validData,
    List<_ChartData> chartDataList,
  ) {
    return SfCartesianChart(
      title: ChartTitle(
        text:
            'Total $selectedTypeLabel: ${formatAmountInt(total, validData.first.currency)}',
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      primaryXAxis: const CategoryAxis(
        labelStyle: TextStyle(fontSize: 10),
        labelRotation: -45, // Rotate labels for better fit
      ),
      primaryYAxis: const NumericAxis(labelStyle: TextStyle(fontSize: 10)),
      legend: const Legend(
        isVisible:
            false, // Hide legend for bar chart as categories are on x-axis
      ),
      series: <CartesianSeries>[
        ColumnSeries<_ChartData, String>(
          dataSource: chartDataList,
          xValueMapper: (_ChartData data, _) => data.label,
          yValueMapper: (_ChartData data, _) => data.amount,
          dataLabelMapper: (_ChartData data, _) => data.formattedAmount,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            labelAlignment: ChartDataLabelAlignment.top,
          ),
          enableTooltip: true,
          animationDuration: 1000,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y',
        textStyle: const TextStyle(fontSize: 12),
        canShowMarker: true,
        header: '',
      ),
    );
  }

  SfCartesianChart _buildLineChart(
    String selectedTypeLabel,
    int total,
    List<dynamic> validData,
    List<_ChartData> chartDataList,
  ) {
    return SfCartesianChart(
      title: ChartTitle(
        text:
            'Total $selectedTypeLabel: ${formatAmountInt(total, validData.first.currency)}',
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      primaryXAxis: const CategoryAxis(
        labelStyle: TextStyle(fontSize: 10),
        labelRotation: -45,
      ),
      primaryYAxis: const NumericAxis(labelStyle: TextStyle(fontSize: 10)),
      legend: const Legend(isVisible: false),
      series: <CartesianSeries>[
        LineSeries<_ChartData, String>(
          dataSource: chartDataList,
          xValueMapper: (_ChartData data, _) => data.label,
          yValueMapper: (_ChartData data, _) => data.amount,
          dataLabelMapper: (_ChartData data, _) => data.formattedAmount,
          color: const Color(0xFF6B7280),
          width: 3,
          markerSettings: const MarkerSettings(
            isVisible: true,
            shape: DataMarkerType.circle,
            width: 8,
            height: 8,
            borderWidth: 2,
            borderColor: Colors.white,
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            labelAlignment: ChartDataLabelAlignment.top,
          ),
          enableTooltip: true,
          animationDuration: 1000,
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        format: 'point.x: point.y',
        textStyle: const TextStyle(fontSize: 12),
        canShowMarker: true,
        header: '',
      ),
    );
  }
}

// Helper class for chart data
class _ChartData {
  _ChartData(this.label, this.amount, this.formattedAmount);
  final String label;
  final double amount;
  final String formattedAmount;
}
