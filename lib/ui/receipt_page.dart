// receipt_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';

import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '../../core/storage/app_session.dart';
import 'project_detail_page.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _loading = true;
  List<Map<String, dynamic>> _projectList = []; // 프로젝트 리스트
  int _totalPrice = 0;
  final Map<String, int> _projectSum = {}; // 프로젝트별 총액

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _pickMonth() async {
    FocusScope.of(context).unfocus();

    final picked = await showMonthYearPicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(0.94)),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() => _month = DateTime(picked.year, picked.month, 1));
    await _loadMonthData();
  }

  // 월 별 데이터 조회
  Future<void> _loadMonthData() async {
    setState(() => _loading = true);

    try {
      await _loadProjectsForMonth();
      await _loadReceiptsAndSum();
    } catch (e) {
      debugPrint("ReceiptPage _loadMonthData error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 프로젝트별 금액 및 총액 계산
  Future<void> _loadReceiptsAndSum() async {
    final userId = (await AppSession.userId() ?? "").trim();
    final yearMonth = DateFormat("yyyyMM").format(_month);

    int tempTotal = 0;
    Map<String, int> tempProjectSum = {};

    // 각 프로젝트 별 금액 조회
    for (var project in _projectList) {
      final projectCd = (project["CODE_CD"] ?? "").toString();

      try {
        final list = await BizService.search(
          siq: "project.receiptMng",
          outDs: "rtnList",
          params: {
            "empId": userId,
            "userId": userId,
            "yearMonth": yearMonth,
            "project": projectCd,
            "expenseCode": "", // 전체 조회
            "_mtd": "getList",
          },
        );
        int projectTotal = 0;
        for (var item in list) {
          final p = (item["PROJECT_CD"] ?? "").toString();
          if (!p.toLowerCase().contains("total")) {
            final price = int.tryParse((item["PRICE"] ?? "0").toString()) ?? 0;
            projectTotal += price;
          }
        }

        tempProjectSum[projectCd] = projectTotal;
        tempTotal += projectTotal;
      } catch (e) {
        debugPrint("$projectCd 금액 로드 에러: $e");
        tempProjectSum[projectCd] = 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _projectSum.clear();
      _projectSum.addAll(tempProjectSum);
      _totalPrice = tempTotal;
    });
  }

  // 월 별 프로젝트 조회
  Future<void> _loadProjectsForMonth() async {
    final userId = (await AppSession.userId() ?? "").trim();
    final yearMonth = DateFormat("yyyyMM").format(_month);

    final result = await BizService.searchList(
      tranList: [
        TranData(
          siq: "common.projectDynamic",
          outDs: "projectList",
          params: {
            "userId": userId,
            "yearMonth": yearMonth,
          },
        ),
      ],
    );
    final list = (result["projectList"] ?? []).cast<Map<String, dynamic>>();

    if (!mounted) return;
    setState(() => _projectList = list);
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat("yyyy-MM").format(_month);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "경비 신청",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2A3B),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E2A3B)),
        actions: [
          IconButton(
            tooltip: "월 선택",
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(monthTitle),
            const SizedBox(height: 12),
            _buildTotalCard(),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _projectList.isEmpty
                  ? const Center(child: Text("해당 월에 진행 중인 프로젝트가 없습니다."))
                  : ListView.builder(
                padding: const EdgeInsets.only(top: 4),
                itemCount: _projectList.length,
                itemBuilder: (context, index) {
                  final p = _projectList[index];

                  final projectCd = (p["CODE_CD"] ?? "").toString();
                  final projectNm = (p["CODE_NM"] ?? "").toString().trim().isEmpty
                      ? "프로젝트명 없음"
                      : (p["CODE_NM"] ?? "").toString();

                  final price = _projectSum[projectCd] ?? 0;

                  return _ProjectCard(
                    projectCd: projectCd,
                    projectNm: projectNm,
                    price: price,
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailPage(
                            projectCd: projectCd,
                            projectNm: projectNm,
                            yearMonth: DateFormat("yyyyMM").format(_month),
                          ),
                        ),
                      );
                      await _loadMonthData();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(String monthTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: Color(0xFF2F6BFF)),
          const SizedBox(width: 8),
          const Text(
            "월별 프로젝트 경비",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A3B),
            ),
          ),
          const Spacer(),
          Text(
            monthTitle,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A3B),
            ),
          ),
          const SizedBox(width: 12),
          if (_loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final mm = DateFormat("MM").format(_month);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE6EDF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6BFF).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF2F6BFF),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$mm월 경비 총액",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2A3B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${NumberFormat('#,###').format(_totalPrice)}원",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2F6BFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final String projectCd;
  final String projectNm;
  final int price;
  final VoidCallback onTap;

  const _ProjectCard({
    required this.projectCd,
    required this.projectNm,
    required this.price,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EDF6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          projectNm,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
        ),
        trailing: Text(
          "${NumberFormat('#,###').format(price)}원",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        onTap: onTap,
      ),
    );
  }
}