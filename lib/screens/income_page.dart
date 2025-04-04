import 'package:flutter/material.dart';
import '../utils/database_helper.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  List<Map<String, dynamic>> incomeTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadIncomeTransactions();
  }

  Future<void> _loadIncomeTransactions() async {
    final data = await dbHelper.fetchTransactions(true);
    setState(() {
      incomeTransactions = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Income'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: incomeTransactions.length,
          itemBuilder: (context, index) {
            final transaction = incomeTransactions[index];
            return Card(
              elevation: 4,
              margin: const EdgeInsets.only(bottom: 16.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                title: Text(
                  transaction['title'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Amount: \$${transaction['amount'].toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editTransaction(context, transaction),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteTransaction(transaction['id']),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _editTransaction(
    BuildContext context,
    Map<String, dynamic> transaction,
  ) {
    final TextEditingController titleController = TextEditingController(
      text: transaction['title'],
    );
    final TextEditingController amountController = TextEditingController(
      text: transaction['amount'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Income'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text;
                final amount = double.tryParse(amountController.text) ?? 0.0;

                if (title.isNotEmpty && amount > 0) {
                  await dbHelper.updateTransaction(
                    transaction['id'],
                    title,
                    amount,
                  );
                  _loadIncomeTransactions();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(int id) async {
    await dbHelper.deleteTransaction(id);
    _loadIncomeTransactions();
  }
}
