import 'package:flutter/material.dart';
import '../utils/database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  DateTime? startDate;
  DateTime? endDate;

  double totalIncome = 0.0;
  double totalExpense = 0.0;

  List<Map<String, dynamic>> filteredIncome = [];
  List<Map<String, dynamic>> filteredExpense = [];

  double netBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _calculateNetBalance();
  }

  Future<void> _calculateNetBalance() async {
    try {
      final incomeData = await dbHelper.fetchTransactions(true);
      final expenseData = await dbHelper.fetchTransactions(false);

      final totalIncome = incomeData.fold(
        0.0,
        (sum, t) => sum + (t['amount'] ?? 0.0),
      );
      final totalExpense = expenseData.fold(
        0.0,
        (sum, t) => sum + (t['amount'] ?? 0.0),
      );

      setState(() {
        netBalance = totalIncome - totalExpense;
      });
    } catch (e) {
      debugPrint('Error calculating net balance: $e');
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange:
          startDate != null && endDate != null
              ? DateTimeRange(start: startDate!, end: endDate!)
              : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _calculateMetrics(); // Automatically calculate metrics after selecting a date range
    }
  }

  void _calculateMetrics() async {
    if (startDate != null && endDate != null) {
      try {
        // Fetch all income and expense transactions
        final incomeData = await dbHelper.fetchTransactions(true);
        final expenseData = await dbHelper.fetchTransactions(false);

        // Filter transactions based on the selected date range
        setState(() {
          filteredIncome =
              incomeData.where((t) {
                final date = DateTime.parse(t['date']);
                return date.isAfter(
                      startDate!.subtract(const Duration(days: 1)),
                    ) &&
                    date.isBefore(endDate!.add(const Duration(days: 1)));
              }).toList();

          filteredExpense =
              expenseData.where((t) {
                final date = DateTime.parse(t['date']);
                return date.isAfter(
                      startDate!.subtract(const Duration(days: 1)),
                    ) &&
                    date.isBefore(endDate!.add(const Duration(days: 1)));
              }).toList();

          // Calculate total income and expense
          totalIncome = filteredIncome.fold(
            0.0,
            (sum, t) => sum + (t['amount'] ?? 0.0),
          );
          totalExpense = filteredExpense.fold(
            0.0,
            (sum, t) => sum + (t['amount'] ?? 0.0),
          );
        });
      } catch (e) {
        debugPrint('Error calculating metrics: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to calculate metrics.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid date range.')),
      );
    }
  }

  void _generatePDF() async {
    if (startDate == null || endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range first.')),
      );
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build:
            (context) => [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Financial Report',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Date Range: ${startDate!.toLocal().year}-${startDate!.toLocal().month.toString().padLeft(2, '0')}-${startDate!.toLocal().day.toString().padLeft(2, '0')} '
                'to ${endDate!.toLocal().year}-${endDate!.toLocal().month.toString().padLeft(2, '0')}-${endDate!.toLocal().day.toString().padLeft(2, '0')}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Detailed Transactions',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Date', 'Title', 'Income', 'Expense'],
                data: [
                  ...filteredIncome.map(
                    (t) => [
                      '${DateTime.parse(t['date']).toLocal().year}-${DateTime.parse(t['date']).toLocal().month.toString().padLeft(2, '0')}-${DateTime.parse(t['date']).toLocal().day.toString().padLeft(2, '0')}',
                      t['title'],
                      '\Rs.${t['amount'].toStringAsFixed(2)}',
                      '',
                    ],
                  ),
                  ...filteredExpense.map(
                    (t) => [
                      '${DateTime.parse(t['date']).toLocal().year}-${DateTime.parse(t['date']).toLocal().month.toString().padLeft(2, '0')}-${DateTime.parse(t['date']).toLocal().day.toString().padLeft(2, '0')}',
                      t['title'],
                      '',
                      '\Rs.${t['amount'].toStringAsFixed(2)}',
                    ],
                  ),
                  // Add a summary row for totals
                  [
                    'Total',
                    '',
                    '\Rs.${totalIncome.toStringAsFixed(2)}',
                    '\Rs.${totalExpense.toStringAsFixed(2)}',
                  ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Final Balance: \Rs.${(totalIncome - totalExpense).toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue,
                ),
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generate PDF',
            onPressed: _generatePDF,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net Balance: \Rs:${netBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Income vs Expenses',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _selectDateRange(context),
              child: const Text('Select Date Range'),
            ),
            if (startDate != null && endDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  'Selected Range: ${startDate!.toLocal().year}-'
                  '${startDate!.toLocal().month.toString().padLeft(2, '0')}-'
                  '${startDate!.toLocal().day.toString().padLeft(2, '0')} - '
                  '${endDate!.toLocal().year}-'
                  '${endDate!.toLocal().month.toString().padLeft(2, '0')}-'
                  '${endDate!.toLocal().day.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (totalIncome > 0 || totalExpense > 0)
              Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Income: \Rs.${totalIncome.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Expense: \Rs.${totalExpense.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, color: Colors.red),
                      ),
                      Text(
                        'Net Balance: \Rs.${(totalIncome - totalExpense).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (filteredIncome.isNotEmpty || filteredExpense.isNotEmpty)
              Expanded(
                child: ListView(
                  children: [
                    const Text(
                      'Income Transactions:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...filteredIncome.map(
                      (t) => ListTile(
                        title: Text(t['title']),
                        subtitle: Text(
                          'Amount: \Rs.${t['amount'].toStringAsFixed(2)}\n'
                          '${DateTime.parse(t['date']).toLocal().year}-'
                          '${DateTime.parse(t['date']).toLocal().month.toString().padLeft(2, '0')}-'
                          '${DateTime.parse(t['date']).toLocal().day.toString().padLeft(2, '0')} '
                          '${DateTime.parse(t['date']).toLocal().hour > 12 ? DateTime.parse(t['date']).toLocal().hour - 12 : DateTime.parse(t['date']).toLocal().hour}:'
                          '${DateTime.parse(t['date']).toLocal().minute.toString().padLeft(2, '0')} '
                          '${DateTime.parse(t['date']).toLocal().hour >= 12 ? 'PM' : 'AM'}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Expense Transactions:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ...filteredExpense.map(
                      (t) => ListTile(
                        title: Text(t['title']),
                        subtitle: Text(
                          'Amount: \Rs.${t['amount'].toStringAsFixed(2)}\n'
                          '${DateTime.parse(t['date']).toLocal().year}-'
                          '${DateTime.parse(t['date']).toLocal().month.toString().padLeft(2, '0')}-'
                          '${DateTime.parse(t['date']).toLocal().day.toString().padLeft(2, '0')} '
                          '${DateTime.parse(t['date']).toLocal().hour > 12 ? DateTime.parse(t['date']).toLocal().hour - 12 : DateTime.parse(t['date']).toLocal().hour}:'
                          '${DateTime.parse(t['date']).toLocal().minute.toString().padLeft(2, '0')} '
                          '${DateTime.parse(t['date']).toLocal().hour >= 12 ? 'PM' : 'AM'}',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
