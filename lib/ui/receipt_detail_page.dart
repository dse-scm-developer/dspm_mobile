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
                  onPressed: () => _downloadImage(bytes),
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("갤러리에 저장이 완료되었습니다."))
        );
      }
    } catch (e) {
      debugPrint("다운로드 실패 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("저장에 실패했습니다."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text("영수증 상세"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loadingCodes
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageSection(),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          TextFormField(
            controller: _dateCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "사용일자",
              suffixIcon: Icon(Icons.calendar_today),
            ),
            onTap: _pickDate,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedExpCd,
            decoration: const InputDecoration(labelText: "경비 항목"),
            items: _expenseCodes
                .map((c) => DropdownMenuItem(value: c.codeCd, child: Text(c.codeNm)))
                .toList(),
            onChanged: (v) => setState(() => _selectedExpCd = v ?? ""),
          ),
          DropdownButtonFormField<String>(
            value: _selectedCreditCd,
            decoration: const InputDecoration(labelText: "결제 구분"),
            items: _creditOptions
                .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCreditCd = v ?? "개인"),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "금액", suffixText: "원"),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contentsCtrl,
            decoration: const InputDecoration(labelText: "내용"),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    final recSeq = widget.receiptData?['REC_SEQ']?.toString() ?? "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("영수증 첨부", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          if (_loadingFiles) const LinearProgressIndicator(),

          // 서버에 저장된 썸네일들
          if (recSeq.isNotEmpty && _serverFiles.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_serverFiles.length, (index) {
                  final f = _serverFiles[index];
                  final fileSeq = (f['FILE_SEQ'] ?? '').toString();

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
                          width: 80,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }

                      final bytes = snap.data!;
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _openPreview(bytes),
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 80,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: MemoryImage(bytes),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => _markDeleteServerFile(index),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...List.generate(_images.length, (index) => _buildLocalImageThumbnail(index)),
                _buildAddImageBtn(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalImageThumbnail(int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 80,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            image: DecorationImage(
              image: FileImage(File(_images[index].path)),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() => _images.removeAt(index)),
            child: const CircleAvatar(
              radius: 10,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(
          _isSaving ? "저장 중..." : "저장",
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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