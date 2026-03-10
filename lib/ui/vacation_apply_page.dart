import 'package:flutter/material.dart';
import '../../core/storage/app_session.dart';
import '../../core/theme/app_theme.dart';
import '/features/biz/service/biz_service.dart';

class VacationApplyPage extends StatefulWidget {
  const VacationApplyPage({super.key});

  @override
  State<VacationApplyPage> createState() => _VacationApplyPageState();
}

class _VacationApplyPageState extends State<VacationApplyPage> {
  List<Map<String, dynamic>> _applyList = [];
  bool _isLoading = true;

  late String _selectedYear;
  late final List<String> _years;

  @override
  void initState() {
    super.initState();

    final nowYear = DateTime.now().year;
    _years = [
      nowYear.toString(),
      (nowYear - 1).toString(),
    ];

    _selectedYear = _years.first;
    _loadVacationHistory();
  }

  Future<void> _loadVacationHistory() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final userId = (await AppSession.userId()) ?? "";
      final company = await AppSession.company();
      final bu = await AppSession.bu();

      final list = await BizService.search(
        siq: "master.vacationDtl",
        outDs: "rtnList",
        params: {
          "SEARCH_USER_ID": userId,
          "GV_COMPANY_CD": company,
          "GV_BU_CD": bu,
          "year": _selectedYear,
          "empId": userId,
          "_mtd": "getList",
        },
      );

      if (!mounted) return;

      setState(() {
        _applyList = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("휴가 내역 조회 실패: $e");

      if (!mounted) return;

      setState(() {
        _applyList = [];
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("휴가 내역을 불러오지 못했습니다.")),
      );
    }
  }

  String _formatDate(String raw) {
    if (raw.trim().isEmpty) return "-";

    try {
      final normalized = raw.replaceAll('.', '-').replaceAll('/', '-');
      final date = DateTime.parse(normalized);

      final y = date.year.toString();
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');

      return "$y.$m.$d";
    } catch (_) {
      return raw;
    }
  }

  String _buildPeriodText(String start, String end) {
    final s = _formatDate(start);
    final e = _formatDate(end);
    return "$s ~ $e";
  }

  // 소수점 있을때만 소수점 표시
  String _formatDays(dynamic value) {
    final raw = (value ?? "").toString().trim();
    if (raw.isEmpty) return "0";

    final number = double.tryParse(raw);
    if (number == null) return raw;

    if (number == number.truncateToDouble()) {
      return number.toInt().toString();
    }
    return number.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("휴가 내역"),
      ),
      body: Column(
        children: [
          _buildTopSection(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _applyList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
              onRefresh: _loadVacationHistory,
              color: AppTheme.primary,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: _applyList.length,
                itemBuilder: (context, index) {
                  return _buildHistoryRow(_applyList[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _years.map((year) {
              final isSelected = _selectedYear == year;

              return ChoiceChip(
                label: Text("$year년"),
                selected: isSelected,
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() => _selectedYear = year);
                  _loadVacationHistory();
                },
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.softBg,
                showCheckmark: false,
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.ink,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            "$_selectedYear년 신청 내역",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "총 ${_applyList.length}건",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.ink.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 56,
              color: AppTheme.ink.withOpacity(0.12),
            ),
            const SizedBox(height: 14),
            Text(
              "$_selectedYear년 휴가 신청 내역이 없어요",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink.withOpacity(0.62),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "다른 연도를 선택해서 확인해보세요.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.ink.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> item) {
    final start = (item["VACATION_START_DATE"] ?? "").toString();
    final end = (item["VACATION_END_DATE"] ?? "").toString();
    final type = (item["VACATION_DIVISION_NM"] ?? "휴가").toString();
    final days = _formatDays(item["VACATION_USE"]);
    final desc = (item["VACATION_DESC"] ?? "").toString().trim();

    final periodText = _buildPeriodText(start, end);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 날짜 + 일수
          Row(
            children: [
              Text(
                periodText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.ink,
                  height: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                "$days일",
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 휴가구분 + 사유
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.softBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink.withOpacity(0.55),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}