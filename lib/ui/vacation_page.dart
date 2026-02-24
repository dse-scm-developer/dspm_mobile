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
      final userBu = await _loadUserBu();     // ✅ 먼저 BU 구함
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
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateStr = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
        _endDateStr = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
                    onPressed: () async {
                      if (!_validateBeforeSubmit()) return;

                      final _userId = (await AppSession.userId()).toString();
                      final _companyCd = await AppSession.company();
                      final _buCd = await AppSession.bu();
                      final res = await BizService.saveVacation(
                        siq: "master.vacationDtl",     // ✅ 메일 데이터 조회용 siq (서버에서 sqlId로 사용)
                        outDs: "saveCnt",
                        rows: [
                          {
                            "state": "inserted",
                            "COMPANY_CD": _companyCd,
                            "BU_CD": _buCd,
                            "USER_ID": _userId,
                            "VACATION_START_DATE": _startDateStr,
                            "VACATION_END_DATE": _endDateStr,
                            "VACATION_DIVISION": _vacTypeCd,
                            "VACATION_USE": _days,
                            "VACATION_DESC": _contentController.text,
                          }
                        ],
                        extraParams: {
                        },
                      );
                      debugPrint("DSPMERROR: ${_userId}");
                      debugPrint("DSPMERROR: ${res}");
                      if (res['success'] == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'])),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(res['message'])),
                        );
                      }
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
