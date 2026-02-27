import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import '/core/config/env.dart';
import '/features/auth/controller/auth_controller.dart';
import '../../../core/network/session_dio.dart';
import '../../core/storage/app_session.dart';
import '../../core/theme/app_theme.dart';
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
          Text(
            'Sign In',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
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

          // Microsoft OAuth
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
                        if (!ok) throw Exception('브라우저를 열 수 없습니다.');
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
                        );
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.softBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.account_circle_outlined, size: 20, color: AppTheme.primary),
                    SizedBox(width: 8),
                    Text(
                      'Microsoft 계정으로 로그인하기',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),
          const _OrDivider(),
          const SizedBox(height: 14),

          _InputField(
            controller: _userIdController,
            hintText: '사원번호',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
          ),
          const SizedBox(height: 12),

          _InputField(
            controller: _passwordController,
            hintText: '비밀번호',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscure,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            ),
          ),

          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              child: const Text('Forgot Password?'),
            ),
          ),

          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
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
              child: const Text('Log In'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
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
        const Expanded(child: Divider()),
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
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffix,
      ),
    );
  }
}