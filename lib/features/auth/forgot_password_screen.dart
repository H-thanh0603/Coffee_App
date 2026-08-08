import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.lock_reset, size: 72, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Nhập email đã đăng ký',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Chúng tôi sẽ gửi liên kết đặt lại mật khẩu vào email của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            if (_sent)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: const [
                  Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Liên kết khôi phục đã gửi (demo).'),
                  ),
                ]),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_emailCtrl.text.trim().isEmpty) return;
                  setState(() => _sent = true);
                },
                icon: const Icon(Icons.send_outlined),
                label: const Text('Gửi liên kết'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
