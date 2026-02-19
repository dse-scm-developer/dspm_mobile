import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkLogPage extends StatefulWidget {
  const WorkLogPage({super.key});

  @override
  State<WorkLogPage> createState() => _WorkLogPageState();
}

class _WorkLogPageState extends State<WorkLogPage> {
  // TODO: 로그인 사용자명으로 치환
  final String _employeeName = "정지솔";

  // 화면에서 보고 싶은 월(예: 이번달). 필요하면 월 선택 UI로 확장 가능
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  late List<_WorkLogRow> _rows;

  final _workTypes = const ["근무", "재택", "외근", "휴일", "연차", "반차"];
  final _locations = const ["본사", "재택", "현장", "출장"];
  final _projects = const ["-", "HR", "APS", "SCM", "운영"];

  @override
  void initState() {
    super.initState();
    _rows = _buildRowsForMonth(_month);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2030, 12, 31),
      helpText: "월 선택",
    );

    if (picked == null) return;

    setState(() {
      _month = DateTime(picked.year, picked.month, 1);
      _rows = _buildRowsForMonth(_month);
    });
  }

  List<_WorkLogRow> _buildRowsForMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final nextMonth = DateTime(month.year, month.month + 1, 1);
    final days = nextMonth.difference(first).inDays;

    return List.generate(days, (i) {
      final d = DateTime(month.year, month.month, i + 1);
      final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
      return _WorkLogRow(
        date: d,
        workType: isWeekend ? "휴일" : "근무",
        location: isWeekend ? "" : "본사",
        project: "",
        remark: "",
      );
    });
  }

  String _dowText(int weekday) {
    // DateTime.monday=1 ... sunday=7
    switch (weekday) {
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

  @override
  Widget build(BuildContext context) {
    final monthTitle = DateFormat("yyyy-MM").format(_month);

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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("저장되었습니다. (임시)")),
              );
            },
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 그리드(가로 스크롤 + 세로 스크롤)
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
                        width: 980, // 컬럼들이 잘 보이게 넓이 고정(필요시 조정)
                        child: ListView.builder(
                          itemCount: _rows.length + 1, // 헤더 포함
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
        border: Border(
          bottom: BorderSide(color: Color(0xFFE6EDF6)),
        ),
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
    final isWeekend = row.date.weekday == DateTime.saturday || row.date.weekday == DateTime.sunday;
    final isOffDay = (row.workType == "휴일" || row.workType == "연차" || row.workType == "반차");


    // 웹 화면처럼 연한 노란 배경 느낌(근무 형태~비고 영역)
    final baseBg = i.isEven ? Colors.white : const Color(0xFFFBFCFF);
    final workAreaBg = const Color(0xFFFFF8CC); // 연노랑

    final dateStr = DateFormat("yyyy-MM-dd").format(row.date);
    final dow = _dowText(row.date.weekday);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: baseBg,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE6EDF6)),
        ),
      ),
      child: Row(
        children: [
          _Cell(
            width: 110,
            child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          _Cell(
            width: 70,
            child: Text(dow, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),

          // 근무 형태(드롭다운)
          _Cell(
            width: 150,
            background: workAreaBg,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: row.workType.isEmpty ? null : row.workType,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                items: _workTypes
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: (e == "휴일" || e == "연차" || e == "반차") ? Colors.red : const Color(0xFF1E2A3B),
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    row.workType = v;

                    final off = (v == "휴일" || v == "연차" || v == "반차");
                    if (off) {
                      row.location = "";
                      row.project = "";
                    } else {
                      row.location = row.location.isEmpty ? "본사" : row.location;
                    }
                  });
                },
              ),
            ),
          ),

          // 근무 지역(드롭다운)
          _Cell(
            width: 140,
            background: workAreaBg,
            child: IgnorePointer(
              ignoring: isOffDay,
              child: Opacity(
                opacity: isOffDay ? 0.45 : 1.0,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: row.location.isEmpty ? null : row.location,
                    hint: const Text(""),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: _locations.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      setState(() => row.location = v ?? "");
                    },
                  ),
                ),
              ),
            ),
          ),


          // 프로젝트(드롭다운)
          _Cell(
            width: 220,
            background: workAreaBg,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: row.project.isEmpty ? null : row.project,
                hint: const Text(""),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                items: _projects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) {
                  setState(() => row.project = v ?? "");
                },
              ),
            ),
          ),

          // 비고(텍스트 입력)
          _Cell(
            width: 220,
            background: workAreaBg,
            child: IgnorePointer(
              ignoring: isOffDay,
              child: Opacity(
                opacity: isOffDay ? 0.45 : 1.0,
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: row.project.isEmpty ? null : row.project,
                    hint: const Text(""),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    items: _projects.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) {
                      setState(() => row.project = v ?? "");
                    },
                  ),
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

  const _Cell({
    required this.width,
    required this.child,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: background,
      ),
      child: child,
    );
  }
}

class _WorkLogRow {
  final DateTime date;
  String workType;
  String location;
  String project;
  String remark;

  final TextEditingController remarkCtrl;

  _WorkLogRow({
    required this.date,
    required this.workType,
    required this.location,
    required this.project,
    required this.remark,
  }) : remarkCtrl = TextEditingController(text: remark);
}
