import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';
import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '../../core/storage/app_session.dart';

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

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month - 1,);

  List<_WorkLogRow> _rows = [];

  List<Map<String, dynamic>> _workTypeRows = [];
  List<Map<String, dynamic>> _locationRows = [];
  List<Map<String, dynamic>> _projectRows = [];

  bool _loadingCodes = true;
  bool _loadingMonth = true;

  // WORK_LOC_CODE 기준: 휴일/휴가/반차 등 "쉬는 날"
  static const Set<String> _offWorkTypeCodes = {
    "100", // 휴일
    "101", // 휴가(대체근무)
    "102", // 휴가(연차)
    "103", // 휴가(경조사)
    "104", // 반차
    "110", // 휴가(기타)
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
    // 코드 + 월조회 같이 돌려도 되는데, 여기선 순서가 중요하진 않음
    await Future.wait([
      _initCodes(),
      _loadMonthRows(_month),
    ]);
  }

  /// ✅ 공통코드/프로젝트 멀티 조회
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("코드 조회 실패: $e")),
        );
      }
    }
  }

  /// ✅ 월 선택 시 서버에서 rows 그대로 조회해서 바인딩 (휴일/공휴일 자동 채워진 데이터)
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

      // 기존 컨트롤러 dispose 후 교체
      setState(() {
        _disposeRows(_rows);
        _rows = newRows;
        _loadingMonth = false;
      });
    } catch (e) {
      setState(() => _loadingMonth = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("월 근무일지 조회 실패: $e")),
        );
      }
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
        final mq = MediaQuery.of(context);

        return MediaQuery(
          data: mq.copyWith(
            // 월 텍스트 overflow 방지만
            textScaler: const TextScaler.linear(0.94),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() => _month = DateTime(picked.year, picked.month, 1));
    await _loadMonthRows(_month);
  }

  // CODE_CD/CODE_NM -> Dropdown items (중복 제거)
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

  // Dropdown value가 items에 없으면 null로 내려 assertion 방지
  String? safeValue(String? current, List<Map<String, dynamic>> rows) {
    if (current == null || current.trim().isEmpty) return null;
    final v = current.trim();
    final exists = rows.any((r) => (r["CODE_CD"] ?? "").toString().trim() == v);
    return exists ? v : null;
  }

  String _dowTextFromDb(String? dayNm, DateTime date) {
    // 서버 DAY_NM이 THU/MON 식으로 오니 그거 있으면 쓰고, 없으면 날짜로 계산
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

    final workCd = (row.workType).trim(); // WORK_TYPE
    return {"104", "106", "107", "108", "109"}.contains(workCd);
  }
  
  _CellStyle _workTypeStyle(_WorkLogRow row) {
    const editBg = Color(0xFFFFF8CC);
    const noneEditBg = Color(0xFFEFF3F9);
    const red = Color(0xFFCC0000);
    const black = Color(0xFF000000);

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
        return const _CellStyle(editable: true, background: noneEditBg, foreground: black);
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "근무일지 작성",
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
          IconButton(
            tooltip: "저장",
            onPressed: isBusy
                ? null
                : _saveAll,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 정보 바(사원명/월)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: Color(0xFF2F6BFF)),
                  const SizedBox(width: 8),
                  Text(
                    "사원명: $_employeeName",
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E2A3B)),
                  ),
                  const Spacer(),
                  Text(
                    monthTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E2A3B)),
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
                    border: Border.all(color: const Color(0xFFE6EDF6)),
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
        border: Border(bottom: BorderSide(color: Color(0xFFE6EDF6))),
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
    // --- normalize ---
    final confirmFlag = (row.confirmFlag ?? "").trim(); // 'Y'면 확정
    final vacFlag = (row.vacFlag ?? "").trim();         // 'Y'면 휴가등록
    final workCd = (row.workType).trim();               // WORK_TYPE 코드 (필요 시 디버깅용)

    final isConfirmed = confirmFlag == 'Y';
    final disableByLoading = _loadingCodes || _loadingMonth;

    // --- styles (web rule) ---
    final wtStyle = _workTypeStyle(row);           // WORK_TYPE: editable/bg/fg
    final areaEditable = _isWorkAreaEditable(row); // WORK_AREA: editable rule

    // row-level editable (확정이면 대부분 편집불가)
    final rowLocked = disableByLoading || isConfirmed;

    // 각 컬럼별 editable (웹 로직을 최대한 그대로)
    final workTypeEditable = !rowLocked && wtStyle.editable;    // ✅ 핵심: wtStyle 반영
    final workAreaEditable = !rowLocked && areaEditable;        // ✅ confirm/loading까지 반영
    final projectEditable = !rowLocked;                         // (웹 규칙 없어서 보통 이렇게)
    final remarkEditable = !rowLocked;                          // (웹 규칙 없어서 보통 이렇게)
    // 필요하면 vacFlag == 'Y'일 때 project/remark도 잠그려면 여기서 추가:
    // final projectEditable = !rowLocked && vacFlag != 'Y';
    // final remarkEditable = !rowLocked && vacFlag != 'Y';

    // --- colors ---
    final baseBg = i.isEven ? Colors.white : const Color(0xFFFBFCFF);
    const editBg = Color(0xFFFFF8CC);
    const noneEditBg = Color(0xFFEFF3F9);

    // WORK_AREA/PROJECT/REMARK 배경은 "편집 가능 여부"에 따라 바꿈 (웹의 gv_editColor / gv_noneEditColor 느낌)
    final areaBg = workAreaEditable ? editBg : noneEditBg;
    final projectBg = projectEditable ? editBg : noneEditBg;
    final remarkBg = remarkEditable ? editBg : noneEditBg;

    // --- display values ---
    final dateStr = row.yyyymmdd ?? DateFormat("yyyy-MM-dd").format(row.date);
    final dow = _dowTextFromDb(row.dayNm, row.date);

    // --- items ---
    final workTypeItems =
        _loadingCodes ? const <DropdownMenuItem<String>>[] : buildCodeItems(_workTypeRows);
    final locationItems =
        _loadingCodes ? const <DropdownMenuItem<String>>[] : buildCodeItems(_locationRows);
    final projectItems =
        _loadingCodes ? const <DropdownMenuItem<String>>[] : buildCodeItems(_projectRows);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: baseBg,
        border: const Border(bottom: BorderSide(color: Color(0xFFE6EDF6))),
      ),
      child: Row(
        children: [
          _Cell(width: 110, child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w700))),
          _Cell(width: 70, child: Text(dow, style: const TextStyle(fontWeight: FontWeight.w700))),

          // ✅ 근무 형태(WORK_TYPE) - web style 반영
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
                      
                        // (선택) 쉬는날 코드면 입력값 비우기
                        // - 웹이 자동으로 채운 remark는 지우지 않는게 유사
                        if (_offWorkTypeCodes.contains(v)) {
                          row.workArea = "";
                          row.project = "";
                        }
                      });
                    },
                    // ✅ 글자색 (빨강/검정)
                    style: TextStyle(
                      color: wtStyle.foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ✅ 근무 지역(WORK_AREA) - web rule: confirm!='Y' && workCd in {104,106,107,108,109}
          _Cell(
            width: 140,
            background: areaBg,
            child: IgnorePointer(
              ignoring: !workAreaEditable,
              child: Opacity(
                opacity: workAreaEditable ? 1.0 : 0.45, // ✅ 반대로 되어있던 버그 수정
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _loadingCodes ? null : safeValue(row.workArea, _locationRows),
                    hint: const Text(""),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: locationItems,
                    onChanged: (v) => setState(() => row.workArea = v ?? ""),
                  ),
                ),
              ),
            ),
          ),

          // ✅ 프로젝트(PROJECT_CD) - (웹 rule 미제공) 기본은 confirm/loading 아니면 편집 가능
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
                  ),
                ),
              ),
            ),
          ),

          // ✅ 비고(REMARK) - (웹 rule 미제공) 기본은 confirm/loading 아니면 편집 가능
          _Cell(
            width: 220,
            background: remarkBg,
            child: IgnorePointer(
              ignoring: !remarkEditable,
              child: Opacity(
                opacity: remarkEditable ? 1.0 : 0.45,
                child: TextField(
                  controller: row.remarkCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
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
        color: Color(0xFF1E2A3B),
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

/// 서버 월조회 결과 컬럼에 맞춘 row
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

  String workCd = "";     // 서버: WORK_CD
  String workType = "";   // 서버: WORK_TYPE (휴일이면 100)
  String workArea = "";   // 서버: WORK_AREA (AREA_CODE)
  String project;    // 서버: PROJECT_CD

  String remark;     // 서버: REMARK
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