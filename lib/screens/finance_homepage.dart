import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/database_helper.dart';
import 'income_page.dart';
import 'expense_page.dart';
import 'analytics_page.dart';

class FinanceHomePage extends StatefulWidget {
  const FinanceHomePage({super.key});

  @override
  State<FinanceHomePage> createState() => _FinanceHomePageState();
}

class _FinanceHomePageState extends State<FinanceHomePage> {
  final List<Map<String, dynamic>> incomeTransactions = [];
  final List<Map<String, dynamic>> expenseTransactions = [];
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    try {
      final incomeData = await dbHelper.fetchTransactions(true);
      final expenseData = await dbHelper.fetchTransactions(false);

      setState(() {
        incomeTransactions.clear();
        expenseTransactions.clear();
        incomeTransactions.addAll(incomeData);
        expenseTransactions.addAll(expenseData);
      });
    } catch (e) {
      debugPrint('Error loading transactions: $e');
    }
  }

  Future<void> _syncToCloud() async {
    try {
      final incomeCollection = firestore.collection('income');
      final expenseCollection = firestore.collection('expenses');

      // Sync income transactions
      for (var transaction in incomeTransactions) {
        await incomeCollection
            .doc(transaction['id'].toString())
            .set(transaction);
      }

      // Sync expense transactions (fixing the issue)
      for (var transaction in expenseTransactions) {
        await expenseCollection
            .doc(transaction['id'].toString())
            .set(transaction);
      }

      // Delete cloud entries not present locally
      final cloudIncomeDocs = await incomeCollection.get();
      for (var doc in cloudIncomeDocs.docs) {
        if (!incomeTransactions.any((t) => t['id'].toString() == doc.id)) {
          await incomeCollection.doc(doc.id).delete();
        }
      }

      final cloudExpenseDocs = await expenseCollection.get();
      for (var doc in cloudExpenseDocs.docs) {
        if (!expenseTransactions.any((t) => t['id'].toString() == doc.id)) {
          await expenseCollection.doc(doc.id).delete();
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data synced to cloud successfully!')),
      );
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to sync data to cloud.')),
      );
    }
  }

  Future<void> _fetchFromCloud() async {
    try {
      final incomeCollection = firestore.collection('income');
      final expenseCollection = firestore.collection('expenses');

      final incomeDocs = await incomeCollection.get();
      final expenseDocs = await expenseCollection.get();

      setState(() {
        incomeTransactions.clear();
        expenseTransactions.clear();

        incomeTransactions.addAll(
          incomeDocs.docs.map((doc) => doc.data() as Map<String, dynamic>),
        );
        expenseTransactions.addAll(
          expenseDocs.docs.map((doc) => doc.data() as Map<String, dynamic>),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data fetched from cloud successfully!')),
      );
    } catch (e) {
      debugPrint('Error fetching from cloud: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch data from cloud.')),
      );
    }
  }

  void _addTransaction(bool isIncome) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController titleController = TextEditingController();
        final TextEditingController amountController = TextEditingController();

        return AlertDialog(
          title: Text(isIncome ? 'Add Income' : 'Add Expense'),
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
                  await dbHelper.insertTransaction(title, amount, isIncome);
                  _loadTransactions();
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editTransaction(bool isIncome, int index) {
    final transaction =
        isIncome ? incomeTransactions[index] : expenseTransactions[index];

    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController titleController = TextEditingController(
          text: transaction['title'],
        );
        final TextEditingController amountController = TextEditingController(
          text: transaction['amount'].toString(),
        );

        return AlertDialog(
          title: Text(isIncome ? 'Edit Income' : 'Edit Expense'),
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
                  _loadTransactions();
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

  void _deleteTransaction(bool isIncome, int index) async {
    final transaction =
        isIncome ? incomeTransactions[index] : expenseTransactions[index];

    await dbHelper.deleteTransaction(transaction['id']);
    _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finance Overview'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _syncToCloud,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download),
            onPressed: _fetchFromCloud,
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalyticsPage()),
              );
            },
          ),
        ],
      ),
      resizeToAvoidBottomInset: true, // Prevents overflow when keyboard opens
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Income Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.arrow_upward, // Income icon
                        color: Colors.green,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Income ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _addTransaction(true),
                        child: const Text('Add Income'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const IncomePage(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: screenHeight / 2 - 160,
                child: ListView.builder(
                  itemCount:
                      incomeTransactions.length > 10
                          ? 10
                          : incomeTransactions.length,
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
                          'Amount: \Rs.${transaction['amount'].toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editTransaction(true, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTransaction(true, index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              // Expense Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: <Widget>[
                      Icon(
                        Icons.arrow_downward, // Expenses icon
                        color: Colors.red,
                      ),
                      SizedBox(width: 2),
                      Text(
                        'Expenses ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _addTransaction(false),
                        child: const Text('Add Expense'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ExpensePage(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: screenHeight / 2 - 80,
                child: ListView.builder(
                  itemCount:
                      expenseTransactions.length > 10
                          ? 10
                          : expenseTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = expenseTransactions[index];
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
                          'Amount: \Rs.${transaction['amount'].toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editTransaction(false, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteTransaction(false, index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
