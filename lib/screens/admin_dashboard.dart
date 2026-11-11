import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/card.dart'as ui;
import '../widgets/custom_button.dart';
import '../models/admin_submissions.dart';

class AdminDashboard extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminDashboard({super.key, required this.onLogout});

  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<Map<String, dynamic>> submissions = List.from(MockAdminSubmissions.submissions);
  Map<String, dynamic>? selectedSubmission;
  String filter = 'All';
  String searchQuery = '';

  void handleAction(int id, String newStatus) {
    setState(() {
      submissions = submissions.map((s) {
        if (s['id'] == id) {
          return {...s, 'status': newStatus};
        }
        return s;
      }).toList();
      selectedSubmission = null;
    });
  }

  Map<String, int> get statusCounts {
    final counts = <String, int>{};
    for (final submission in submissions) {
      final status = submission['status'];
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get filteredSubmissions {
    return submissions.where((s) {
      final matchesFilter = filter == 'All' || s['status'] == filter;
      final matchesSearch = s['athleteName'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  Map<String, int> get submissionCountsByDate {
    final counts = <String, int>{};
    for (final submission in submissions) {
      final date = submission['date'];
      counts[date] = (counts[date] ?? 0) + 1;
    }
    return counts;
  }

  List<Map<String, dynamic>> get chartData {
    final List<Map<String, dynamic>> data = [];
    submissionCountsByDate.forEach((date, count) {
      data.add({'date': date, 'submissions': count});
    });
    data.sort((a, b) => a['date'].compareTo(b['date']));
    return data;
  }

  @override
  Widget build(BuildContext context) {
    if (selectedSubmission != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: ui.Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Review Submission",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.play_circle,
                        size: 48,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Athlete: ${selectedSubmission!['athleteName']}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "Exercise: ${selectedSubmission!['exercise']}",
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red, size: 14),
                            SizedBox(width: 4),
                            Text(
                              "AI Flag",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Incomplete Range of Motion on last 3 reps.",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (selectedSubmission!['status'] == 'Pending') ...[
                    CustomButton(
                      text: "Approve",
                      onPressed: () {
                        handleAction(selectedSubmission!['id'], 'Approved');
                      },
                      icon: Icons.check_circle,
                      backgroundColor: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      text: "Reject",
                      onPressed: () {
                        handleAction(selectedSubmission!['id'], 'Rejected');
                      },
                      icon: Icons.cancel,
                      backgroundColor: Colors.red,
                    ),
                    const SizedBox(height: 12),
                  ],
                  CustomButton(
                    text: "Back to List",
                    onPressed: () {
                      setState(() {
                        selectedSubmission = null;
                      });
                    },
                    backgroundColor: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Admin Dashboard",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: widget.onLogout,
                  child: const Text(
                    "Logout",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Stats Cards
            Row(
              children: [
                Expanded(
                  child: ui.Card(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const Text(
                          "Total",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          "${submissions.length}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ui.Card(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const Text(
                          "Pending",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          "${statusCounts['Pending'] ?? 0}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.yellow,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ui.Card(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const Text(
                          "Approved",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          "${statusCounts['Approved'] ?? 0}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ui.Card(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const Text(
                          "Rejected",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          "${statusCounts['Rejected'] ?? 0}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Daily Submissions Chart
            Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daily Submissions",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 150,
                    child: BarChart(
                      BarChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < chartData.length) {
                                  return Text(
                                    chartData[index]['date'],
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: chartData.map((data) {
                          return BarChartGroupData(
                            x: chartData.indexOf(data),
                            barRods: [
                              BarChartRodData(
                                toY: data['submissions'].toDouble(),
                                color: Colors.cyan,
                                width: 20,
                                borderRadius: BorderRadius.zero,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Submissions Queue
            Expanded(
              child: ui.Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Submissions Queue",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search athlete...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.cyan),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    // Filter Buttons
                    Row(
                      children: ['All', 'Pending', 'Approved', 'Rejected'].map((status) {
                        final isSelected = filter == status;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  filter = status;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSelected ? Colors.cyan : Colors.white.withOpacity(0.1),
                                foregroundColor: isSelected ? Colors.white : Colors.grey,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Submissions List
                    Expanded(
                      child: filteredSubmissions.isEmpty
                          ? const Center(
                              child: Text(
                                "No submissions found.",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.separated(
                              separatorBuilder: (context, index) => const Divider(
                                color: Colors.white10,
                                height: 1,
                              ),
                              itemCount: filteredSubmissions.length,
                              itemBuilder: (context, index) {
                                final submission = filteredSubmissions[index];
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedSubmission = submission;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                submission['athleteName'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                submission['exercise'],
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              submission['date'],
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: _getStatusColor(submission['status']).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                submission['status'],
                                                style: TextStyle(
                                                  color: _getStatusColor(submission['status']),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        CustomButton(
                                          text: submission['status'] == 'Pending' ? "Review" : "View",
                                          onPressed: () {
                                            setState(() {
                                              selectedSubmission = submission;
                                            });
                                          },
                                          icon: Icons.visibility,
                                          backgroundColor: Colors.blue.shade600,
                                          width: 80,
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
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}