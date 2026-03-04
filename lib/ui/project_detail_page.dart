import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '../../core/storage/app_session.dart';
import 'receipt_detail_page.dart';

// 공통코드 모델
class CodeModel {
  final String codeCd;
  final String codeNm;

  CodeModel({required this.codeCd, required this.codeNm});

  factory CodeModel.fromJson(Map<String, dynamic> json) {
    return CodeModel(
      codeCd: (json['CODE_CD'] ?? '').toString(),
      codeNm: (json['CODE_NM'] ?? '').toString(),
    );
  }
}

class ProjectDetailPage extends StatefulWidget {
  final String projectCd;
  final String projectNm;
  final String yearMonth;

  const ProjectDetailPage({
    super.key,
    required this.projectCd,
    required this.projectNm,
    required this.yearMonth,
  });

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  String _empId = "";
  List<CodeModel> _expenseCodes = [];
  String _selectedExpCd = "ALL";

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingCodes = true;
  bool _isWorkConfirmed = false;

  final Set<int> _selectedIdx = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final empId = (await AppSession.userId() ?? "").trim();
    setState(() => _empId = empId);
    await Future.wait([
      _loadExpenseCodes(),
      _loadReceipts(),
    ]);

    if (mounted) setState(() => _loading = false);
  }

  // 공통코드 조회
  Future<void> _loadExpenseCodes() async {
    setState(() => _loadingCodes = true);
    try {
      final result = await BizService.searchList(
        tranList: [
          TranData(
            siq: "common.comCode",
            outDs: "expenseCodeList",
            params: {"grpCd": "EXPENSE_ITEM_CODE"},
          ),
        ],
      );

      final rows = (result["expenseCodeList"] ?? []).cast<Map<String, dynamic>>();
      final codes = rows.map(CodeModel.fromJson).toList();
      codes.insert(0, CodeModel(codeCd: "ALL", codeNm: "전체"));

      if (!mounted) return;
      setState(() {
        _expenseCodes = codes;
        _loadingCodes = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loadingCodes = false);
    }
  }

  // 경비내역 조회
  Future<void> _loadReceipts() async {
    final userId = (await AppSession.userId() ?? "").trim();
    setState(() {
      _loading = true;
      _selectedIdx.clear();
    });

    try {
      final results = await BizService.searchList(
        tranList: [
          // 경비 내역
          TranData(
              siq: "project.receiptMng",
              outDs: "rtnList",
              params: {
                "year": widget.yearMonth.substring(0, 4),
                "userId": userId,
                "sql": "N",
                "gvSubTotal": "Sub Total",
                "gvTotal": "Total",
                "_mtd": "getList",
                "yearMonth": widget.yearMonth,
                "project": widget.projectCd,
                "expenseCode": _selectedExpCd == "ALL" ? "" : _selectedExpCd,
              }
          ),
          // 근무일지 확정 여부
          TranData(
            siq: "master.workCalConfirm",
            outDs: "rtnList2",
            params: {
              "yearMonth": widget.yearMonth.replaceAll('-', ''),
              "empId": _empId,
            },
          ),
        ],
      );

      final list = (results["rtnList"] ?? []).cast<Map<String, dynamic>>();
      final confirmRows = (results["rtnList2"] ?? []).cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _items = list.where((m) {
          final p = (m["PROJECT_CD"] ?? "").toString().toLowerCase();
          final u = (m["USER_ID"] ?? "").toString().trim();
          return !p.contains("total") && (u == _empId || u.isEmpty);
        }).toList();

        // 근무일자 확정 여부
        if (confirmRows.isNotEmpty) {
          _isWorkConfirmed = (int.tryParse(confirmRows[0]["CNT"].toString()) ?? 0) > 0;
        }
      });

    } catch (e) {
      debugPrint("목록 조회 에러 발생: $e");
      if (mounted) setState(() => _items = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _calcTotal() {
    int receiptSum = 0;
    for (final m in _items) {
      final v = m["PRICE"];
      receiptSum += int.tryParse((v ?? "0").toString()) ?? 0;
    }
    return receiptSum;
  }

  // 삭제
  List<Map<String, dynamic>> _deletedItems = [];

  Future<void> _deleteSelected() async {
    if (_selectedIdx.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("삭제할 항목을 선택하세요.")));
      return;
    }

    setState(() {
      List<int> sortedIndices = _selectedIdx.toList()..sort((a, b) => b.compareTo(a));

      for (int index in sortedIndices) {
        var item = _items[index];
        if (item["REC_SEQ"] != null) {
          var deleteTarget = Map<String, dynamic>.from(item);
          deleteTarget["state"] = "deleted";
          _deletedItems.add(deleteTarget);
        }
        _items.removeAt(index);
      }
      _selectedIdx.clear();
    });

    _showMsg("저장 버튼을 눌러주세요");
  }

  // saveAll함수
  Future<void> _saveAll() async {
    List<Map<String, dynamic>> finalRows = [];
    for (var delItem in _deletedItems) {
      finalRows.add(delItem);
    }
    // 목록에 추가된 데이터 있으면 insert
    for (var item in _items) {
      if (item["REC_SEQ"] == null) {
        var newRow = Map<String, dynamic>.from(item);
        newRow["state"] = "inserted";
        finalRows.add(newRow);
      }
    }

    if (finalRows.isEmpty) {
      _showMsg("변경사항이 없습니다");
      return;
    }

    try {
      final cnt = await BizService.save(
        siq: "project.receiptMng",
        outDs: "saveCnt",
        rows: finalRows,
        extraParams: {
          "_mtd": "saveAll",
          "sql": "N",
          "gvTotal": "Total",
          "gvSubTotal": "Sub Total",
        },
      );

      if (mounted) {
        _showMsg("저장 완료");
        _deletedItems.clear();
        await _loadReceipts();
      }
    } catch (e) {
      debugPrint("저장 에러: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("저장 실패: $e")));
    }
  }

  void _toggleAll(bool? checked) {
    setState(() {
      _selectedIdx.clear();
      if (checked == true) {
        for (int i = 0; i < _items.length; i++) {
          _selectedIdx.add(i);
        }
      }
    });
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
    final total = _calcTotal();
    final allChecked = _items.isNotEmpty && _selectedIdx.length == _items.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.projectNm,
            style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E2A3B))),
        actions: [
          IconButton(
              onPressed: _loading ? null : _saveAll,
              icon: const Icon(Icons.save_outlined)
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(total),
          _buildFilterArea(),
          _buildSelectionHeader(allChecked),
          Expanded(child: _buildListView()),
        ],
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  // 총 금액
  Widget _buildSummaryCard(int total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(color: const Color(0xFFE8EAF6), borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: Text(
          "총 ${NumberFormat('#,###').format(total)}원",
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF3F51B5)),
        ),
      ),
    );
  }

  // 필터
  Widget _buildFilterArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedExpCd,
            items: _expenseCodes.map((c) => DropdownMenuItem(value: c.codeCd, child: Text(c.codeNm))).toList(),
            onChanged: _loadingCodes ? null : (v) async {
              if (v == null) return;
              setState(() => _selectedExpCd = v);
              await _loadReceipts();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(bool allChecked) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Checkbox(value: allChecked, onChanged: _loading ? null : _toggleAll, activeColor: Colors.black),
          const Text("전체 선택", style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(widget.yearMonth, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  // 리스트
  Widget _buildListView() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) return const Center(child: Text("내역이 없습니다."));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final expNm = (item["EXP_NM"] ?? "").toString();
        final expCd = (item["EXP_CD"] ?? "").toString();
        final recDate = (item["REC_DATE"] ?? "").toString();
        // 날짜 형식 변환
        String formattedDate = recDate;
        if (recDate.contains("-")) {
          try {
            final parts = recDate.split("-");
            if (parts.length >= 3) {
              final month = int.parse(parts[1]);
              final day = int.parse(parts[2]);
              formattedDate = "$month월 $day일";
            }
          } catch (e) {
            debugPrint("날짜 하이픈 파싱 에러: $e");
          }
        } else if (recDate.length == 8) {
          try {
            final month = int.parse(recDate.substring(4, 6));
            final day = int.parse(recDate.substring(6, 8));
            formattedDate = "$month월 $day일";
          } catch (e) {
            debugPrint("날짜 8자리 파싱 에러: $e");
          }
        }
        final price = int.tryParse((item["PRICE"] ?? "0").toString()) ?? 0;
        final creditNm = item["CREDIT_CD"] == "CORPORATION" ? "법인" : "개인";
        final receiptCnt = (item["RECEIPT"] ?? "").toString();
        final bool isConfirmed = (item["CONFIRM_YN"] ?? "N") == "Y"; // 확정 여부

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isConfirmed ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if(!isConfirmed)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
            ],
              border: isConfirmed ? Border.all(color: Colors.grey.shade300) : null,
          ),
          child: InkWell(
            onTap:
              // ? () => _showMsg("확정된 데이터는 수정할 수 없습니다.")
              () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptDetailPage(
                    projectCd: widget.projectCd,
                    projectNm: widget.projectNm,
                    yearMonth: widget.yearMonth,
                    receiptData: item,
                  ),
                ),
              );
              if (result == true) await _loadReceipts();
            },
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: _selectedIdx.contains(index),
                    activeColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: isConfirmed
                      ? null
                      : (v) => setState(() => v == true ? _selectedIdx.add(index) : _selectedIdx.remove(index)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expNm.isEmpty ? expCd : expNm,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isConfirmed ? Colors.grey : const Color(0xFF1E2A3B)
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.description_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "영수증 ${receiptCnt}장", // 영수증 개수 표시
                            style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  "${NumberFormat('#,###').format(price)}원",
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.black),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 하단영역
  Widget _buildBottomButtons() {
    final bool isConfirmed = _items.any((item) => (item["CONFIRM_YN"] ?? "N") == "Y");
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (isConfirmed || _loading || !_isWorkConfirmed)
                      ? null
                      : _deleteSelected,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7D6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("삭제", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: (isConfirmed || _loading || !_isWorkConfirmed)
                  ? null
                  : () async {
                    if (!_isWorkConfirmed) {
                      _showMsg("해당 월의 근무일지가 확정되지 않았습니다.\n근무일지 먼저 작성 후 확정해주세요.");
                      return;
                    }
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReceiptDetailPage(
                          projectCd: widget.projectCd,
                          projectNm: widget.projectNm,
                          yearMonth: widget.yearMonth,
                        ),
                      ),
                    );
                    if (result == true) await _loadReceipts();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("추가", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}