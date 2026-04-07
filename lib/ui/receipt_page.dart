// receipt_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '../../core/storage/app_session.dart';
import 'project_detail_page.dart';
import '../../core/theme/app_theme.dart'; 

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key});

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month - 1);

  bool _loading = true;
  List<Map<String, dynamic>> _projectList = []; // 프로젝트 리스트
  int _totalPrice = 0;
  final Map<String, int> _projectSum = {}; // 프로젝트별 총액
  bool _isWorkConfirmed = false;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _pickMonth() async {
    FocusScope.of(context).unfocus();

    final picked = await AppTheme.pickMonthYear(
      context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      // textScale: 0.94, // 기본값이 0.94면 생략 가능
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
        // 근무일지 확정 여부
        TranData(
          siq: "master.workCalConfirm",
          outDs: "rtnList2",
          params: {
            "yearMonth": yearMonth,
            "empId": userId,
          },
        ),
      ],
    );
    final list = (result["projectList"] ?? []).cast<Map<String, dynamic>>();
    final confirmRows = (result["rtnList2"] ?? []).cast<Map<String, dynamic>>(); // 근무일지 확정 여부

    if (!mounted) return;
    setState(() {
      _projectList = list;

      // 근무일지 확정 여부
      if (confirmRows.isNotEmpty) {
        _isWorkConfirmed =
            (int.tryParse(confirmRows[0]["CNT"].toString()) ?? 0) > 0;
      } else {
        _isWorkConfirmed = false;
      }
    });
  }

  Future<void> _confirmAll() async {
    if (!_isWorkConfirmed) {
      _showMsg("해당 월의 근무일지가 확정되지 않았습니다.\n근무일지 먼저 작성 후 확정해주세요.");
      return;
    }
    final userId = (await AppSession.userId() ?? "").trim();
    final yearMonth = DateFormat("yyyyMM").format(_month);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('확정'),
        content: const Text('경비를 확정하시겠습니까?\n확정 후 수정이 제한될 수 있습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확정'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      // 최신 일비 조회
      final dayPayRows = await BizService.search(
        siq: "project.calDayPay",
        outDs: "rtnList3",
        params: {
          "empId": userId,
          "userId": userId,
          "yearMonth": yearMonth,
          "loadFlag": "Y",
          "_mtd": "getList",
        },
      );

      if (dayPayRows.isEmpty) {
        if (!mounted) return;
        _showMsg("최신 일비 계산에 실패했습니다.");
        return;
      }

      final latestDayPay =
          int.tryParse((dayPayRows.first["DAY_PAY"] ?? "0").toString()) ?? 0;

      // 월 전체 상세내역 조회
      final detailRows = await BizService.search(
        siq: "project.receiptMng",
        outDs: "rtnList",
        params: {
          "empId": userId,
          "userId": userId,
          "yearMonth": yearMonth,
          "expenseCode": "",
          "_mtd": "getList",
        },
      );

      // 일비 최신값으로 변경
      final saveRows = <Map<String, dynamic>>[];

      for (final item in detailRows) {
        final row = Map<String, dynamic>.from(item);
        final projectCd = (row["PROJECT_CD"] ?? "").toString();
        final expCd = (row["EXP_CD"] ?? "").toString();

        if (projectCd == "Total" || projectCd == "Sub Total") continue;

        if (expCd == "251") {
          row["PRICE"] = latestDayPay;
          row["USER_ID"] = userId;
          row["GV_USER_ID"] = userId;
          row["state"] = "updated";
          saveRows.add(row);
        }
      }

      if (saveRows.isNotEmpty) {
        await BizService.save(
          siq: "project.receiptMng",
          outDs: "saveCnt",
          rows: saveRows,
          extraParams: {
            "_mtd": "saveAll",
            "sql": "N",
            "gvTotal": "Total",
            "gvSubTotal": "Sub Total",
          },
        );
      }

      final confirmRows = [
        {
          "userId": userId,
          "confirm_yn": "Y",
          "YEARMONTH": yearMonth,
          "state": "updated",
        }
      ];

      await BizService.saveUpdate(
        siq: "project.receiptConfirm",
        outDs: "saveCnt",
        rows: confirmRows,
      );

      if (!mounted) return;

      await _loadMonthData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("확정되었습니다.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("확정 실패: $e")));
    }
  }

  void _showMsg(String msg) {
    final double bottomMargin = MediaQuery.of(context).size.height * 0.1;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: bottomMargin,
          left: 20,
          right: 20,
        ),
        duration: const Duration(milliseconds: 1000),
      ),
    );
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
          // IconButton(
          //   tooltip: "월 선택",
          //   onPressed: _pickMonth,
          //   icon: const Icon(Icons.calendar_month_outlined),
          // ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'confirm') {
                await _confirmAll();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'confirm',
                child: Text('확정'),
              ),
            ],
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
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "월별 프로젝트 경비",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.ink,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Text(
                  monthTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: _loading ? null : _pickMonth,
                  borderRadius: BorderRadius.circular(8),
                  child: Icon(
                    Icons.calendar_month_outlined,
                    size: 18,
                    color: _loading ? Colors.grey : AppTheme.primary,
                  ),
                ),
              ],
            ),
          )
        ]
      )
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        trailing: Text(
          "${NumberFormat('#,###').format(price)}원",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        onTap: onTap,
      ),
    );
  }
}