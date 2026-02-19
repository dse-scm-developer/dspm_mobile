import 'package:flutter/material.dart';
import '../../core/storage/app_session.dart';
import '/features/biz/service/biz_service.dart';

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

  String _userBu = "";
  
  final _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final userBu = await _loadUserBu();     // ✅ 먼저 BU 구함
      final vacTypes = await _loadVacTypes();


      if (!mounted) return;
      setState(() {
        _userBu = userBu;
        _vacTypeList = vacTypes;
        _vacTypeCd = vacTypes.isNotEmpty ? (vacTypes.first["CODE_CD"] ?? "").toString() : null;
        _vacTypeLoading = false;
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
    final buList = await AppSession.buList();
    if (buList.isEmpty) return "";

    final first = buList.first;
    if (first is Map) {
      return (first["CODE_NM"] ?? first["CODE_CD"] ?? "").toString();
    }
    return first.toString();
  }

  Future<List<Map<String, dynamic>>> _loadVacTypes() async {
    final list = await BizService.searchList(
      siq: "common.comCode", // 교체
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


  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
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
      firstDate: _startDate!, // ✅ 시작일 이전 선택 못함
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _calculateDays();
      });
    }
  }

  void _calculateDays() {
    if (_startDate != null && _endDate != null) {
      if (_vacTypeCd == "101") { // 휴가(대체근무)
        _days = 0;
        return;
      }

      if (_vacTypeCd == "104") { // 휴가(반차)
        _days = (_endDate!.difference(_startDate!).inDays + 1) * 0.5;
        return;
      }

      final diff = _endDate!.difference(_startDate!).inDays + 1;
      _days = diff > 0 ? diff.toDouble() : 0;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "휴가 신청",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E2A3B),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E2A3B)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                _buildLabel("구분"),
                const SizedBox(height: 8),
                _buildVacTypeDropdown(),

                const SizedBox(height: 20),

                _buildLabel("시작일"),
                const SizedBox(height: 8),
                _buildDateField(_startDate, () => _pickStartDate()),

                const SizedBox(height: 20),

                _buildLabel("종료일"),
                const SizedBox(height: 8),
                _buildDateField(_endDate, () => _pickEndDate()),

                const SizedBox(height: 20),

                _buildLabel("신청 일수"),
                const SizedBox(height: 8),
                _buildReadOnlyField("${_days.toStringAsFixed(1)} 일"),

                const SizedBox(height: 20),

                _buildLabel("신청 내용"),
                const SizedBox(height: 8),
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "신청 내용을 입력하세요",
                    filled: true,
                    fillColor: const Color(0xFFF6F8FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("휴가 신청이 완료되었습니다."),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F6BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "신청하기",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E2A3B),
      ),
    );
  }

  Widget _buildVacTypeDropdown() {
    if (_vacTypeLoading) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
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
          _calculateDays();   // ✅ 구분 바뀌면 재계산
        });
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }


  Widget _buildDateField(DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F8FB),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          date == null
              ? "날짜 선택"
              : "${date.year}-${date.month}-${date.day}",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF2F6BFF),
        ),
      ),
    );
  }
}
