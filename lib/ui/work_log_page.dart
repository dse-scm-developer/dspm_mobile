import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';

import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '../../core/storage/app_session.dart';
import '../../core/theme/app_theme.dart'; // ✅ 추가

class _CellStyle {
  final bool editable;
  final Color background;
  final Color foreground;

  const _CellStyle({
    required this.editable,
    required this.background,
    required this.foreground,
  });
}

class WorkLogPage extends StatefulWidget {
  const WorkLogPage({super.key});

  @override
  State<WorkLogPage> createState() => _WorkLogPageState();
}

class _WorkLogPageState extends State<WorkLogPage> {
  String _employeeName = "";
  String _empId = "";

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month - 1);

  List<_WorkLogRow> _rows = [];

  List<Map<String, dynamic>> _workTypeRows = [];
  List<Map<String, dynamic>> _locationRows = [];
  List<Map<String, dynamic>> _projectRows = [];

  bool _loadingCodes = true;
  bool _loadingMonth = true;

  static const Set<String> _offWorkTypeCodes = {
    "100",
    "101",
    "102",
    "103",
    "104",
    "110",
  };

  @override
  void initState() {
    super.initState();
    _initSessionAndLoad();
  }

  @override
  void dispose() {
    _disposeRows(_rows);
    super.dispose();
  }

  void _disposeRows(List<_WorkLogRow> rows) {
    for (final r in rows) {
      r.remarkCtrl.dispose();
    }
  }

  Future<void> _initSessionAndLoad() async {
    final empId = await AppSession.userId();
    final empName = await AppSession.userNm();

    setState(() {
      _empId = empId ?? "";
      _employeeName = empName ?? "";
    });

    await _initCodesAndLoadMonth();
  }

  Future<void> _initCodesAndLoadMonth() async {
    await Future.wait([
      _initCodes(),
      _loadMonthRows(_month),
    ]);
  }

  Future<void> _initCodes() async {
    setState(() => _loadingCodes = true);
    final yearMonth = DateFormat("yyyyMM").format(_month);

    try {
      final result = await BizService.searchList(
        tranList: [
          TranData(
            siq: "common.comCode",
            outDs: "workTypeList",
            params: {"grpCd": "WORK_LOC_CODE"},
          ),
          TranData(
            siq: "common.comCode",
            outDs: "locationList",
            params: {"grpCd": "AREA_CODE"},
          ),
          TranData(
            siq: "common.projectDynamic",
            outDs: "projectList",
            params: {"userId": _empId, "yearMonth": yearMonth},
          ),
        ],
      );

      setState(() {
        _workTypeRows = (result["workTypeList"] ?? []).cast<Map<String, dynamic>>();
        _locationRows = (result["locationList"] ?? []).cast<Map<String, dynamic>>();
        _projectRows = (result["projectList"] ?? []).cast<Map<String, dynamic>>();
        _loadingCodes = false;
      });
    } catch (e) {
      setState(() => _loadingCodes = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("코드 조회 실패: $e")),
      );
    }
  }

  Future<void> _loadMonthRows(DateTime month) async {
    setState(() => _loadingMonth = true);

    final year = DateFormat("yyyy").format(month);
    final mm = DateFormat("MM").format(month);

    try {
      final result = await BizService.searchList(
        tranList: [
          TranData(
            siq: "master.workCal",
            outDs: "workLogList",
            params: {
              "empId": _empId,
              "year": year,
              "month": mm,
              "workCode": "",
            },
          ),
        ],
      );

      final list = (result["workLogList"] ?? []).cast<Map<String, dynamic>>();
      final newRows = list.map(_WorkLogRow.fromMap).toList();

      setState(() {
        _disposeRows(_rows);
        _rows = newRows;
        _loadingMonth = false;
      });
    } catch (e) {
      setState(() => _loadingMonth = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("월 근무일지 조회 실패: $e")),
      );
    }
  }

  Future<void> _pickMonth() async {
    FocusScope.of(context).unfocus();

    final picked = await showMonthYearPicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        final base = Theme.of(context);
        final mq = MediaQuery.of(context);

        return Theme(
          data: base.copyWith(
            colorScheme: base.colorScheme.copyWith(
              // ✅ 헤더 배경(연한색)
              primary: AppTheme.primary.withOpacity(0.12),
              // ✅ 헤더 텍스트
              onPrimary: AppTheme.ink,

              // ✅ 선택된 월 원형/강조색(진한 primary)
              secondary: AppTheme.primary,
              onSecondary: Colors.white,

              surface: Colors.white,
              onSurface: AppTheme.ink,
            ),
            dialogTheme: base.dialogTheme.copyWith(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          child: MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(0.94)),
            child: child!,
          ),
        );
      },
    );

    if (picked == null) return;

    setState(() => _month = DateTime(picked.year, picked.month, 1));
    await _loadMonthRows(_month);
  }
  List<DropdownMenuItem<String>> buildCodeItems(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    return rows.where((r) {
      final code = (r["CODE_CD"] ?? "").toString().trim();
      if (code.isEmpty) return false;
      if (seen.contains(code)) return false;
      seen.add(code);
      return true;
    }).map((r) {
      final code = (r["CODE_CD"] ?? "").toString().trim();
      final name = (r["CODE_NM"] ?? "").toString().trim();
      return DropdownMenuItem<String>(
        value: code,
        child: Text(name),
      );
    }).toList();
  }

  String? safeValue(String? current, List<Map<String, dynamic>> rows) {
    if (current == null || current.trim().isEmpty) return null;
    final v = current.trim();
    final exists = rows.any((r) => (r["CODE_CD"] ?? "").toString().trim() == v);
    return exists ? v : null;
  }

  String _dowTextFromDb(String? dayNm, DateTime date) {
    if (dayNm != null && dayNm.trim().isNotEmpty) return dayNm.trim();
    switch (date.weekday) {
      case DateTime.monday:
        return "MON";
      case DateTime.tuesday:
        return "TUE";
      case DateTime.wednesday:
        return "WED";
      case DateTime.thursday:
        return "THU";
      case DateTime.friday:
        return "FRI";
      case DateTime.saturday:
        return "SAT";
      case DateTime.sunday:
        return "SUN";
      default:
        return "";
    }
  }

  bool _isWorkAreaEditable(_WorkLogRow row) {
    final confirm = (row.confirmFlag ?? "").trim();
    if (confirm == 'Y') return false;

    final workCd = (row.workType).trim();
    return {"104", "106", "107", "108", "109"}.contains(workCd);
  }

  // ✅ 테이블용 색상: AppTheme 기반으로만 톤 정리
  _CellStyle _workTypeStyle(_WorkLogRow row) {
    const editBg = Color(0xFFFFF4C2); // 기존보다 덜 튀는 노랑(선택 영역 느낌)
    const red = Color(0xFFCC0000);
    const black = Colors.black;

    final noneEditBg = AppTheme.softBg; // ✅ 통일

    final confirm = (row.confirmFlag ?? "").trim();
    final vac = (row.vacFlag ?? "").trim();
    final workCd = row.workType.trim();
    final isRed = {"100", "101", "102", "103", "110"}.contains(workCd);

    if (vac == 'Y') {
      return _CellStyle(
        editable: false,
        background: noneEditBg,
        foreground: isRed ? red : black,
      );
    }

    if (confirm != 'Y') {
      if (isRed) {
        return const _CellStyle(editable: true, background: editBg, foreground: red);
      }
      if (workCd == "120") {
        return _CellStyle(editable: true, background: noneEditBg, foreground: black);
      }
      return const _CellStyle(editable: true, background: editBg, foreground: black);
    }

    return _CellStyle(
      editable: false,
      background: noneEditBg,
      foreground: isRed ? red : black,
    );
  }

  Future<void> _saveAll() async {
    FocusScope.of(context).unfocus();

    final rowList = _rows.map((r) => r.toSaveMap()).toList();

    if (rowList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("저장할 데이터가 없습니다.")),
      );
      return;
    }

    final rowData = [
      {
        "empId": rowList.first["EMP_ID"],
        "yearMonth": rowList.first["YEARMONTH"],
        "rowList": rowList,
        "state": "updated",
      }
    ];

    try {
      final cnt = await BizService.saveUpdate(
        siq: "master.workCal",
        outDs: "saveCnt",
        rows: rowData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 완료 ($cnt)")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("저장 실패: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat("yyyy-MM").format(_month);
    final isBusy = _loadingCodes || _loadingMonth;

    return Scaffold(
      // ✅ background/appBar는 ThemeData(app_theme.dart)로
      appBar: AppBar(
        title: const Text("근무일지"),
        actions: [
          IconButton(
            tooltip: "월 선택",
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: "저장",
            onPressed: isBusy ? null : _saveAll,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 상단 정보 바(Home 스타일)
            Container(
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
                    child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "사원명: $_employeeName",
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink),
                  ),
                  const Spacer(),
                  Text(
                    monthTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.ink),
                  ),
                  const SizedBox(width: 12),
                  if (isBusy)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    color: Colors.white,
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 980,
                        child: ListView.builder(
                          itemCount: _rows.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) return _buildHeaderRow();
                            final row = _rows[index - 1];
                            return _buildDataRow(row, index - 1);
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF3F9),
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: const Row(
        children: [
          _Cell(width: 110, child: _HeaderText("날짜")),
          _Cell(width: 70, child: _HeaderText("요일")),
          _Cell(width: 150, child: _HeaderText("근무 형태")),
          _Cell(width: 140, child: _HeaderText("근무 지역")),
          _Cell(width: 220, child: _HeaderText("프로젝트")),
          _Cell(width: 220, child: _HeaderText("비고")),
        ],
      ),
    );
  }

  Widget _buildDataRow(_WorkLogRow row, int i) {
    final confirmFlag = (row.confirmFlag ?? "").trim();
    final isConfirmed = confirmFlag == 'Y';
    final disableByLoading = _loadingCodes || _loadingMonth;

    final wtStyle = _workTypeStyle(row);
    final areaEditable = _isWorkAreaEditable(row);

    final rowLocked = disableByLoading || isConfirmed;

    final workTypeEditable = !rowLocked && wtStyle.editable;
    final workAreaEditable = !rowLocked && areaEditable;
    final projectEditable = !rowLocked;
    final remarkEditable = !rowLocked;

    final baseBg = i.isEven ? Colors.white : const Color(0xFFFBFCFF);

    const editBg = Color(0xFFFFF4C2);
    final noneEditBg = AppTheme.softBg;

    final areaBg = workAreaEditable ? editBg : noneEditBg;
    final projectBg = projectEditable ? editBg : noneEditBg;
    final remarkBg = remarkEditable ? editBg : noneEditBg;

    final dateStr = row.yyyymmdd ?? DateFormat("yyyy-MM-dd").format(row.date);
    final dow = _dowTextFromDb(row.dayNm, row.date);

    final workTypeItems = _loadingCodes ? const <DropdownMenuItem<String>>[] : buildCodeItems(_workTypeRows);
    final locationItems = _loadingCodes ? const <DropdownMenuItem<String>>[] : buildCodeItems(_locationRows);
    final projectItems = _loadingCodes ? const <DropdownMenuItem<String>>[] : buildCodeItems(_projectRows);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: baseBg,
        border: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          _Cell(
            width: 110,
            child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ),
          _Cell(
            width: 70,
            child: Text(dow, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
          ),

          _Cell(
            width: 150,
            background: wtStyle.background,
            child: IgnorePointer(
              ignoring: !workTypeEditable,
              child: Opacity(
                opacity: workTypeEditable ? 1.0 : 0.45,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _loadingCodes ? null : safeValue(row.workType, _workTypeRows),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: workTypeItems,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        row.workType = v;
                        if (_offWorkTypeCodes.contains(v)) {
                          row.workArea = "";
                          row.project = "";
                        }
                      });
                    },
                    style: TextStyle(
                      color: wtStyle.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),

          _Cell(
            width: 140,
            background: areaBg,
            child: IgnorePointer(
              ignoring: !workAreaEditable,
              child: Opacity(
                opacity: workAreaEditable ? 1.0 : 0.45,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _loadingCodes ? null : safeValue(row.workArea, _locationRows),
                    hint: const Text(""),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: locationItems,
                    onChanged: (v) => setState(() => row.workArea = v ?? ""),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                ),
              ),
            ),
          ),

          _Cell(
            width: 220,
            background: projectBg,
            child: IgnorePointer(
              ignoring: !projectEditable,
              child: Opacity(
                opacity: projectEditable ? 1.0 : 0.45,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _loadingCodes ? null : safeValue(row.project, _projectRows),
                    hint: const Text(""),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: projectItems,
                    onChanged: (v) => setState(() => row.project = v ?? ""),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                ),
              ),
            ),
          ),

          _Cell(
            width: 220,
            background: remarkBg,
            child: IgnorePointer(
              ignoring: !remarkEditable,
              child: Opacity(
                opacity: remarkEditable ? 1.0 : 0.45,
                child: TextField(
                  controller: row.remarkCtrl,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false, // ✅ softBg 차단
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    hintText: "",
                  ),
                  onChanged: (v) => row.remark = v,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderText extends StatelessWidget {
  final String text;
  const _HeaderText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: AppTheme.ink, // ✅ 통일
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;
  final Color? background;

  const _Cell({required this.width, required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: background),
      child: child,
    );
  }
}

class _WorkLogRow {
  final DateTime date;

  String? companyCd;
  String? buCd;
  String? empId;
  String? empNm;
  String? yearMonth;
  String? yyyymmdd;
  String? confirmFlag;
  String? dayNm;

  String workCd = "";
  String workType = "";
  String workArea = "";
  String project;

  String remark;
  String? vacFlag;

  final TextEditingController remarkCtrl;

  _WorkLogRow({
    required this.date,
    required this.workCd,
    required this.workType,
    required this.workArea,
    required this.project,
    required this.remark,
    this.companyCd,
    this.buCd,
    this.empId,
    this.empNm,
    this.yearMonth,
    this.yyyymmdd,
    this.confirmFlag,
    this.dayNm,
    this.vacFlag,
  }) : remarkCtrl = TextEditingController(text: remark);

  factory _WorkLogRow.fromMap(Map<String, dynamic> m) {
    final ymd = (m["YYYYMMDD"] ?? "").toString();
    DateTime parsed;
    try {
      parsed = DateTime.parse(ymd);
    } catch (_) {
      parsed = DateTime.now();
    }

    return _WorkLogRow(
      date: parsed,
      companyCd: (m["COMPANY_CD"] ?? "").toString(),
      buCd: (m["BU_CD"] ?? "").toString(),
      empId: (m["EMP_ID"] ?? "").toString(),
      empNm: (m["EMP_NM"] ?? "").toString(),
      yearMonth: (m["YEARMONTH"] ?? "").toString(),
      yyyymmdd: ymd,
      confirmFlag: (m["CONFIRM_FLAG"] ?? "").toString(),
      dayNm: (m["DAY_NM"] ?? "").toString(),
      workCd: (m["WORK_CD"] ?? "").toString(),
      workType: (m["WORK_TYPE"] ?? "").toString(),
      workArea: (m["WORK_AREA"] ?? "").toString(),
      project: (m["PROJECT_CD"] ?? "").toString(),
      remark: (m["REMARK"] ?? "").toString(),
      vacFlag: (m["VAC_FLAG"] ?? "").toString(),
    );
  }

  Map<String, dynamic> toSaveMap() => {
        "COMPANY_CD": companyCd ?? "",
        "BU_CD": buCd ?? "",
        "EMP_ID": empId ?? "",
        "EMP_NM": empNm ?? "",
        "YEARMONTH": yearMonth ?? "",
        "YYYYMMDD": yyyymmdd ?? DateFormat("yyyy-MM-dd").format(date),
        "WORK_TYPE": workType,
        "WORK_AREA": workArea,
        "PROJECT_CD": project,
        "REMARK": remark,
        "CONFIRM_FLAG": confirmFlag ?? "",
        "VAC_FLAG": vacFlag ?? "N",
      };
}