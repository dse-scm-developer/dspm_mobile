import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '/core/config/env.dart';
import '/features/auth/controller/auth_controller.dart';
import '../../../core/network/session_dio.dart'; 
import '../../core/storage/app_session.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  bool _isLoading = false; 
  bool _obscure = true;

  @override
  void initState() {
    super.initState();

    _linkSub = _appLinks.uriLinkStream.listen((uri) async {
      if (uri.scheme == 'dspm' && uri.host == 'login' && uri.path == '/success') {
        final code = uri.queryParameters['code'];
        if (code == null || code.isEmpty) return;

        try {
          setState(() => _isLoading = true);

          final res = await SessionDio.dio.post('/th/mobile/oauthLogin', data: {'code': code});
          final data = res.data;

          if (data['success'] != true) {
            throw Exception((data['message'] ?? '로그인 실패').toString());
          }

          await AppSession.save(
            userId: data["userId"].toString(),
            userNm: data["userNm"].toString(),
            langCd: data["langCd"].toString(),
            companyList: data["companyList"] ?? [],
            buList: data["buList"] ?? [],
          );

          if (!mounted) return;
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
        } catch (e) {
          if (!mounted) return;
          //debugPrint("DSPMERROR: ${e.toString()}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxCardWidth = width < 420 ? width : 420.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxCardWidth),
            child: _buildCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          const Text(
            'Sign In',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A3B),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'DS-eTrade Project Management System',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 18),

          // Social buttons
          SizedBox(
            height: 44,
            child: InkWell(
              onTap: _isLoading
              ? null
              : () async {
                  setState(() => _isLoading = true);
                  try {
                    final url = Uri.parse('${Env.baseUrl}/th/mobile/oauth2/authorization/azure');
                    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
                    if (!ok) {
                      throw Exception('브라우저를 열 수 없습니다.');
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
                    );
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE6EDF6)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.account_circle_outlined,
                        size: 20, color: Color(0xFF2F6BFF)),
                    SizedBox(width: 8),
                    Text(
                      'Microsoft 계정으로 로그인하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF34485E),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          _OrDivider(),
          const SizedBox(height: 14),

          // Email
          _InputField(
            controller: _userIdController,
            hintText: '사원번호',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
          ),
          const SizedBox(height: 12),

          // Password
          _InputField(
            controller: _passwordController,
            hintText: '비밀번호',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscure,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF8AA0B6),
              ),
            ),
          ),

          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                foregroundColor: const Color(0xFF2F6BFF),
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                try {
                  await AuthController.login(
                    userId: _userIdController.text,
                    userPw: _passwordController.text,
                  );

                  if (!context.mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomePage()),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6BFF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Log In',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EDF6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF2F6BFF)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF34485E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: const Color(0xFFE6EDF6), thickness: 1)),
        const SizedBox(width: 10),
        Text(
          'Or',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.black.withOpacity(0.45),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: const Color(0xFFE6EDF6), thickness: 1)),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.35), fontWeight: FontWeight.w600),
        prefixIcon: Icon(prefixIcon, color: const Color(0xFF8AA0B6)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF6F8FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2F6BFF), width: 1.2),
        ),
      ),
    );
  }
}
