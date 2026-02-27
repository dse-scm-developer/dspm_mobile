import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '/features/biz/service/biz_service.dart';
import '/features/biz/service/tran_data.dart';
import '/features/file/service/receipt_file_service.dart';
import '../../core/storage/app_session.dart';
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
  String _selectedCreditCd = "개인";
  final List<String> _creditOptions = ["개인", "법인"];
  String _empId = "";

  bool _isSaving = false;
  bool _loadingCodes = true;

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
    _priceCtrl = TextEditingController(text: (data?['PRICE'] ?? '').toString());
    _contentsCtrl = TextEditingController(text: data?['CONTENTS'] ?? '');
    if (data?['EXP_CD'] != null) _selectedExpCd = data!['EXP_CD'].toString();
    if (data?['CREDIT_CD'] != null) {
      final dbValue = data!['CREDIT_CD'].toString();
      _selectedCreditCd = (dbValue == "CORPORATION") ? "법인" : "개인";
    }
  }

  Future<void> _initData() async {
    final empId = (await AppSession.userId() ?? "").trim();
    setState(() => _empId = empId);
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
      final codes = rows.map<CodeModel>(CodeModel.fromJson).toList();

      if (!mounted) return;
      setState(() {
        _expenseCodes = codes;
        if (_selectedExpCd.isEmpty && codes.isNotEmpty) {
          _selectedExpCd = codes[0].codeCd;
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

  // 경비 내역 저장 함수
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final row = {
        ...(widget.receiptData ?? {}),
        "PROJECT_CD": widget.projectCd,
        "YEARMONTH": widget.yearMonth.replaceAll('-', ''),
        "REC_DATE": _dateCtrl.text.replaceAll('-', ''),
        "EXP_CD": _selectedExpCd,
        "CONTENTS": _contentsCtrl.text,
        "PRICE": int.tryParse(_priceCtrl.text.replaceAll(',', '')) ?? 0,
        "CREDIT_CD": _selectedCreditCd,
        "USER_ID": _empId,
        "state": widget.receiptData == null ? "inserted" : "updated",
      };

      await BizService.save(
        siq: "project.receiptMng",
        outDs: "saveCnt",
        rows: [row],
        extraParams: {"_mtd": "saveAll"},
      );
      final recSeq = widget.receiptData?['REC_SEQ']?.toString() ?? "";
      // 서버 파일 삭제 반영
      if (recSeq.isNotEmpty && _deletedFileSeqs.isNotEmpty) {
        for (final fileSeq in _deletedFileSeqs) {
          await ReceiptFileService.delete(
            projectCd: widget.projectCd,
            dtlRecSeq: recSeq,
            fileSeq: fileSeq,
          );
        }
        _deletedFileSeqs.clear();
      }
      // 새로 선택한 이미지 업로드
      if (_images.isNotEmpty) {
        await ReceiptFileService.upload(
          images: _images,
          params: {
            "PROJECT_CD": widget.projectCd,
            "DTL_REC_SEQ": recSeq,
            "USER_ID": _empId,
            "YEARMONTH": widget.yearMonth.replaceAll('-', ''),
            "EXP_CD": _selectedExpCd,
          },
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("저장 실패: $e");
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

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar(); // 기존 snackbar 삭제
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "경비 상세",
          style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E2A3B)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1E2A3B)),
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
              _buildImageSection(),
              const SizedBox(height: 32),

              _buildLabel("경비일자"),
              const SizedBox(height: 8),
              _buildDateField(),

              const SizedBox(height: 20),

              _buildLabel("경비 항목"),
              const SizedBox(height: 8),
              _buildExpTypeDropdown(),

              const SizedBox(height: 20),

              _buildLabel("개인/법인"),
              const SizedBox(height: 8),
              _buildCreditTypeDropdown(),

              const SizedBox(height: 20),

              _buildLabel("금액"),
              const SizedBox(height: 8),
              _buildPriceField(),

              const SizedBox(height: 20),

              _buildLabel("내용"),
              const SizedBox(height: 8),
              _buildContentsField(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildSaveButton(),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1E2A3B)),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(color: const Color(0xFFF6F8FB), borderRadius: BorderRadius.circular(14)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_dateCtrl.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildExpTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedExpCd.isEmpty ? null : _selectedExpCd,
      items: _expenseCodes.map((c) => DropdownMenuItem(value: c.codeCd, child: Text(c.codeNm))).toList(),
      onChanged: (v) => setState(() => _selectedExpCd = v ?? ""),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF6F8FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildCreditTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCreditCd,
      items: _creditOptions.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
      onChanged: (v) => setState(() => _selectedCreditCd = v ?? "개인"),
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFF6F8FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceCtrl,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F6BFF)),
      decoration: InputDecoration(
        suffixText: "원",
        filled: true,
        fillColor: const Color(0xFFF6F8FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildContentsField() {
    return TextFormField(
      controller: _contentsCtrl,
      maxLines: 3,
      decoration: InputDecoration(
        hintText: "내용을 입력하세요",
        filled: true,
        fillColor: const Color(0xFFF6F8FB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

// 영수증 영역
  Widget _buildImageSection() {
    final recSeq = widget.receiptData?['REC_SEQ']?.toString() ?? "";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("영수증 첨부", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          if (_loadingFiles) const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
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
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
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
              border: Border.all(color: Colors.grey.shade200),
              image: DecorationImage(image: image, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 16,
          child: GestureDetector(
            onTap: onDelete,
            child: CircleAvatar(
              radius: 10,
              backgroundColor: isServer ? Colors.red.withOpacity(0.8) : Colors.black54,
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
      onTap: _pickImages,
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(Icons.add_a_photo, color: Colors.grey),
      ),
    );
  }

  // 저장 버튼
  Widget _buildSaveButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F4F8))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F6BFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              _isSaving ? "저장 중..." : "저장하기",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
  Future<void> _pickDate() async {
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