// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'BizMate POS';

  @override
  String get login => 'Đăng nhập';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get register => 'Đăng ký';

  @override
  String get taxCode => 'Mã số thuế';

  @override
  String get password => 'Mật khẩu';

  @override
  String get confirmPassword => 'Xác nhận mật khẩu';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get loginToAccount => 'Đăng nhập vào tài khoản';

  @override
  String get registerOwner => 'Đăng ký Chủ cửa hàng';

  @override
  String get registerStaff => 'Đăng ký Nhân viên';

  @override
  String get ownerChip => 'Chủ shop';

  @override
  String get staffChip => 'Nhân viên';

  @override
  String get shopId => 'Shop ID';

  @override
  String get shopIdHint => 'Nhập hoặc quét Shop ID';

  @override
  String get shopIdHintDesktop => 'Nhập Shop ID cửa hàng';

  @override
  String get scanShopQr => 'Quét mã QR cửa hàng';

  @override
  String get scanShopQrTitle => 'Quét mã QR cửa hàng';

  @override
  String get close => 'Đóng';

  @override
  String get rememberPassword => 'Ghi nhớ mật khẩu';

  @override
  String get rememberAccount => 'Ghi nhớ tài khoản';

  @override
  String get noAccountRegister => 'Chưa có tài khoản? Đăng ký ngay';

  @override
  String get haveAccountLogin => 'Đã có tài khoản? Đăng nhập';

  @override
  String get pleaseEnterEmail => 'Vui lòng nhập email';

  @override
  String get invalidEmail => 'Email không hợp lệ';

  @override
  String get pleaseEnterPassword => 'Vui lòng nhập mật khẩu';

  @override
  String get passwordMinLength => 'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get pleaseConfirmPassword => 'Vui lòng xác nhận mật khẩu';

  @override
  String get passwordMismatch => 'Mật khẩu xác nhận không khớp';

  @override
  String get pleaseEnterShopId =>
      'Vui lòng nhập hoặc quét Shop ID của cửa hàng';

  @override
  String get pleaseEnterShopIdDesktop => 'Vui lòng nhập Shop ID của cửa hàng';

  @override
  String get firebaseNotReady =>
      'Firebase chưa sẵn sàng. Vui lòng thử lại sau.';

  @override
  String get loginSuccess => 'Đăng nhập thành công!';

  @override
  String get loginFailed => 'Đăng nhập thất bại';

  @override
  String get registerSuccess => 'Đăng ký thành công! Đang tạo cửa hàng...';

  @override
  String get registerSuccessStaff =>
      'Đăng ký thành công, vui lòng đợi Admin phê duyệt.';

  @override
  String get registerFailed => 'Đăng ký thất bại';

  @override
  String get initializingFirebase => 'Đang khởi tạo Firebase...';

  @override
  String get selectColumns => 'Chọn cột hiển thị';

  @override
  String get productCode => 'Mã hàng';

  @override
  String get productName => 'Tên hàng';

  @override
  String get category => 'Nhóm hàng';

  @override
  String get sellPrice => 'Giá bán';

  @override
  String get costPrice => 'Giá vốn';

  @override
  String get stock => 'Tồn kho';

  @override
  String get customerOrder => 'Khách đặt';

  @override
  String get createdAt => 'Thời gian tạo';

  @override
  String get expiry => 'Dự kiến hết hàng';

  @override
  String get isSellable => 'Đang bán';

  @override
  String get productSellEnabled => 'Đã bật bán sản phẩm';

  @override
  String get productSellDisabled => 'Đã tắt bán sản phẩm';

  @override
  String errorOnUpdate(Object error) {
    return 'Lỗi khi cập nhật: $error';
  }

  @override
  String get pleaseSelectBranchToUpdateStock =>
      'Vui lòng chọn chi nhánh để cập nhật tồn kho.';

  @override
  String get updateStock => 'Cập nhật tồn kho';

  @override
  String get quickUpdateDisabledMessage =>
      'Tính năng cập nhật nhanh đã bị tắt. Vui lòng sử dụng \'Phiếu nhập kho\' để điều chỉnh số lượng.';

  @override
  String get goToPurchase => 'Đến Phiếu nhập kho';

  @override
  String get newQuantity => 'Số lượng mới';

  @override
  String get cancel => 'Hủy';

  @override
  String get update => 'Cập nhật';

  @override
  String get invalidQuantity => 'Số lượng không hợp lệ';

  @override
  String get quantityUnchanged => 'Số lượng không thay đổi';

  @override
  String stockUpdated(Object productName) {
    return 'Đã cập nhật tồn kho $productName';
  }

  @override
  String get errorUpdateStock => 'Lỗi cập nhật tồn kho';

  @override
  String errorGeneric(Object error) {
    return 'Lỗi: $error';
  }

  @override
  String get confirmDelete => 'Xác nhận xóa';

  @override
  String confirmDeleteProduct(Object productName) {
    return 'Bạn có chắc muốn xóa sản phẩm \"$productName\"? Sản phẩm sẽ được chuyển sang trạng thái ngừng kinh doanh.';
  }

  @override
  String get delete => 'Xóa';

  @override
  String get productDeleted => 'Đã xóa sản phẩm';

  @override
  String errorOnDelete(Object error) {
    return 'Lỗi khi xóa: $error';
  }

  @override
  String get apply => 'Áp dụng';

  @override
  String get allCategories => 'Tất cả danh mục';

  @override
  String get all => 'Tất cả';

  @override
  String get inStock => 'Còn hàng';

  @override
  String get lowStock => 'Sắp hết';

  @override
  String get outOfStock => 'Hết hàng';

  @override
  String get searchByNameSku => 'Tìm kiếm theo tên, SKU hoặc mã vạch...';

  @override
  String get searchByCodeNameSku => 'Tìm kiếm theo mã, tên, SKU...';

  @override
  String get selectCategory => 'Chọn nhóm hàng';

  @override
  String get createNew => 'Tạo mới';

  @override
  String get productList => 'Danh sách sản phẩm';

  @override
  String get addProduct => 'Thêm sản phẩm';

  @override
  String get addCategory => 'Thêm nhóm hàng';

  @override
  String get addProductShort => 'sản phẩm';

  @override
  String get addCategoryShort => 'nhóm hàng';

  @override
  String get importExcel => 'Import Excel';

  @override
  String get retry => 'Thử lại';

  @override
  String get loadMore => 'Tải thêm';

  @override
  String get allTime => 'Toàn thời gian';

  @override
  String get customDate => 'Tùy chỉnh ngày...';

  @override
  String get advancedFilter => 'Bộ lọc nâng cao';

  @override
  String get resetFilter => 'Đặt lại bộ lọc';

  @override
  String get searchCategory => 'Tìm nhóm hàng...';

  @override
  String get allCategoriesFilter => 'Tất cả nhóm hàng';

  @override
  String get stockStatus => 'Trạng thái tồn kho';

  @override
  String get warehouseLocation => 'Vị trí kho';

  @override
  String get selectLocation => 'Chọn vị trí';

  @override
  String get extraOptions => 'Tùy chọn bổ sung';

  @override
  String get points => 'TÍCH ĐIỂM';

  @override
  String get directSale => 'BÁN TRỰC TIẾP';

  @override
  String get channelLink => 'LIÊN KẾT KÊNH BÁN';

  @override
  String get productStatus => 'Trạng thái hàng hóa';

  @override
  String get active => 'Đang kinh doanh';

  @override
  String get inactive => 'Ngừng kinh doanh';

  @override
  String get description => 'Mô tả, ghi chú';

  @override
  String get stockTag => 'Thẻ kho';

  @override
  String get copy => 'Sao chép';

  @override
  String get edit => 'Chỉnh sửa';

  @override
  String get branch => 'Chi nhánh';

  @override
  String get status => 'Trạng thái';

  @override
  String get total => 'Tổng';

  @override
  String get unclassified => 'Chưa phân loại';

  @override
  String get regularProduct => 'Hàng hóa thường';

  @override
  String get directSell => 'Bán trực tiếp';

  @override
  String get noDirectSell => 'Không bán trực tiếp';

  @override
  String get pointsChip => 'Tích điểm';

  @override
  String get searchBranchName => 'Tìm tên chi nhánh';

  @override
  String get yes => 'Có';

  @override
  String get no => 'Không';

  @override
  String get stopSelling => 'Ngừng bán';

  @override
  String get unit => 'Đơn vị';

  @override
  String get barcode => 'Mã vạch';

  @override
  String get brand => 'Thương hiệu';

  @override
  String get version => 'Phiên bản';

  @override
  String get noVersion => 'Không có';

  @override
  String get minStockLabel => 'Định mức tồn';

  @override
  String get location => 'Vị trí';

  @override
  String get quickUpdateFromList => 'Cập nhật nhanh từ danh sách sản phẩm';

  @override
  String currentStock(Object value) {
    return 'Tồn kho hiện tại: $value';
  }

  @override
  String get customerManagement => 'Quản lý khách hàng';

  @override
  String get allGroups => 'Tất cả nhóm';

  @override
  String get deactivate => 'Ngừng hoạt động';

  @override
  String contentUpdating(Object label) {
    return 'Nội dung $label đang cập nhật';
  }

  @override
  String get noDebt => 'Khách hàng không có nợ cần thu';

  @override
  String get currentDebt => 'Nợ hiện tại';

  @override
  String get viewAnalysis => 'Xem phân tích';

  @override
  String get chooseBranch => 'Chọn chi nhánh';

  @override
  String get allGroupsFilter => 'Tất cả các nhóm';

  @override
  String get custom => 'Tùy chỉnh';

  @override
  String get productNotFound => 'Không tìm thấy sản phẩm';

  @override
  String get noBatchAtBranch => 'Không có lô hàng tồn tại tại chi nhánh này';

  @override
  String addedToCart(Object batch, Object productName) {
    return 'Đã thêm $productName — Lô $batch vào giỏ hàng';
  }

  @override
  String addedToCartSimple(Object productName) {
    return 'Đã thêm $productName vào giỏ hàng';
  }

  @override
  String get selectBatch => 'Chọn lô hàng';

  @override
  String get existingBatches => 'Lô hiện có:';

  @override
  String get addToCart => 'Thêm vào giỏ';

  @override
  String quantityExceedsBatch(Object quantity) {
    return 'Số lượng vượt tồn lô ($quantity)';
  }

  @override
  String get emptyCart => 'Giỏ hàng trống';

  @override
  String get selectPaymentMethod => 'Chọn phương thức thanh toán';

  @override
  String get cash => 'Tiền mặt';

  @override
  String get qrTransfer => 'Chuyển khoản QR';

  @override
  String get confirmPayment => 'Xác nhận thanh toán';

  @override
  String totalAmount(Object amount) {
    return 'Tổng tiền: $amount đ';
  }

  @override
  String get paymentMethodCash => 'Phương thức: Tiền mặt';

  @override
  String get confirm => 'Xác nhận';

  @override
  String get qrPayment => 'Thanh toán chuyển khoản';

  @override
  String get createOrder => 'Tạo đơn hàng';

  @override
  String get orderCreatedMessage =>
      'Đơn hàng đã được tạo. Vui lòng kiểm tra tài khoản và xác nhận khi đã nhận tiền.';

  @override
  String get cannotCreateQr =>
      'Không thể tạo mã QR. Vui lòng kiểm tra cấu hình thanh toán trong Cài đặt.';

  @override
  String get paymentSuccessEinvoice =>
      'Thanh toán thành công! Hóa đơn điện tử đã được tạo.';

  @override
  String cannotOpenLink(Object error) {
    return 'Không thể mở link: $error';
  }

  @override
  String get paymentSuccess => 'Thanh toán thành công!';

  @override
  String get exit => 'Thoát';

  @override
  String get totalAmountLabel => 'Tổng tiền hàng';

  @override
  String get pay => 'Thanh toán';

  @override
  String get customer => 'Khách hàng';

  @override
  String get promotion => 'Khuyến mãi';

  @override
  String get done => 'Xong';

  @override
  String get featureInDevelopment => 'Tính năng đang phát triển';

  @override
  String get addProductToCart => 'Thêm sản phẩm vào giỏ';

  @override
  String get quantity => 'Số lượng';

  @override
  String get removeDiscount => 'Xóa chiết khấu';

  @override
  String get priceCannotBeNegative => 'Giá bán không được âm';

  @override
  String get discountCannotBeNegative => 'Chiết khấu không được âm';

  @override
  String get discountPercentExceeds100 =>
      'Phần trăm giảm giá không được vượt quá 100%';

  @override
  String get approvalRequired => 'Yêu cầu phê duyệt';

  @override
  String get selectProduct => 'Chọn sản phẩm';

  @override
  String get productOutOfStock => 'Sản phẩm tạm hết hàng';

  @override
  String get scanBarcode => 'Quét mã vạch';

  @override
  String get checkout => 'THANH TOÁN';

  @override
  String errorSaveSettings(Object error) {
    return 'Lỗi khi lưu cài đặt: $error';
  }

  @override
  String get settingsSaved => 'Lưu cài đặt thành công!';

  @override
  String get logoUploadSuccess =>
      'Đã tải logo lên thành công. Logo sẽ hiển thị trên hóa đơn.';

  @override
  String logoUploadError(Object error) {
    return 'Lỗi tải logo: $error';
  }

  @override
  String get userGuide => 'Hướng dẫn sử dụng';

  @override
  String get salesGuide => 'Hướng dẫn bán hàng';

  @override
  String get purchaseGuide => 'Hướng dẫn nhập kho';

  @override
  String get purchaseGuideUpdating => 'Hướng dẫn nhập kho đang được cập nhật.';

  @override
  String get addProductGuide => 'Hướng dẫn thêm sản phẩm';

  @override
  String get addProductGuideUpdating =>
      'Hướng dẫn thêm sản phẩm đang được cập nhật.';

  @override
  String get paymentConfig => 'Cấu hình Thanh toán';

  @override
  String get autoConfirmPayment => 'Tự động xác nhận tiền về';

  @override
  String get save => 'Lưu';

  @override
  String get eInvoiceConfig => 'Cấu hình Hóa đơn điện tử';

  @override
  String get contactAdminUpgrade =>
      'Liên hệ quản trị viên để nâng cấp lên gói PRO.';

  @override
  String get upgrade => 'Nâng cấp';

  @override
  String get shopSettings => 'Cài đặt Shop';

  @override
  String get dashboard => 'Trang Tổng Quan';

  @override
  String get featureInDev => 'Tính năng đang được phát triển';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get selectLanguage => 'Chọn ngôn ngữ';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'English';

  @override
  String get overview => 'Tổng quan';

  @override
  String get needSupport => 'CẦN HỖ TRỢ?';

  @override
  String get contactTechTeam => 'Liên hệ đội ngũ kỹ thuật ngay.';

  @override
  String get sendRequest => 'Gửi yêu cầu';

  @override
  String get orders => 'Đơn hàng';

  @override
  String get salesInvoice => 'Hóa đơn bán hàng';

  @override
  String get returnInvoice => 'Hóa đơn trả hàng';

  @override
  String get cancelInvoice => 'Hóa đơn hủy';

  @override
  String get eInvoice => 'Hóa đơn điện tử';

  @override
  String get products => 'Sản phẩm';

  @override
  String get productGroup => 'Nhóm sản phẩm';

  @override
  String get serviceList => 'Danh sách dịch vụ';

  @override
  String get serviceGroup => 'Nhóm dịch vụ';

  @override
  String get inventoryManagement => 'Quản lý kho';

  @override
  String get stockOverview => 'Tồn kho';

  @override
  String get purchase => 'Nhập kho';

  @override
  String get transferStock => 'Chuyển kho';

  @override
  String get adjustStock => 'Điều chỉnh kho';

  @override
  String get customers => 'Khách hàng';

  @override
  String get customerList => 'Danh sách khách hàng';

  @override
  String get customerGroup => 'Nhóm khách hàng';

  @override
  String get staffManagement => 'Quản lý nhân viên';

  @override
  String get employeeList => 'Danh sách nhân viên';

  @override
  String get employeeGroup => 'Nhóm nhân viên';

  @override
  String get reports => 'Báo cáo';

  @override
  String get salesReport => 'Báo cáo doanh số';

  @override
  String get profitReport => 'Báo cáo lợi nhuận';

  @override
  String get stockMovementReport => 'Báo cáo nhập xuất tồn';

  @override
  String get debtReport => 'Báo cáo công nợ';

  @override
  String get salesReturnReport => 'Báo cáo hàng trả';

  @override
  String get lowStockReport => 'Báo cáo tồn kho thấp';

  @override
  String get expiryReport => 'Hàng sắp hết hạn';

  @override
  String get settings => 'Cài đặt';

  @override
  String get more => 'Nhiều hơn';

  @override
  String get shopInfo => 'Thông tin cửa hàng';

  @override
  String get generalSettings => 'Cài đặt chung';

  @override
  String get storeSetup => 'Thiết lập cửa hàng';

  @override
  String get transactions => 'Giao dịch';

  @override
  String get invoices => 'Hóa đơn';

  @override
  String get returns => 'Trả hàng';

  @override
  String get cashBook => 'Sổ quỹ';

  @override
  String get goods => 'Hàng hoá';

  @override
  String get inventoryCheck => 'Kiểm kho';

  @override
  String get goodsReceipt => 'Nhập hàng';

  @override
  String get partners => 'Đối tác';

  @override
  String get suppliers => 'Nhà cung cấp';

  @override
  String get taxAndAccounting => 'Thuế & Kế toán';

  @override
  String get branchManagement => 'Chi nhánh';

  @override
  String get advancedFeatures => 'Tính năng nâng cao';

  @override
  String get appAccount => 'Tài khoản app';

  @override
  String get bizmate => 'BizMate';

  @override
  String get home => 'Trang chủ';

  @override
  String get sales => 'Bán hàng';

  @override
  String get employees => 'Nhân viên';

  @override
  String get guideTouchHint =>
      'Chạm vào đây để xem danh sách hướng dẫn: bán hàng, nhập kho, thêm sản phẩm.';

  @override
  String get registrationEnabled => 'Đã bật cho phép nhân viên đăng ký';

  @override
  String get registrationDisabled => 'Đã tắt cho phép nhân viên đăng ký';

  @override
  String get accountInfo => 'Thông tin tài khoản';

  @override
  String get loginEmail => 'Email đăng nhập';

  @override
  String get servicePackage => 'Gói dịch vụ';

  @override
  String get packagePro => 'Gói dịch vụ: PRO';

  @override
  String get packageBasic => 'Gói dịch vụ: BASIC';

  @override
  String get cloudSyncEnabled =>
      'Đã mở khóa đồng bộ Cloud và tính năng Real-time.';

  @override
  String get offlineOnly => 'Chế độ Offline-only.';

  @override
  String get logoutReloginHint =>
      'Nếu bạn vừa được gia hạn/nâng cấp gói, hãy đăng xuất rồi đăng nhập lại để áp dụng.';

  @override
  String get goHome => 'Về trang chủ';

  @override
  String get shopName => 'Tên shop';

  @override
  String get pleaseEnterShopName => 'Vui lòng nhập tên shop';

  @override
  String get phone => 'Số điện thoại';

  @override
  String get address => 'Địa chỉ';

  @override
  String get website => 'Website';

  @override
  String get shopLogo => 'Logo cửa hàng';

  @override
  String get logoOnInvoice => 'Logo hiển thị trên đầu hóa đơn in.';

  @override
  String get uploading => 'Đang tải...';

  @override
  String get selectLogo => 'Chọn logo';

  @override
  String get branchManagementTile => 'Quản lý chi nhánh';

  @override
  String get branchManagementSubtitle =>
      'Thêm, sửa, xóa các chi nhánh cửa hàng';

  @override
  String get paymentConfigTile => 'Cấu hình thanh toán';

  @override
  String get configured => 'Đã cấu hình';

  @override
  String get notConfigured => 'Chưa cấu hình';

  @override
  String get setup => 'Thiết lập';

  @override
  String get printerConfig => 'Cấu hình Máy in';

  @override
  String get defaultPaperSize => 'Khổ giấy mặc định';

  @override
  String get paper58mm => 'Khổ 58mm (K58)';

  @override
  String get paper80mm => 'Khổ 80mm (K80)';

  @override
  String get copyShopId => 'Sao chép Shop ID';

  @override
  String get shopIdCopied => 'Đã sao chép Shop ID vào clipboard';

  @override
  String get viewQr => 'Xem QR';

  @override
  String get shopQrCode => 'Mã QR Cửa hàng';

  @override
  String get noShopId => 'Chưa có Shop ID';

  @override
  String get staffShopIdHint =>
      'Nhân viên có thể dùng Shop ID này để đăng ký tài khoản';

  @override
  String get guideList => 'Xem hướng dẫn bán hàng, nhập kho, thêm sản phẩm';

  @override
  String get paymentFailed => 'Thanh toán thất bại';

  @override
  String get cannotCreateOrder => 'Không thể tạo đơn hàng';

  @override
  String get cannotApplyDiscount => 'Không thể áp dụng chiết khấu';

  @override
  String get selectReportType => 'Chọn loại báo cáo';

  @override
  String get revenueReportSubtitle => 'Doanh thu và số đơn theo ngày';

  @override
  String get profitReportSubtitle =>
      'Doanh thu, giá vốn, lợi nhuận theo ngày/tháng';

  @override
  String invoiceTabName(Object n) {
    return 'Hóa đơn $n';
  }

  @override
  String get tutorialOrderSuccess => 'Hoàn thành đơn hàng mẫu thành công!';

  @override
  String get qrTransferManualConfirm =>
      'Vui lòng tự kiểm tra xác nhận thanh toán từ khách hàng trước khi hoàn tất đơn hàng.';

  @override
  String get openInvoice => 'Mở hóa đơn';

  @override
  String get mainBranch => 'Cửa hàng chính';

  @override
  String get noBranchSelected => 'Chưa chọn chi nhánh';

  @override
  String get pleaseSelectBranch => 'Vui lòng chọn chi nhánh';

  @override
  String get staffLabel => 'Nhân viên';

  @override
  String get tutorialModeHint =>
      'Bạn đang ở chế độ hướng dẫn - Dữ liệu sẽ không được lưu';

  @override
  String get emptyCartHint => 'Chưa có sản phẩm nào trong giỏ hàng';

  @override
  String get pressAddProductHint => 'Nhấn \"Thêm sản phẩm\" để chọn hàng';

  @override
  String get customerInfo => 'Thông tin khách hàng';

  @override
  String get taxCodeForInvoice => 'MST (xuất hóa đơn)';

  @override
  String get branchLabel => 'Chi nhánh: ';

  @override
  String get staffShortLabel => 'NV: ';

  @override
  String get searchProductHint =>
      'Tìm sản phẩm (F2) - quét mã vạch hoặc nhập tên...';

  @override
  String get deleteHeader => 'Xóa';

  @override
  String get unitHeader => 'ĐVT';

  @override
  String get unitPriceHeader => 'Đơn giá';

  @override
  String get amountHeader => 'Thành tiền';

  @override
  String get printLabel => 'In';

  @override
  String get selectPriceList => 'Chọn bảng giá';

  @override
  String get deliveryLabel => 'Giao hàng';

  @override
  String get pressCartToPay =>
      'Nhấn nút Giỏ hàng ở góc dưới để xem và thanh toán';

  @override
  String get confirmLabel => 'Xác nhận';

  @override
  String get totalBeforeDiscount => 'Tổng tiền hàng';

  @override
  String get discountLabel => 'Giảm giá';

  @override
  String get tapToAdd => 'Nhấn để thêm';

  @override
  String get taxLabel => 'Thuế';

  @override
  String get totalLabel => 'Tổng cộng';

  @override
  String get customerToPay => 'KHÁCH CẦN TRẢ';

  @override
  String get payButtonShort => 'THANH TOÁN (F9)';

  @override
  String get enterQuantity => 'Nhập số lượng';

  @override
  String get sellPriceVnd => 'Giá bán (VNĐ)';

  @override
  String get enterSellPrice => 'Nhập giá bán';

  @override
  String get discountLabelShort => 'Chiết khấu';

  @override
  String get vnd => 'VNĐ';

  @override
  String get enterPercentExample => 'Nhập % (ví dụ: 10)';

  @override
  String get enterAmountExample => 'Nhập số tiền (ví dụ: 50000)';

  @override
  String get orderDiscountTitle => 'Chiết khấu đơn hàng';

  @override
  String get percentLabel => 'Phần trăm (%)';

  @override
  String get amountVnd => 'Số tiền (VNĐ)';

  @override
  String get discountPercentLabel => 'Phần trăm giảm giá (%)';

  @override
  String get discountAmountLabel => 'Số tiền giảm giá (VNĐ)';

  @override
  String discountExceedsThreshold(Object percent) {
    return 'Chiết khấu $percent% vượt quá ngưỡng cho phép (10%).';
  }

  @override
  String get onlyAdminCanApprove =>
      'Chỉ Admin/Manager mới có quyền phê duyệt chiết khấu này.';

  @override
  String get searchProduct => 'Tìm kiếm sản phẩm...';

  @override
  String get backToList => 'Xem lại danh sách sản phẩm';

  @override
  String get backTooltip => 'Quay lại';

  @override
  String get totalToPay => 'Tổng cộng cần thanh toán';

  @override
  String get defaultUnit => 'Cái';

  @override
  String get customerName => 'Tên khách hàng';

  @override
  String get defaultAddress => 'Quận 1 - TP. Hồ Chí Minh';
}
