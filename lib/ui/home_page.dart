import 'package:flutter/material.dart';
import '../../core/storage/app_session.dart';
import 'vacation_page.dart';
import 'work_log_page.dart';

class HomePage extends StatefulWidget  {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userNm = "";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final name = await AppSession.userNm();
    debugPrint("DSPMERROR: ${name}");
    setState(() {
      _userNm = name ?? "";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "DSPM",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2A3B),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E2A3B)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            /// ✅ 여기 이름 추가
            Text(
              _userNm.isNotEmpty
                  ? "안녕하세요, ${_userNm}님 👋"
                  : "안녕하세요 👋",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2A3B),
              ),
            ),

            const SizedBox(height: 4),
            const Text(
              "오늘도 좋은 하루 보내세요.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.05,
                children: [
                  _HomeCard(
                    icon: Icons.beach_access_rounded,
                    title: "휴가 신청",
                    color: const Color(0xFF2F6BFF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VacationPage(),
                        ),
                      );
                    },
                  ),
                  _HomeCard(
                    icon: Icons.edit_note_rounded,
                    title: "근무일지 작성",
                    color: const Color(0xFF00BFA6),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WorkLogPage(),
                        ),
                      );
                    },
                  ),
                  _HomeCard(
                    icon: Icons.payments_outlined,
                    title: "경비 신청",
                    color: const Color(0xFFFF9800),
                    onTap: () {},
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

class _HomeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _HomeCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 25,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: color,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2A3B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
