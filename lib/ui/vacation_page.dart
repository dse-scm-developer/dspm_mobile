import 'package:flutter/material.dart';
import '../../core/storage/app_session.dart';
import '/features/biz/service/biz_service.dart';
import '../../core/theme/app_theme.dart';

class VacationPage extends StatefulWidget {
  const VacationPage({super.key});

  @override
  State<VacationPage> createState() => _VacationPageState();
}

class _VacationPageState extends State<VacationPage> {
  List<Map<String, dynamic>> _vacTypeList = [];
  String? _vacTypeCd;
  bool _vacTypeLoading = true;

  DateTime? _startDate;
  DateTime? _endDate;
  double _days = 0;
  double _remainDays = 0;

  String _startDateStr = "";
  String _endDateStr = "";

  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _loadUserBu(); // ✅ 먼저 BU 구함 (현재 값은 사용 안하지만 유지)
      final vacTypes = await _loadVacTypes();
      final remainDays = await _loadRemainDays();

      if (!mounted) return;
      setState(() {
        _vacTypeList = vacTypes;
        _vacTypeCd = vacTypes.isNotEmpty ? (vacTypes.first["CODE_CD"] ?? "").toString() : null;
        _vacTypeLoading = false;
        _remainDays = remainDays;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _vacTypeLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst("Exception: ", ""))),
      );
    }
  }

  Future<String> _loadUserBu() async {
    return await AppSession.bu();
  }

  Future<List<Map<String, dynamic>>> _loadVacTypes() async {
    final list = await BizService.search(
      siq: "common.comCode",
      outDs: "vacTypeList",
      params: {
        "grpCd": "WORK_LOC_CODE",
        "buCd": "ALL",
      },
    );

    final filtered = list.where((m) {
      return (m["ATTB_3_CD"] ?? "").toString() == "Y";
    }).toList();

    filtered.sort((a, b) {
      final sa = int.tryParse((a["SORT"] ?? "0").toString()) ?? 0;
      final sb = int.tryParse((b["SORT"] ?? "0").toString()) ?? 0;
      return sa.compareTo(sb);
    });

    return filtered;
  }

  Future<double> _loadRemainDays() async {
    final userId = (await AppSession.userId()) ?? "";
    final company = await AppSession.company();
    final bu = await AppSession.bu();

    final list = await BizService.search(
      siq: "master.vacationHdr",
      outDs: "remainDs",
      params: {
        "GV_USER_ID": userId,
        "GV_COMPANY_CD": company,
        "GV_BU_CD": bu,
        "year": DateTime.now().year.toString(),
        "empId": userId,
      },
    );

    final first = list.isNotEmpty ? list.first : {};
    final v = first["VACATION_REMAIN"];
    return double.tryParse((v ?? "0").toString()) ?? 0;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      // ✅ 다이얼로그에도 AppTheme 톤 반영
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppTheme.ink,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateStr =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _calculateDays();
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("먼저 시작일을 선택하세요.")),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.primary,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppTheme.ink,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateStr =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
        _calculateDays();
      });
    }
  }

  void _calculateDays() {
    if (_startDate != null && _endDate != null) {
      if (_vacTypeCd == "101") {
        _days = 0;
        return;
      }

      if (_vacTypeCd == "104") {
        _days = (_endDate!.difference(_startDate!).inDays + 1) * 0.5;
        return;
      }

      final diff = _endDate!.difference(_startDate!).inDays + 1;
      _days = diff > 0 ? diff.toDouble() : 0;
    }
  }

  bool _validateBeforeSubmit() {
    if (_startDate == null) {
      _showMsg('시작일을 선택해 주세요.');
      return false;
    }

    if (_endDate == null) {
      _showMsg('종료일을 선택해 주세요.');
      return false;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showMsg('종료일은 시작일보다 빠를 수 없습니다.');
      return false;
    }

    if (_days > _remainDays) {
      _showMsg('잔여 휴가일수를 초과했습니다.\n잔여: $_remainDays일, 신청: $_days일');
      return false;
    }

    if (_days > 5) {
      _showMsg('휴가 신청 일수는 5일을 초과할 수 없습니다.\n초과되는 일수는 행을 추가해서 작성해주세요.');
      return false;
    }

    return true;
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width < 520
        ? double.infinity
        : 520.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("휴가 신청"),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _buildFormCard(context),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
  
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 18),

          _buildLabel("구분"),
          const SizedBox(height: 8),
          _buildVacTypeDropdown(),

          const SizedBox(height: 18),

          _buildLabel("시작일"),
          const SizedBox(height: 8),
          _buildDateField(_startDate, () => _pickStartDate()),

          const SizedBox(height: 18),

          _buildLabel("종료일"),
          const SizedBox(height: 8),
          _buildDateField(_endDate, () => _pickEndDate()),

          const SizedBox(height: 18),

          _buildLabel("신청 일수"),
          const SizedBox(height: 8),
          _buildReadOnlyField("${_days.toStringAsFixed(1)} 일"),

          const SizedBox(height: 18),

          _buildLabel("신청 내용"),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: "신청 내용을 입력하세요",
            ),
          ),

          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _vacTypeLoading
                  ? null
                  : () async {
                      if (!_validateBeforeSubmit()) return;

                      final userId = (await AppSession.userId()).toString();
                      final companyCd = await AppSession.company();
                      final buCd = await AppSession.bu();

                      final res = await BizService.saveVacation(
                        siq: "master.vacationDtl",
                        outDs: "saveCnt",
                        rows: [
                          {
                            "state": "inserted",
                            "COMPANY_CD": companyCd,
                            "BU_CD": buCd,
                            "USER_ID": userId,
                            "VACATION_START_DATE": _startDateStr,
                            "VACATION_END_DATE": _endDateStr,
                            "VACATION_DIVISION": _vacTypeCd,
                            "VACATION_USE": _days,
                            "VACATION_DESC": _contentController.text,
                          }
                        ],
                        extraParams: const {},
                      );

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text((res['message'] ?? '').toString())),
                      );
                    },
              child: const Text("신청하기"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    // ✅ 상단 상태(잔여 휴가) 배지 느낌으로 추가 — 톤은 Home 스타일
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.softBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.beach_access_rounded, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "휴가 신청서",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
          ),
          Text(
            "잔여 ${_remainDays.toStringAsFixed(1)}일",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        color: AppTheme.ink,
      ),
    );
  }

  Widget _buildVacTypeDropdown() {
    if (_vacTypeLoading) {
      return const SizedBox(
        height: 52, // TextField 기본 높이와 맞춤
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _vacTypeCd,
      items: _vacTypeList.map((m) {
        final cd = (m["CODE_CD"] ?? "").toString();
        final nm = (m["CODE_NM"] ?? "").toString();
        return DropdownMenuItem<String>(
          value: cd,
          child: Text(nm),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _vacTypeCd = value;
          _calculateDays();
        });
      },
      decoration: const InputDecoration(
        hintText: "구분 선택",
        prefixIcon: Icon(Icons.category_outlined), // 선택사항
      ),
    );
  }

  Widget _buildDateField(DateTime? date, VoidCallback onTap) {
    final text = date == null
        ? ""
        : "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final controller = TextEditingController(text: text);

    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: const InputDecoration(
        hintText: "날짜 선택",
        prefixIcon: Icon(Icons.calendar_month_outlined),
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    final controller = TextEditingController(text: value);
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: const InputDecoration(
        // hintText 필요 없으면 생략 가능
        prefixIcon: Icon(Icons.timelapse_rounded), // 아이콘 싫으면 제거
      ),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: AppTheme.primary,
      ),
    );
  }
}