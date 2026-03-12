import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '/features/file/service/receipt_file_service.dart';
import '../../core/storage/app_session.dart';
import '../../core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

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

// 가격 형식 지정 클래스
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String newValueText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final int value = int.parse(newValueText);
    final String newText = NumberFormat('#,###').format(value);
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class ReceiptDetailPage extends StatefulWidget {
  final String projectCd;
  final String projectNm;
  final String yearMonth;
  final Map<String, dynamic>? receiptData;

  const ReceiptDetailPage({
    super.key,
    required this.projectCd,
    required this.projectNm,
    required this.yearMonth,
    this.receiptData,
  });

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final List<XFile> _images = [];
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _dateCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _contentsCtrl;

  String _selectedExpCd = "";
  List<CodeModel> _expenseCodes = [];
  String? _selectedCreditCd;
  final List<String> _creditOptions = ["개인", "법인"];
  String _empId = "";
  int _calculateDayPay = 0; // 일비

  bool _isSaving = false;
  bool _loadingCodes = true;
  bool get _isConfirmed => (widget.receiptData?['CONFIRM_YN'] ??'N') == 'Y';

  // 서버에 이미 저장된 파일 목록
  List<Map<String, dynamic>> _serverFiles = [];
  bool _loadingFiles = false;

  //삭제할 목록들
  final Set<String> _deletedFileSeqs = {};

  @override
  void initState() {
    super.initState();
    _initFields();
    _initData();
  }

  void _initFields() {
    final data = widget.receiptData;
    _dateCtrl = TextEditingController(
      text: data?['REC_DATE'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    final rawPrice = (data?['PRICE'] ?? '').toString();
    String formattedPrice = '';
    if (rawPrice.isNotEmpty) {
      final n = int.tryParse(rawPrice) ?? 0;
      formattedPrice = NumberFormat('#,###').format(n);
    }
    _priceCtrl = TextEditingController(text: formattedPrice);
    _contentsCtrl = TextEditingController(text: data?['CONTENTS'] ?? '');
    if (data?['EXP_CD'] != null) _selectedExpCd = data!['EXP_CD'].toString();
    if (data?['CREDIT_CD'] != null) {
      final dbValue = data!['CREDIT_CD'].toString();
      _selectedCreditCd = (dbValue == "CORPORATION") ? "법인" : "개인";
    } else {
      _selectedCreditCd = null;
    }
  }

  Future<void> _initData() async {
    final empId = (await AppSession.userId() ?? "").trim();
    final company = (await AppSession.company()) ?? "";
    final bu = (await AppSession.bu()) ?? "";
    setState(() => _empId = empId);
    try {
      final result = await BizService.searchList(
        tranList: [
          TranData(
            siq: "common.comCode",
            outDs: "expenseCodeList",
            params: {"grpCd": "EXPENSE_ITEM_CODE"},
          ),
          TranData(
            siq: "project.calDayPay", //일비
            outDs: "dayPayData",
            params: {
              "empId": empId,
              "yearMonth": widget.yearMonth.replaceAll('-', ''),
              "loadFlag": "Y",
            },
          ),
        ],
      );
      final codeRows = (result["expenseCodeList"] ?? []).cast<Map<String, dynamic>>();
      final dayPayRows = (result["dayPayData"] ?? []);
      final codes = codeRows.map<CodeModel>(CodeModel.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _expenseCodes = codes;
/*        if (_selectedExpCd.isEmpty && codes.isNotEmpty) {
          _selectedExpCd = codes[0].codeCd;
        }*/
        if (dayPayRows.isNotEmpty) {
          _calculateDayPay = int.tryParse(dayPayRows[0]["DAY_PAY"].toString()) ?? 0;
        }
        _loadingCodes = false;
      });
      final recSeq = widget.receiptData?['REC_SEQ']?.toString() ?? "";
      if (recSeq.isNotEmpty) {
        await _loadServerFiles(recSeq);
      }
    } catch (e) {
      debugPrint("코드 로드 실패: $e");
      if (mounted) setState(() => _loadingCodes = false);
    }
  }

  // 서버 파일 불러오기
  Future<void> _loadServerFiles(String recSeq) async {
    setState(() => _loadingFiles = true);
    try {
      final files = await ReceiptFileService.fetchList(
        projectCd: widget.projectCd,
        dtlRecSeq: recSeq,
        yearMonth: widget.yearMonth.replaceAll('-', ''),
        userId: _empId,
      );
      if (!mounted) return;
      setState(() {
        _serverFiles = files;
        _loadingFiles = false;
      });
    } catch (e) {
      debugPrint("파일 목록 조회 실패: $e");
      if (mounted) setState(() => _loadingFiles = false);
    }
  }
  Future<void> _pickImages() async {
    final List<XFile> selected = await _picker.pickMultiImage();
    if (selected.isNotEmpty) {
      setState(() => _images.addAll(selected));
    }
  }

  // 화면에서 삭제
  void _markDeleteServerFile(int index) {
    final f = _serverFiles[index];
    final fileSeq = (f['FILE_SEQ'] ?? '').toString();
    if (fileSeq.isEmpty) return;

    setState(() {
      _deletedFileSeqs.add(fileSeq);
      _serverFiles.removeAt(index); // 화면에서 즉시 제거
    });
  }

  // 썸네일 탭
  void _openPreview(Uint8List bytes) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () {
                    _downloadImage(bytes);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.download, color: Colors.white, size: 28),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 달력은 해당 달만 나오게
  Future<void> _pickDate() async {
    try {
      String ymRaw = widget.yearMonth.replaceAll('-', '');
      if (ymRaw.length < 6) {
        throw Exception("연월 형식이 잘못되었습니다: ${widget.yearMonth}");
      }
      final int year = int.parse(ymRaw.substring(0, 4));
      final int month = int.parse(ymRaw.substring(4, 6));

      final DateTime firstDay = DateTime(year, month, 1);
      final DateTime lastDay = DateTime(year, month + 1, 0);

      DateTime initialDate = DateTime.tryParse(_dateCtrl.text) ?? firstDay;
      if (initialDate.isBefore(firstDay) || initialDate.isAfter(lastDay)) {
        initialDate = firstDay;
      }

      // 달력 띄우기
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: firstDay,
        lastDate: lastDay,
        helpText: "${year}년 ${month}월 날짜 선택",
      );

      if (picked != null) {
        setState(() => _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
      }
    } catch (e) {
      debugPrint("날짜 선택 에러: $e");
      DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2024),
        lastDate: DateTime(2030),
      );
      if (picked != null) {
        setState(() => _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked));
      }
    }
  }

  // 경비 내역 저장 함수
  Future<void> _save() async {
    final userId = (await AppSession.userId() ?? "").trim();
    final company = (await AppSession.company()) ?? "";
    final bu = (await AppSession.bu()) ?? "";
    if (!_formKey.currentState!.validate() || _isSaving) return;
    if (_isSaving) return;
    final String inputDate = _dateCtrl.text.replaceAll('-', '');
    final String inputYm = inputDate.substring(0, 6);
    final String targetYm = widget.yearMonth.replaceAll('-', '');
    if (inputYm != targetYm) {
      _showMsg("일자는 조회한 연월(${widget.yearMonth})과 같아야 합니다.");
      return;
    }
    setState(() => _isSaving = true);

    try {
      final bool isNew = widget.receiptData == null;

      final Map<String, dynamic> row = {
        ...(widget.receiptData ?? {}),
        "PROJECT_CD": widget.projectCd,
        "YEARMONTH": widget.yearMonth.replaceAll('-', ''),
        "REC_DATE": _dateCtrl.text,
        "EXP_CD": _selectedExpCd,
        "CONTENTS": _contentsCtrl.text.isEmpty ? "-" : _contentsCtrl.text,
        "PRICE": int.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
        "CREDIT_CD": _selectedCreditCd,
        "USER_ID": _empId,
        "state": isNew ? "inserted" : "updated",
        "GV_USER_ID": _empId,
        "GV_COMPANY_CD": "DSE",
        "GV_BU_CD": "DS",
        "_ROWNUM": "1",
      };

      final saveResult = await BizService.save(
        siq: "project.receiptMng",
        outDs: "saveCnt",
        rows: [row],
        extraParams: {
          "_mtd": "saveAll",
          "sql": "N",
          "gvTotal": "Total",
          "gvSubTotal": "Sub Total"
        },
      );

      String finalRecSeq = widget.receiptData?['REC_SEQ']?.toString() ?? "";

      // 파일 신규 저장 시
      if (isNew) {
        final res = await BizService.searchList(
          tranList: [
            TranData(
              siq: "project.receiptMng",
              outDs: "rtnList",
              params: {
                "year": widget.yearMonth.substring(0, 4),
                "userId": userId,
                "yearMonth": widget.yearMonth,
                "project": widget.projectCd,
                "expenseCode": "",
                "_mtd": "getList",
              },
            ),
          ],
        );

        final List<Map<String, dynamic>> list = (res["rtnList"] ?? []).cast<Map<String, dynamic>>();
        if (list.isNotEmpty) {
          final realItems = list.where((e) =>
          e["REC_SEQ"] != null &&
              e["PROJECT_CD"] != "Total" &&
              e["PROJECT_CD"] != "Sub Total"
          ).toList();

          if (realItems.isNotEmpty) {
            // 내림차순 정렬해서 가장 큰 번호
            realItems.sort((a, b) {
              int seqA = int.tryParse(a["REC_SEQ"].toString()) ?? 0;
              int seqB = int.tryParse(b["REC_SEQ"].toString()) ?? 0;
              return seqB.compareTo(seqA);
            });
            finalRecSeq = realItems.first["REC_SEQ"].toString();
          }
        }
      }

      // 파일이 있을 시
      if (finalRecSeq.isNotEmpty && finalRecSeq != "null") {
        // 수정 시 삭제 처리
        if (!isNew && _deletedFileSeqs.isNotEmpty) {
          for (final fileSeq in _deletedFileSeqs) {
            await ReceiptFileService.delete(
              projectCd: widget.projectCd,
              dtlRecSeq: finalRecSeq,
              fileSeq: fileSeq,
            );
          }
          _deletedFileSeqs.clear();
        }

        // 신규 사진 업로드
        if (_images.isNotEmpty) {
          await ReceiptFileService.upload(
            images: _images,
            params: {
              "PROJECT_CD": widget.projectCd,
              "DTL_REC_SEQ": finalRecSeq,
              "USER_ID": _empId,
              "YEARMONTH": widget.yearMonth.replaceAll('-', ''),
              "EXP_CD": _selectedExpCd,
            },
          );
        }
      }
      if (mounted) Navigator.pop(context, true);

    } catch (e) {
      debugPrint("저장 실패 에러: $e");
      _showMsg("저장 실패");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // 이미지 다운로드 함수
  Future<void> _downloadImage(Uint8List bytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final String name = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = '${tempDir.path}/$name';

      final file = File(path);
      await file.writeAsBytes(bytes);

      final result = await SaverGallery.saveFile(
        filePath: path,
        fileName: name,
        skipIfExists: false,
        androidRelativePath: "Pictures/Receipts",
      );

      if (mounted) _showMsg("갤러리에 저장이 완료되었습니다.");

    } catch (e) {
      debugPrint("다운로드 실패 에러: $e");
      if (mounted) _showMsg("저장 실패");
    }
  }

  // snackbar함수
  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
              fontSize: 16,
              color: Colors.white
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // scaffoldBackgroundColor는 AppTheme에서 흰색이므로 생략 가능
      appBar: AppBar(
        title: const Text("경비 상세"),
      ),
      resizeToAvoidBottomInset: true,
      body: _loadingCodes
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(context),
              const SizedBox(height: 32),

              _buildLabel(context, "경비일자"),
              const SizedBox(height: 8),
              _buildDateField(context),

              const SizedBox(height: 20),

              _buildLabel(context, "경비 항목"),
              const SizedBox(height: 8),
              _buildExpTypeDropdown(context),

              const SizedBox(height: 20),

              _buildLabel(context, "개인/법인"),
              const SizedBox(height: 8),
              _buildCreditTypeDropdown(context),

              const SizedBox(height: 20),

              _buildLabel(context, "금액"),
              const SizedBox(height: 8),
              _buildPriceField(context),

              const SizedBox(height: 20),

              _buildLabel(context, "내용"),
              const SizedBox(height: 8),
              _buildContentsField(context),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _isConfirmed ? null : _buildSaveButton(context),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppTheme.ink,
      ),
    );
  }

  Widget _buildDateField(BuildContext context) {
    return TextFormField(
      controller: _dateCtrl,
      readOnly: true,
      enabled: !_isConfirmed,
      onTap: _isConfirmed ? null : _pickDate,
      // style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      //       fontSize: 16,
      //       fontWeight: FontWeight.w700,
      //       color: AppTheme.ink,
      //     ),
      decoration: const InputDecoration(
        suffixIcon: Icon(Icons.calendar_today, size: 20),
      ),
    );
  }

  Widget _buildExpTypeDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedExpCd.isEmpty ? null : _selectedExpCd,
      hint: const Text("항목을 선택하세요"),
      validator: (value) => (value == null || value.isEmpty) ? "경비 항목을 선택하세요." : null,
      items: _expenseCodes
          .map((c) => DropdownMenuItem(
        value: c.codeCd,
        child: Text(
          c.codeNm,
          overflow: TextOverflow.ellipsis,
          // style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ))
          .toList(),
      onChanged: _isConfirmed
          ? null
          : (v) {
        if (v == null) return;
        setState(() {
          _selectedExpCd = v;
          // 일비 선택시, 자동 계산
          if (v == "251") {
            _priceCtrl.text = NumberFormat('#,###').format(_calculateDayPay);
            _contentsCtrl.text = "일비 자동 계산분";
          }
        });
      },
      // ✅ decoration 비워서 InputDecorationTheme 적용
      decoration: const InputDecoration(),
    );
  }

  Widget _buildCreditTypeDropdown(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: _selectedCreditCd,
      hint: const Text("결제 수단 선택"),
      validator: (value) => (value == null || value.isEmpty) ? "개인/법인 중 선택하세요." : null,
      items: _creditOptions
          .map((val) => DropdownMenuItem(
        value: val,
        child: Text(val),
      ))
          .toList(),
      onChanged: _isConfirmed ? null : (v) => setState(() => _selectedCreditCd = v ?? "개인"),
      decoration: const InputDecoration(),
    );
  }

  Widget _buildPriceField(BuildContext context) {
    final bool isDayPay = (_selectedExpCd == "251");

    return TextFormField(
      controller: _priceCtrl,
      validator: (value) {
        if (value == null || value.isEmpty || value == "0") return "금액을 입력하세요.";
        return null;
      },
      readOnly: isDayPay || _isConfirmed,
      enabled: !_isConfirmed,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        ThousandsFormatter(),
      ],
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppTheme.primary,
      ),
      decoration: const InputDecoration(
        suffixText: "원",
      ),
    );
  }

  Widget _buildContentsField(BuildContext context) {
    return TextFormField(
      controller: _contentsCtrl,
      readOnly: _isConfirmed,
      enabled: !_isConfirmed,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: "내용을 입력하세요",
      ),
    );
  }

  // ===================
  // 영수증 영역
  // ===================
  Widget _buildImageSection(BuildContext context) {
    final recSeq = widget.receiptData?['REC_SEQ']?.toString() ?? "";

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "영수증 첨부",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 16),

            if (_loadingFiles)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: LinearProgressIndicator(),
              ),

            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildAddImageBtn(),
                  const SizedBox(width: 12),

                  if (recSeq.isNotEmpty)
                    ...List.generate(_serverFiles.length, (index) {
                      final f = _serverFiles[index];
                      final fileSeq = (f['FILE_SEQ'] ?? '').toString();
                      return _buildServerImageThumbnail(recSeq, fileSeq, index);
                    }),

                  ...List.generate(_images.length, (index) => _buildLocalImageThumbnail(index)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 영수증 썸네일 (로컬)
  Widget _buildLocalImageThumbnail(int index) {
    return _imageThumbnailItem(
      image: FileImage(File(_images[index].path)),
      onDelete: () => setState(() => _images.removeAt(index)),
      onTap: () async {
        final bytes = await File(_images[index].path).readAsBytes();
        _openPreview(bytes);
      },
    );
  }

  // 영수증 썸네일 (서버)
  Widget _buildServerImageThumbnail(String recSeq, String fileSeq, int index) {
    return FutureBuilder<Uint8List>(
      future: ReceiptFileService.downloadBytes(
        projectCd: widget.projectCd,
        dtlRecSeq: recSeq,
        fileSeq: fileSeq,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            margin: const EdgeInsets.only(right: 12),
            width: 85,
            decoration: BoxDecoration(
              color: AppTheme.softBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _imageThumbnailItem(
          image: MemoryImage(snap.data!),
          onDelete: () => _markDeleteServerFile(index),
          onTap: () => _openPreview(snap.data!),
          isServer: true,
        );
      },
    );
  }

  // 썸네일 위젯
  Widget _imageThumbnailItem({
    required ImageProvider image,
    required VoidCallback onDelete,
    required VoidCallback onTap,
    bool isServer = false,
  }) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            width: 85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
              image: DecorationImage(image: image, fit: BoxFit.cover),
            ),
          ),
        ),
        if (!_isConfirmed)
          Positioned(
            top: 4,
            right: 16,
            child: GestureDetector(
              onTap: onDelete,
              child: CircleAvatar(
                radius: 10,
                // ✅ 테마 톤 유지 (강한 red 대신 primary/ink 계열)
                backgroundColor: isServer
                    ? AppTheme.primary.withOpacity(0.85)
                    : AppTheme.ink.withOpacity(0.6),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  // 이미지 추가 버튼
  Widget _buildAddImageBtn() {
    return GestureDetector(
      onTap: _isConfirmed ? null : _pickImages,
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.softBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(Icons.add_a_photo, color: AppTheme.ink.withOpacity(0.45)),
      ),
    );
  }

  // 저장 버튼
  Widget _buildSaveButton(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: Text(_isSaving ? "저장 중..." : "저장하기"),
          ),
        ),
      ),
    );
  }
}