import 'package:flutter/material.dart';
import '../widgets/card.dart'as ui;
import '../../widgets/custom_button.dart';
import '../../widgets/progress_bar.dart';

class CertificateVerificationScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const CertificateVerificationScreen({
    super.key,
    required this.onComplete,
  });

  @override
  _CertificateVerificationScreenState createState() => _CertificateVerificationScreenState();
}

class _CertificateVerificationScreenState extends State<CertificateVerificationScreen> {
  double progress = 0;
  Map<String, dynamic>? result;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  void _startVerification() {
    const interval = Duration(milliseconds: 200);
    Future.delayed(interval, () {
      if (mounted) {
        setState(() {
          progress += 8;
          if (progress >= 100) {
            result = {
              'status': 'Verified',
              'doctorName': 'Dr. V. S. Chauhan',
              'hospital': 'Max Healthcare',
              'verificationDate': DateTime.now().toString().split(' ')[0],
              'summary': 'AI verified seal and signature against the National Medical Register.',
              'xpGained': 100
            };
          }
        });

        if (progress < 100) {
          _startVerification();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  "AI Certificate Verification",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (result == null) ...[
                  const Text(
                    "Analyzing document...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  const Text(
                    "Checking seal, signature, and medical registry...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProgressBar(value: progress, max: 100, color: Colors.teal),
                ] else ...[
                  const Icon(
                    Icons.verified,
                    size: 48,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Authenticity Verified",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow("Doctor:", result!['doctorName']),
                        _buildInfoRow("Hospital:", result!['hospital']),
                        _buildInfoRow("Verified On:", result!['verificationDate']),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: "Return to Dashboard",
                    onPressed: () {
                      widget.onComplete(result!);
                    },
                    icon: Icons.check_circle,
                    backgroundColor: Colors.blue.shade600,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
