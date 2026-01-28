class FPTInvoice {
  // 1. Thông tin chung hóa đơn [cite: 230, 241]
  String type = "01/MTT"; // Hóa đơn GTGT từ máy tính tiền [cite: 230]
  String form = "1";      // Mẫu số [cite: 230]
  String serial = "C26MAA"; // Ký hiệu hóa đơn 
  String sid;             // Key duy nhất cho mỗi giao dịch 
  String idt;             // Ngày hóa đơn yyyy-mm-dd hh:mm:ss 

  // 2. Thông tin người mua 
  String bname;           // Tên khách hàng (Bắt buộc) 
  String baddr;           // Địa chỉ khách hàng (Bắt buộc) 
  String? btax;           // Mã số thuế khách hàng 

  // 3. Thông tin thanh toán [cite: 246, 300, 304]
  String paym = "TM";     // Hình thức thanh toán: TM, CK... [cite: 246]
  double sum;             // Tổng tiền trước thuế [cite: 300]
  double vat;             // Tổng tiền thuế [cite: 300]
  double total;           // Tổng tiền thanh toán sau thuế [cite: 304]

  FPTInvoice({
    required this.sid,
    required this.idt,
    required this.bname,
    required this.baddr,
    required this.sum,
    required this.vat,
    required this.total,
    this.btax,
  });

  // Hàm chuyển đổi sang JSON để gửi API [cite: 313]
  Map<String, dynamic> toJson() {
    return {
      "inv": {
        "type": type,
        "form": form,
        "serial": serial,
        "sid": sid,
        "idt": idt,
        "bname": bname,
        "btax": btax,
        "baddr": baddr,
        "paym": paym,
        "sum": sum,
        "vat": vat,
        "total": total,
        "items": [] // Danh sách hàng hóa sẽ thêm ở bước sau [cite: 313]
      }
    };
  }
}

