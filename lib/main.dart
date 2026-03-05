import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'core/storage/app_session.dart';
import 'core/theme/app_theme.dart';
import '/ui/login_page.dart';
import '/ui/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  Future<bool> _autoLogin() async {
    final userId = await AppSession.userId();
    return userId != null && userId.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DSPM',
      theme: AppTheme.light,
      home: FutureBuilder<bool>(
        future: _autoLogin(),
        builder: (context, snapshot) {
          // 로딩 중
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 로그인 정보 있으면 홈
          if (snapshot.data!) {
            return const HomePage();
          }

          // 없으면 로그인
          return const LoginPage();
        },
      ),
      localizationsDelegates: const [
        MonthYearPickerLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'),
        Locale('en'),
      ],
    );
  }
}
