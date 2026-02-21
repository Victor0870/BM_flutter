import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In vi, this message translates to:
  /// **'BizMate POS'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In vi, this message translates to:
  /// **'Đăng xuất'**
  String get logout;

  /// No description provided for @register.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký'**
  String get register;

  /// No description provided for @taxCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã số thuế'**
  String get taxCode;

  /// No description provided for @password.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận mật khẩu'**
  String get confirmPassword;

  /// No description provided for @email.
  ///
  /// In vi, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In vi, this message translates to:
  /// **'example@email.com'**
  String get emailHint;

  /// No description provided for @loginToAccount.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập vào tài khoản'**
  String get loginToAccount;

  /// No description provided for @registerOwner.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký Chủ cửa hàng'**
  String get registerOwner;

  /// No description provided for @registerStaff.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký Nhân viên'**
  String get registerStaff;

  /// No description provided for @ownerChip.
  ///
  /// In vi, this message translates to:
  /// **'Chủ shop'**
  String get ownerChip;

  /// No description provided for @staffChip.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get staffChip;

  /// No description provided for @shopId.
  ///
  /// In vi, this message translates to:
  /// **'Shop ID'**
  String get shopId;

  /// No description provided for @shopIdHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhập hoặc quét Shop ID'**
  String get shopIdHint;

  /// No description provided for @shopIdHintDesktop.
  ///
  /// In vi, this message translates to:
  /// **'Nhập Shop ID cửa hàng'**
  String get shopIdHintDesktop;

  /// No description provided for @scanShopQr.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã QR cửa hàng'**
  String get scanShopQr;

  /// No description provided for @scanShopQrTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã QR cửa hàng'**
  String get scanShopQrTitle;

  /// No description provided for @close.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get close;

  /// No description provided for @rememberPassword.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhớ mật khẩu'**
  String get rememberPassword;

  /// No description provided for @rememberAccount.
  ///
  /// In vi, this message translates to:
  /// **'Ghi nhớ tài khoản'**
  String get rememberAccount;

  /// No description provided for @noAccountRegister.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có tài khoản? Đăng ký ngay'**
  String get noAccountRegister;

  /// No description provided for @haveAccountLogin.
  ///
  /// In vi, this message translates to:
  /// **'Đã có tài khoản? Đăng nhập'**
  String get haveAccountLogin;

  /// No description provided for @pleaseEnterEmail.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập email'**
  String get pleaseEnterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email không hợp lệ'**
  String get invalidEmail;

  /// No description provided for @pleaseEnterPassword.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập mật khẩu'**
  String get pleaseEnterPassword;

  /// No description provided for @passwordMinLength.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu phải có ít nhất 6 ký tự'**
  String get passwordMinLength;

  /// No description provided for @pleaseConfirmPassword.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng xác nhận mật khẩu'**
  String get pleaseConfirmPassword;

  /// No description provided for @passwordMismatch.
  ///
  /// In vi, this message translates to:
  /// **'Mật khẩu xác nhận không khớp'**
  String get passwordMismatch;

  /// No description provided for @pleaseEnterShopId.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập hoặc quét Shop ID của cửa hàng'**
  String get pleaseEnterShopId;

  /// No description provided for @pleaseEnterShopIdDesktop.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập Shop ID của cửa hàng'**
  String get pleaseEnterShopIdDesktop;

  /// No description provided for @firebaseNotReady.
  ///
  /// In vi, this message translates to:
  /// **'Firebase chưa sẵn sàng. Vui lòng thử lại sau.'**
  String get firebaseNotReady;

  /// No description provided for @loginSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thành công!'**
  String get loginSuccess;

  /// No description provided for @loginFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng nhập thất bại'**
  String get loginFailed;

  /// No description provided for @registerSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thành công! Đang tạo cửa hàng...'**
  String get registerSuccess;

  /// No description provided for @registerSuccessStaff.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thành công, vui lòng đợi Admin phê duyệt.'**
  String get registerSuccessStaff;

  /// No description provided for @registerFailed.
  ///
  /// In vi, this message translates to:
  /// **'Đăng ký thất bại'**
  String get registerFailed;

  /// No description provided for @initializingFirebase.
  ///
  /// In vi, this message translates to:
  /// **'Đang khởi tạo Firebase...'**
  String get initializingFirebase;

  /// No description provided for @selectColumns.
  ///
  /// In vi, this message translates to:
  /// **'Chọn cột hiển thị'**
  String get selectColumns;

  /// No description provided for @productCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã hàng'**
  String get productCode;

  /// No description provided for @productName.
  ///
  /// In vi, this message translates to:
  /// **'Tên hàng'**
  String get productName;

  /// No description provided for @category.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm hàng'**
  String get category;

  /// No description provided for @sellPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá bán'**
  String get sellPrice;

  /// No description provided for @costPrice.
  ///
  /// In vi, this message translates to:
  /// **'Giá vốn'**
  String get costPrice;

  /// No description provided for @stock.
  ///
  /// In vi, this message translates to:
  /// **'Tồn kho'**
  String get stock;

  /// No description provided for @customerOrder.
  ///
  /// In vi, this message translates to:
  /// **'Khách đặt'**
  String get customerOrder;

  /// No description provided for @createdAt.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian tạo'**
  String get createdAt;

  /// No description provided for @expiry.
  ///
  /// In vi, this message translates to:
  /// **'Dự kiến hết hàng'**
  String get expiry;

  /// No description provided for @isSellable.
  ///
  /// In vi, this message translates to:
  /// **'Đang bán'**
  String get isSellable;

  /// No description provided for @productSellEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã bật bán sản phẩm'**
  String get productSellEnabled;

  /// No description provided for @productSellDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt bán sản phẩm'**
  String get productSellDisabled;

  /// No description provided for @errorOnUpdate.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi khi cập nhật: {error}'**
  String errorOnUpdate(Object error);

  /// No description provided for @pleaseSelectBranchToUpdateStock.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn chi nhánh để cập nhật tồn kho.'**
  String get pleaseSelectBranchToUpdateStock;

  /// No description provided for @updateStock.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật tồn kho'**
  String get updateStock;

  /// No description provided for @quickUpdateDisabledMessage.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng cập nhật nhanh đã bị tắt. Vui lòng sử dụng \'Phiếu nhập kho\' để điều chỉnh số lượng.'**
  String get quickUpdateDisabledMessage;

  /// No description provided for @goToPurchase.
  ///
  /// In vi, this message translates to:
  /// **'Đến Phiếu nhập kho'**
  String get goToPurchase;

  /// No description provided for @newQuantity.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng mới'**
  String get newQuantity;

  /// No description provided for @cancel.
  ///
  /// In vi, this message translates to:
  /// **'Hủy'**
  String get cancel;

  /// No description provided for @update.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật'**
  String get update;

  /// No description provided for @invalidQuantity.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng không hợp lệ'**
  String get invalidQuantity;

  /// No description provided for @quantityUnchanged.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng không thay đổi'**
  String get quantityUnchanged;

  /// No description provided for @stockUpdated.
  ///
  /// In vi, this message translates to:
  /// **'Đã cập nhật tồn kho {productName}'**
  String stockUpdated(Object productName);

  /// No description provided for @errorUpdateStock.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi cập nhật tồn kho'**
  String get errorUpdateStock;

  /// No description provided for @errorGeneric.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi: {error}'**
  String errorGeneric(Object error);

  /// No description provided for @confirmDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận xóa'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteProduct.
  ///
  /// In vi, this message translates to:
  /// **'Bạn có chắc muốn xóa sản phẩm \"{productName}\"? Sản phẩm sẽ được chuyển sang trạng thái ngừng kinh doanh.'**
  String confirmDeleteProduct(Object productName);

  /// No description provided for @delete.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get delete;

  /// No description provided for @productDeleted.
  ///
  /// In vi, this message translates to:
  /// **'Đã xóa sản phẩm'**
  String get productDeleted;

  /// No description provided for @errorOnDelete.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi khi xóa: {error}'**
  String errorOnDelete(Object error);

  /// No description provided for @apply.
  ///
  /// In vi, this message translates to:
  /// **'Áp dụng'**
  String get apply;

  /// No description provided for @allCategories.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả danh mục'**
  String get allCategories;

  /// No description provided for @all.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get all;

  /// No description provided for @inStock.
  ///
  /// In vi, this message translates to:
  /// **'Còn hàng'**
  String get inStock;

  /// No description provided for @lowStock.
  ///
  /// In vi, this message translates to:
  /// **'Sắp hết'**
  String get lowStock;

  /// No description provided for @outOfStock.
  ///
  /// In vi, this message translates to:
  /// **'Hết hàng'**
  String get outOfStock;

  /// No description provided for @searchByNameSku.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm theo tên, SKU hoặc mã vạch...'**
  String get searchByNameSku;

  /// No description provided for @searchByCodeNameSku.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm theo mã, tên, SKU...'**
  String get searchByCodeNameSku;

  /// No description provided for @selectCategory.
  ///
  /// In vi, this message translates to:
  /// **'Chọn nhóm hàng'**
  String get selectCategory;

  /// No description provided for @createNew.
  ///
  /// In vi, this message translates to:
  /// **'Tạo mới'**
  String get createNew;

  /// No description provided for @productList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách sản phẩm'**
  String get productList;

  /// No description provided for @addProduct.
  ///
  /// In vi, this message translates to:
  /// **'Thêm sản phẩm'**
  String get addProduct;

  /// No description provided for @addCategory.
  ///
  /// In vi, this message translates to:
  /// **'Thêm nhóm hàng'**
  String get addCategory;

  /// No description provided for @addProductShort.
  ///
  /// In vi, this message translates to:
  /// **'sản phẩm'**
  String get addProductShort;

  /// No description provided for @addCategoryShort.
  ///
  /// In vi, this message translates to:
  /// **'nhóm hàng'**
  String get addCategoryShort;

  /// No description provided for @importExcel.
  ///
  /// In vi, this message translates to:
  /// **'Import Excel'**
  String get importExcel;

  /// No description provided for @retry.
  ///
  /// In vi, this message translates to:
  /// **'Thử lại'**
  String get retry;

  /// No description provided for @loadMore.
  ///
  /// In vi, this message translates to:
  /// **'Tải thêm'**
  String get loadMore;

  /// No description provided for @allTime.
  ///
  /// In vi, this message translates to:
  /// **'Toàn thời gian'**
  String get allTime;

  /// No description provided for @customDate.
  ///
  /// In vi, this message translates to:
  /// **'Tùy chỉnh ngày...'**
  String get customDate;

  /// No description provided for @advancedFilter.
  ///
  /// In vi, this message translates to:
  /// **'Bộ lọc nâng cao'**
  String get advancedFilter;

  /// No description provided for @resetFilter.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại bộ lọc'**
  String get resetFilter;

  /// No description provided for @searchCategory.
  ///
  /// In vi, this message translates to:
  /// **'Tìm nhóm hàng...'**
  String get searchCategory;

  /// No description provided for @allCategoriesFilter.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả nhóm hàng'**
  String get allCategoriesFilter;

  /// No description provided for @stockStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái tồn kho'**
  String get stockStatus;

  /// No description provided for @warehouseLocation.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí kho'**
  String get warehouseLocation;

  /// No description provided for @selectLocation.
  ///
  /// In vi, this message translates to:
  /// **'Chọn vị trí'**
  String get selectLocation;

  /// No description provided for @extraOptions.
  ///
  /// In vi, this message translates to:
  /// **'Tùy chọn bổ sung'**
  String get extraOptions;

  /// No description provided for @points.
  ///
  /// In vi, this message translates to:
  /// **'TÍCH ĐIỂM'**
  String get points;

  /// No description provided for @directSale.
  ///
  /// In vi, this message translates to:
  /// **'BÁN TRỰC TIẾP'**
  String get directSale;

  /// No description provided for @channelLink.
  ///
  /// In vi, this message translates to:
  /// **'LIÊN KẾT KÊNH BÁN'**
  String get channelLink;

  /// No description provided for @productStatus.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái hàng hóa'**
  String get productStatus;

  /// No description provided for @active.
  ///
  /// In vi, this message translates to:
  /// **'Đang kinh doanh'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In vi, this message translates to:
  /// **'Ngừng kinh doanh'**
  String get inactive;

  /// No description provided for @description.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả, ghi chú'**
  String get description;

  /// No description provided for @stockTag.
  ///
  /// In vi, this message translates to:
  /// **'Thẻ kho'**
  String get stockTag;

  /// No description provided for @copy.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép'**
  String get copy;

  /// No description provided for @edit.
  ///
  /// In vi, this message translates to:
  /// **'Chỉnh sửa'**
  String get edit;

  /// No description provided for @branch.
  ///
  /// In vi, this message translates to:
  /// **'Chi nhánh'**
  String get branch;

  /// No description provided for @status.
  ///
  /// In vi, this message translates to:
  /// **'Trạng thái'**
  String get status;

  /// No description provided for @total.
  ///
  /// In vi, this message translates to:
  /// **'Tổng'**
  String get total;

  /// No description provided for @unclassified.
  ///
  /// In vi, this message translates to:
  /// **'Chưa phân loại'**
  String get unclassified;

  /// No description provided for @regularProduct.
  ///
  /// In vi, this message translates to:
  /// **'Hàng hóa thường'**
  String get regularProduct;

  /// No description provided for @directSell.
  ///
  /// In vi, this message translates to:
  /// **'Bán trực tiếp'**
  String get directSell;

  /// No description provided for @noDirectSell.
  ///
  /// In vi, this message translates to:
  /// **'Không bán trực tiếp'**
  String get noDirectSell;

  /// No description provided for @pointsChip.
  ///
  /// In vi, this message translates to:
  /// **'Tích điểm'**
  String get pointsChip;

  /// No description provided for @searchBranchName.
  ///
  /// In vi, this message translates to:
  /// **'Tìm tên chi nhánh'**
  String get searchBranchName;

  /// No description provided for @yes.
  ///
  /// In vi, this message translates to:
  /// **'Có'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In vi, this message translates to:
  /// **'Không'**
  String get no;

  /// No description provided for @stopSelling.
  ///
  /// In vi, this message translates to:
  /// **'Ngừng bán'**
  String get stopSelling;

  /// No description provided for @unit.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị'**
  String get unit;

  /// No description provided for @barcode.
  ///
  /// In vi, this message translates to:
  /// **'Mã vạch'**
  String get barcode;

  /// No description provided for @brand.
  ///
  /// In vi, this message translates to:
  /// **'Thương hiệu'**
  String get brand;

  /// No description provided for @version.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản'**
  String get version;

  /// No description provided for @noVersion.
  ///
  /// In vi, this message translates to:
  /// **'Không có'**
  String get noVersion;

  /// No description provided for @minStockLabel.
  ///
  /// In vi, this message translates to:
  /// **'Định mức tồn'**
  String get minStockLabel;

  /// No description provided for @location.
  ///
  /// In vi, this message translates to:
  /// **'Vị trí'**
  String get location;

  /// No description provided for @quickUpdateFromList.
  ///
  /// In vi, this message translates to:
  /// **'Cập nhật nhanh từ danh sách sản phẩm'**
  String get quickUpdateFromList;

  /// No description provided for @currentStock.
  ///
  /// In vi, this message translates to:
  /// **'Tồn kho hiện tại: {value}'**
  String currentStock(Object value);

  /// No description provided for @customerManagement.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý khách hàng'**
  String get customerManagement;

  /// No description provided for @allGroups.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả nhóm'**
  String get allGroups;

  /// No description provided for @deactivate.
  ///
  /// In vi, this message translates to:
  /// **'Ngừng hoạt động'**
  String get deactivate;

  /// No description provided for @contentUpdating.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung {label} đang cập nhật'**
  String contentUpdating(Object label);

  /// No description provided for @noDebt.
  ///
  /// In vi, this message translates to:
  /// **'Khách hàng không có nợ cần thu'**
  String get noDebt;

  /// No description provided for @currentDebt.
  ///
  /// In vi, this message translates to:
  /// **'Nợ hiện tại'**
  String get currentDebt;

  /// No description provided for @viewAnalysis.
  ///
  /// In vi, this message translates to:
  /// **'Xem phân tích'**
  String get viewAnalysis;

  /// No description provided for @chooseBranch.
  ///
  /// In vi, this message translates to:
  /// **'Chọn chi nhánh'**
  String get chooseBranch;

  /// No description provided for @allGroupsFilter.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả các nhóm'**
  String get allGroupsFilter;

  /// No description provided for @custom.
  ///
  /// In vi, this message translates to:
  /// **'Tùy chỉnh'**
  String get custom;

  /// No description provided for @productNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy sản phẩm'**
  String get productNotFound;

  /// No description provided for @noBatchAtBranch.
  ///
  /// In vi, this message translates to:
  /// **'Không có lô hàng tồn tại tại chi nhánh này'**
  String get noBatchAtBranch;

  /// No description provided for @addedToCart.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm {productName} — Lô {batch} vào giỏ hàng'**
  String addedToCart(Object batch, Object productName);

  /// No description provided for @addedToCartSimple.
  ///
  /// In vi, this message translates to:
  /// **'Đã thêm {productName} vào giỏ hàng'**
  String addedToCartSimple(Object productName);

  /// No description provided for @selectBatch.
  ///
  /// In vi, this message translates to:
  /// **'Chọn lô hàng'**
  String get selectBatch;

  /// No description provided for @existingBatches.
  ///
  /// In vi, this message translates to:
  /// **'Lô hiện có:'**
  String get existingBatches;

  /// No description provided for @addToCart.
  ///
  /// In vi, this message translates to:
  /// **'Thêm vào giỏ'**
  String get addToCart;

  /// No description provided for @quantityExceedsBatch.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng vượt tồn lô ({quantity})'**
  String quantityExceedsBatch(Object quantity);

  /// No description provided for @emptyCart.
  ///
  /// In vi, this message translates to:
  /// **'Giỏ hàng trống'**
  String get emptyCart;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In vi, this message translates to:
  /// **'Chọn phương thức thanh toán'**
  String get selectPaymentMethod;

  /// No description provided for @cash.
  ///
  /// In vi, this message translates to:
  /// **'Tiền mặt'**
  String get cash;

  /// No description provided for @qrTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản QR'**
  String get qrTransfer;

  /// No description provided for @confirmPayment.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận thanh toán'**
  String get confirmPayment;

  /// No description provided for @totalAmount.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tiền: {amount} đ'**
  String totalAmount(Object amount);

  /// No description provided for @paymentMethodCash.
  ///
  /// In vi, this message translates to:
  /// **'Phương thức: Tiền mặt'**
  String get paymentMethodCash;

  /// No description provided for @confirm.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get confirm;

  /// No description provided for @qrPayment.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán chuyển khoản'**
  String get qrPayment;

  /// No description provided for @createOrder.
  ///
  /// In vi, this message translates to:
  /// **'Tạo đơn hàng'**
  String get createOrder;

  /// No description provided for @orderCreatedMessage.
  ///
  /// In vi, this message translates to:
  /// **'Đơn hàng đã được tạo. Vui lòng kiểm tra tài khoản và xác nhận khi đã nhận tiền.'**
  String get orderCreatedMessage;

  /// No description provided for @cannotCreateQr.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo mã QR. Vui lòng kiểm tra cấu hình thanh toán trong Cài đặt.'**
  String get cannotCreateQr;

  /// No description provided for @paymentSuccessEinvoice.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thành công! Hóa đơn điện tử đã được tạo.'**
  String get paymentSuccessEinvoice;

  /// No description provided for @cannotOpenLink.
  ///
  /// In vi, this message translates to:
  /// **'Không thể mở link: {error}'**
  String cannotOpenLink(Object error);

  /// No description provided for @paymentSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thành công!'**
  String get paymentSuccess;

  /// No description provided for @exit.
  ///
  /// In vi, this message translates to:
  /// **'Thoát'**
  String get exit;

  /// No description provided for @totalAmountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tiền hàng'**
  String get totalAmountLabel;

  /// No description provided for @pay.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán'**
  String get pay;

  /// No description provided for @customer.
  ///
  /// In vi, this message translates to:
  /// **'Khách hàng'**
  String get customer;

  /// No description provided for @promotion.
  ///
  /// In vi, this message translates to:
  /// **'Khuyến mãi'**
  String get promotion;

  /// No description provided for @done.
  ///
  /// In vi, this message translates to:
  /// **'Xong'**
  String get done;

  /// No description provided for @featureInDevelopment.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang phát triển'**
  String get featureInDevelopment;

  /// No description provided for @addProductToCart.
  ///
  /// In vi, this message translates to:
  /// **'Thêm sản phẩm vào giỏ'**
  String get addProductToCart;

  /// No description provided for @quantity.
  ///
  /// In vi, this message translates to:
  /// **'Số lượng'**
  String get quantity;

  /// No description provided for @removeDiscount.
  ///
  /// In vi, this message translates to:
  /// **'Xóa chiết khấu'**
  String get removeDiscount;

  /// No description provided for @priceCannotBeNegative.
  ///
  /// In vi, this message translates to:
  /// **'Giá bán không được âm'**
  String get priceCannotBeNegative;

  /// No description provided for @discountCannotBeNegative.
  ///
  /// In vi, this message translates to:
  /// **'Chiết khấu không được âm'**
  String get discountCannotBeNegative;

  /// No description provided for @discountPercentExceeds100.
  ///
  /// In vi, this message translates to:
  /// **'Phần trăm giảm giá không được vượt quá 100%'**
  String get discountPercentExceeds100;

  /// No description provided for @approvalRequired.
  ///
  /// In vi, this message translates to:
  /// **'Yêu cầu phê duyệt'**
  String get approvalRequired;

  /// No description provided for @selectProduct.
  ///
  /// In vi, this message translates to:
  /// **'Chọn sản phẩm'**
  String get selectProduct;

  /// No description provided for @productOutOfStock.
  ///
  /// In vi, this message translates to:
  /// **'Sản phẩm tạm hết hàng'**
  String get productOutOfStock;

  /// No description provided for @scanBarcode.
  ///
  /// In vi, this message translates to:
  /// **'Quét mã vạch'**
  String get scanBarcode;

  /// No description provided for @checkout.
  ///
  /// In vi, this message translates to:
  /// **'THANH TOÁN'**
  String get checkout;

  /// No description provided for @errorSaveSettings.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi khi lưu cài đặt: {error}'**
  String errorSaveSettings(Object error);

  /// No description provided for @settingsSaved.
  ///
  /// In vi, this message translates to:
  /// **'Lưu cài đặt thành công!'**
  String get settingsSaved;

  /// No description provided for @logoUploadSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Đã tải logo lên thành công. Logo sẽ hiển thị trên hóa đơn.'**
  String get logoUploadSuccess;

  /// No description provided for @logoUploadError.
  ///
  /// In vi, this message translates to:
  /// **'Lỗi tải logo: {error}'**
  String logoUploadError(Object error);

  /// No description provided for @userGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn sử dụng'**
  String get userGuide;

  /// No description provided for @salesGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn bán hàng'**
  String get salesGuide;

  /// No description provided for @purchaseGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn nhập kho'**
  String get purchaseGuide;

  /// No description provided for @purchaseGuideUpdating.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn nhập kho đang được cập nhật.'**
  String get purchaseGuideUpdating;

  /// No description provided for @addProductGuide.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn thêm sản phẩm'**
  String get addProductGuide;

  /// No description provided for @addProductGuideUpdating.
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn thêm sản phẩm đang được cập nhật.'**
  String get addProductGuideUpdating;

  /// No description provided for @paymentConfig.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình Thanh toán'**
  String get paymentConfig;

  /// No description provided for @autoConfirmPayment.
  ///
  /// In vi, this message translates to:
  /// **'Tự động xác nhận tiền về'**
  String get autoConfirmPayment;

  /// No description provided for @save.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get save;

  /// No description provided for @eInvoiceConfig.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình Hóa đơn điện tử'**
  String get eInvoiceConfig;

  /// No description provided for @contactAdminUpgrade.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ quản trị viên để nâng cấp lên gói PRO.'**
  String get contactAdminUpgrade;

  /// No description provided for @upgrade.
  ///
  /// In vi, this message translates to:
  /// **'Nâng cấp'**
  String get upgrade;

  /// No description provided for @shopSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt Shop'**
  String get shopSettings;

  /// No description provided for @dashboard.
  ///
  /// In vi, this message translates to:
  /// **'Trang Tổng Quan'**
  String get dashboard;

  /// No description provided for @featureInDev.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng đang được phát triển'**
  String get featureInDev;

  /// No description provided for @language.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ngôn ngữ'**
  String get selectLanguage;

  /// No description provided for @vietnamese.
  ///
  /// In vi, this message translates to:
  /// **'Tiếng Việt'**
  String get vietnamese;

  /// No description provided for @english.
  ///
  /// In vi, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @overview.
  ///
  /// In vi, this message translates to:
  /// **'Tổng quan'**
  String get overview;

  /// No description provided for @needSupport.
  ///
  /// In vi, this message translates to:
  /// **'CẦN HỖ TRỢ?'**
  String get needSupport;

  /// No description provided for @contactTechTeam.
  ///
  /// In vi, this message translates to:
  /// **'Liên hệ đội ngũ kỹ thuật ngay.'**
  String get contactTechTeam;

  /// No description provided for @sendRequest.
  ///
  /// In vi, this message translates to:
  /// **'Gửi yêu cầu'**
  String get sendRequest;

  /// No description provided for @orders.
  ///
  /// In vi, this message translates to:
  /// **'Đơn hàng'**
  String get orders;

  /// No description provided for @salesInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn bán hàng'**
  String get salesInvoice;

  /// No description provided for @returnInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn trả hàng'**
  String get returnInvoice;

  /// No description provided for @cancelInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn hủy'**
  String get cancelInvoice;

  /// No description provided for @eInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn điện tử'**
  String get eInvoice;

  /// No description provided for @products.
  ///
  /// In vi, this message translates to:
  /// **'Sản phẩm'**
  String get products;

  /// No description provided for @productGroup.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm sản phẩm'**
  String get productGroup;

  /// No description provided for @serviceList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách dịch vụ'**
  String get serviceList;

  /// No description provided for @serviceGroup.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm dịch vụ'**
  String get serviceGroup;

  /// No description provided for @inventoryManagement.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý kho'**
  String get inventoryManagement;

  /// No description provided for @stockOverview.
  ///
  /// In vi, this message translates to:
  /// **'Tồn kho'**
  String get stockOverview;

  /// No description provided for @purchase.
  ///
  /// In vi, this message translates to:
  /// **'Nhập kho'**
  String get purchase;

  /// No description provided for @transferStock.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển kho'**
  String get transferStock;

  /// No description provided for @adjustStock.
  ///
  /// In vi, this message translates to:
  /// **'Điều chỉnh kho'**
  String get adjustStock;

  /// No description provided for @customers.
  ///
  /// In vi, this message translates to:
  /// **'Khách hàng'**
  String get customers;

  /// No description provided for @customerList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách khách hàng'**
  String get customerList;

  /// No description provided for @customerGroup.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm khách hàng'**
  String get customerGroup;

  /// No description provided for @staffManagement.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý nhân viên'**
  String get staffManagement;

  /// No description provided for @employeeList.
  ///
  /// In vi, this message translates to:
  /// **'Danh sách nhân viên'**
  String get employeeList;

  /// No description provided for @employeeGroup.
  ///
  /// In vi, this message translates to:
  /// **'Nhóm nhân viên'**
  String get employeeGroup;

  /// No description provided for @reports.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo'**
  String get reports;

  /// No description provided for @salesReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo doanh số'**
  String get salesReport;

  /// No description provided for @profitReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo lợi nhuận'**
  String get profitReport;

  /// No description provided for @stockMovementReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo nhập xuất tồn'**
  String get stockMovementReport;

  /// No description provided for @debtReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo công nợ'**
  String get debtReport;

  /// No description provided for @salesReturnReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo hàng trả'**
  String get salesReturnReport;

  /// No description provided for @lowStockReport.
  ///
  /// In vi, this message translates to:
  /// **'Báo cáo tồn kho thấp'**
  String get lowStockReport;

  /// No description provided for @expiryReport.
  ///
  /// In vi, this message translates to:
  /// **'Hàng sắp hết hạn'**
  String get expiryReport;

  /// No description provided for @settings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// No description provided for @more.
  ///
  /// In vi, this message translates to:
  /// **'Nhiều hơn'**
  String get more;

  /// No description provided for @shopInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin cửa hàng'**
  String get shopInfo;

  /// No description provided for @generalSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt chung'**
  String get generalSettings;

  /// No description provided for @storeSetup.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập cửa hàng'**
  String get storeSetup;

  /// No description provided for @transactions.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch'**
  String get transactions;

  /// No description provided for @invoices.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn'**
  String get invoices;

  /// No description provided for @returns.
  ///
  /// In vi, this message translates to:
  /// **'Trả hàng'**
  String get returns;

  /// No description provided for @cashBook.
  ///
  /// In vi, this message translates to:
  /// **'Sổ quỹ'**
  String get cashBook;

  /// No description provided for @goods.
  ///
  /// In vi, this message translates to:
  /// **'Hàng hoá'**
  String get goods;

  /// No description provided for @inventoryCheck.
  ///
  /// In vi, this message translates to:
  /// **'Kiểm kho'**
  String get inventoryCheck;

  /// No description provided for @goodsReceipt.
  ///
  /// In vi, this message translates to:
  /// **'Nhập hàng'**
  String get goodsReceipt;

  /// No description provided for @partners.
  ///
  /// In vi, this message translates to:
  /// **'Đối tác'**
  String get partners;

  /// No description provided for @suppliers.
  ///
  /// In vi, this message translates to:
  /// **'Nhà cung cấp'**
  String get suppliers;

  /// No description provided for @taxAndAccounting.
  ///
  /// In vi, this message translates to:
  /// **'Thuế & Kế toán'**
  String get taxAndAccounting;

  /// No description provided for @branchManagement.
  ///
  /// In vi, this message translates to:
  /// **'Chi nhánh'**
  String get branchManagement;

  /// No description provided for @advancedFeatures.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng nâng cao'**
  String get advancedFeatures;

  /// No description provided for @appAccount.
  ///
  /// In vi, this message translates to:
  /// **'Tài khoản app'**
  String get appAccount;

  /// No description provided for @bizmate.
  ///
  /// In vi, this message translates to:
  /// **'BizMate'**
  String get bizmate;

  /// No description provided for @home.
  ///
  /// In vi, this message translates to:
  /// **'Trang chủ'**
  String get home;

  /// No description provided for @sales.
  ///
  /// In vi, this message translates to:
  /// **'Bán hàng'**
  String get sales;

  /// No description provided for @employees.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get employees;

  /// No description provided for @guideTouchHint.
  ///
  /// In vi, this message translates to:
  /// **'Chạm vào đây để xem danh sách hướng dẫn: bán hàng, nhập kho, thêm sản phẩm.'**
  String get guideTouchHint;

  /// No description provided for @registrationEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã bật cho phép nhân viên đăng ký'**
  String get registrationEnabled;

  /// No description provided for @registrationDisabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã tắt cho phép nhân viên đăng ký'**
  String get registrationDisabled;

  /// No description provided for @accountInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin tài khoản'**
  String get accountInfo;

  /// No description provided for @loginEmail.
  ///
  /// In vi, this message translates to:
  /// **'Email đăng nhập'**
  String get loginEmail;

  /// No description provided for @servicePackage.
  ///
  /// In vi, this message translates to:
  /// **'Gói dịch vụ'**
  String get servicePackage;

  /// No description provided for @packagePro.
  ///
  /// In vi, this message translates to:
  /// **'Gói dịch vụ: PRO'**
  String get packagePro;

  /// No description provided for @packageBasic.
  ///
  /// In vi, this message translates to:
  /// **'Gói dịch vụ: BASIC'**
  String get packageBasic;

  /// No description provided for @cloudSyncEnabled.
  ///
  /// In vi, this message translates to:
  /// **'Đã mở khóa đồng bộ Cloud và tính năng Real-time.'**
  String get cloudSyncEnabled;

  /// No description provided for @offlineOnly.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ Offline-only.'**
  String get offlineOnly;

  /// No description provided for @logoutReloginHint.
  ///
  /// In vi, this message translates to:
  /// **'Nếu bạn vừa được gia hạn/nâng cấp gói, hãy đăng xuất rồi đăng nhập lại để áp dụng.'**
  String get logoutReloginHint;

  /// No description provided for @goHome.
  ///
  /// In vi, this message translates to:
  /// **'Về trang chủ'**
  String get goHome;

  /// No description provided for @shopName.
  ///
  /// In vi, this message translates to:
  /// **'Tên shop'**
  String get shopName;

  /// No description provided for @pleaseEnterShopName.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên shop'**
  String get pleaseEnterShopName;

  /// No description provided for @phone.
  ///
  /// In vi, this message translates to:
  /// **'Số điện thoại'**
  String get phone;

  /// No description provided for @address.
  ///
  /// In vi, this message translates to:
  /// **'Địa chỉ'**
  String get address;

  /// No description provided for @website.
  ///
  /// In vi, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @shopLogo.
  ///
  /// In vi, this message translates to:
  /// **'Logo cửa hàng'**
  String get shopLogo;

  /// No description provided for @logoOnInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Logo hiển thị trên đầu hóa đơn in.'**
  String get logoOnInvoice;

  /// No description provided for @uploading.
  ///
  /// In vi, this message translates to:
  /// **'Đang tải...'**
  String get uploading;

  /// No description provided for @selectLogo.
  ///
  /// In vi, this message translates to:
  /// **'Chọn logo'**
  String get selectLogo;

  /// No description provided for @branchManagementTile.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý chi nhánh'**
  String get branchManagementTile;

  /// No description provided for @branchManagementSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm, sửa, xóa các chi nhánh cửa hàng'**
  String get branchManagementSubtitle;

  /// No description provided for @paymentConfigTile.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình thanh toán'**
  String get paymentConfigTile;

  /// No description provided for @configured.
  ///
  /// In vi, this message translates to:
  /// **'Đã cấu hình'**
  String get configured;

  /// No description provided for @notConfigured.
  ///
  /// In vi, this message translates to:
  /// **'Chưa cấu hình'**
  String get notConfigured;

  /// No description provided for @setup.
  ///
  /// In vi, this message translates to:
  /// **'Thiết lập'**
  String get setup;

  /// No description provided for @printerConfig.
  ///
  /// In vi, this message translates to:
  /// **'Cấu hình Máy in'**
  String get printerConfig;

  /// No description provided for @defaultPaperSize.
  ///
  /// In vi, this message translates to:
  /// **'Khổ giấy mặc định'**
  String get defaultPaperSize;

  /// No description provided for @paper58mm.
  ///
  /// In vi, this message translates to:
  /// **'Khổ 58mm (K58)'**
  String get paper58mm;

  /// No description provided for @paper80mm.
  ///
  /// In vi, this message translates to:
  /// **'Khổ 80mm (K80)'**
  String get paper80mm;

  /// No description provided for @copyShopId.
  ///
  /// In vi, this message translates to:
  /// **'Sao chép Shop ID'**
  String get copyShopId;

  /// No description provided for @shopIdCopied.
  ///
  /// In vi, this message translates to:
  /// **'Đã sao chép Shop ID vào clipboard'**
  String get shopIdCopied;

  /// No description provided for @viewQr.
  ///
  /// In vi, this message translates to:
  /// **'Xem QR'**
  String get viewQr;

  /// No description provided for @shopQrCode.
  ///
  /// In vi, this message translates to:
  /// **'Mã QR Cửa hàng'**
  String get shopQrCode;

  /// No description provided for @noShopId.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có Shop ID'**
  String get noShopId;

  /// No description provided for @staffShopIdHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên có thể dùng Shop ID này để đăng ký tài khoản'**
  String get staffShopIdHint;

  /// No description provided for @guideList.
  ///
  /// In vi, this message translates to:
  /// **'Xem hướng dẫn bán hàng, nhập kho, thêm sản phẩm'**
  String get guideList;

  /// No description provided for @paymentFailed.
  ///
  /// In vi, this message translates to:
  /// **'Thanh toán thất bại'**
  String get paymentFailed;

  /// No description provided for @cannotCreateOrder.
  ///
  /// In vi, this message translates to:
  /// **'Không thể tạo đơn hàng'**
  String get cannotCreateOrder;

  /// No description provided for @cannotApplyDiscount.
  ///
  /// In vi, this message translates to:
  /// **'Không thể áp dụng chiết khấu'**
  String get cannotApplyDiscount;

  /// No description provided for @selectReportType.
  ///
  /// In vi, this message translates to:
  /// **'Chọn loại báo cáo'**
  String get selectReportType;

  /// No description provided for @revenueReportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Doanh thu và số đơn theo ngày'**
  String get revenueReportSubtitle;

  /// No description provided for @profitReportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Doanh thu, giá vốn, lợi nhuận theo ngày/tháng'**
  String get profitReportSubtitle;

  /// No description provided for @invoiceTabName.
  ///
  /// In vi, this message translates to:
  /// **'Hóa đơn {n}'**
  String invoiceTabName(Object n);

  /// No description provided for @tutorialOrderSuccess.
  ///
  /// In vi, this message translates to:
  /// **'Hoàn thành đơn hàng mẫu thành công!'**
  String get tutorialOrderSuccess;

  /// No description provided for @qrTransferManualConfirm.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng tự kiểm tra xác nhận thanh toán từ khách hàng trước khi hoàn tất đơn hàng.'**
  String get qrTransferManualConfirm;

  /// No description provided for @openInvoice.
  ///
  /// In vi, this message translates to:
  /// **'Mở hóa đơn'**
  String get openInvoice;

  /// No description provided for @mainBranch.
  ///
  /// In vi, this message translates to:
  /// **'Cửa hàng chính'**
  String get mainBranch;

  /// No description provided for @noBranchSelected.
  ///
  /// In vi, this message translates to:
  /// **'Chưa chọn chi nhánh'**
  String get noBranchSelected;

  /// No description provided for @pleaseSelectBranch.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn chi nhánh'**
  String get pleaseSelectBranch;

  /// No description provided for @staffLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nhân viên'**
  String get staffLabel;

  /// No description provided for @tutorialModeHint.
  ///
  /// In vi, this message translates to:
  /// **'Bạn đang ở chế độ hướng dẫn - Dữ liệu sẽ không được lưu'**
  String get tutorialModeHint;

  /// No description provided for @emptyCartHint.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có sản phẩm nào trong giỏ hàng'**
  String get emptyCartHint;

  /// No description provided for @pressAddProductHint.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn \"Thêm sản phẩm\" để chọn hàng'**
  String get pressAddProductHint;

  /// No description provided for @customerInfo.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin khách hàng'**
  String get customerInfo;

  /// No description provided for @taxCodeForInvoice.
  ///
  /// In vi, this message translates to:
  /// **'MST (xuất hóa đơn)'**
  String get taxCodeForInvoice;

  /// No description provided for @branchLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chi nhánh: '**
  String get branchLabel;

  /// No description provided for @staffShortLabel.
  ///
  /// In vi, this message translates to:
  /// **'NV: '**
  String get staffShortLabel;

  /// No description provided for @searchProductHint.
  ///
  /// In vi, this message translates to:
  /// **'Tìm sản phẩm (F2) - quét mã vạch hoặc nhập tên...'**
  String get searchProductHint;

  /// No description provided for @deleteHeader.
  ///
  /// In vi, this message translates to:
  /// **'Xóa'**
  String get deleteHeader;

  /// No description provided for @unitHeader.
  ///
  /// In vi, this message translates to:
  /// **'ĐVT'**
  String get unitHeader;

  /// No description provided for @unitPriceHeader.
  ///
  /// In vi, this message translates to:
  /// **'Đơn giá'**
  String get unitPriceHeader;

  /// No description provided for @amountHeader.
  ///
  /// In vi, this message translates to:
  /// **'Thành tiền'**
  String get amountHeader;

  /// No description provided for @printLabel.
  ///
  /// In vi, this message translates to:
  /// **'In'**
  String get printLabel;

  /// No description provided for @selectPriceList.
  ///
  /// In vi, this message translates to:
  /// **'Chọn bảng giá'**
  String get selectPriceList;

  /// No description provided for @deliveryLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giao hàng'**
  String get deliveryLabel;

  /// No description provided for @pressCartToPay.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn nút Giỏ hàng ở góc dưới để xem và thanh toán'**
  String get pressCartToPay;

  /// No description provided for @confirmLabel.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận'**
  String get confirmLabel;

  /// No description provided for @totalBeforeDiscount.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tiền hàng'**
  String get totalBeforeDiscount;

  /// No description provided for @discountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Giảm giá'**
  String get discountLabel;

  /// No description provided for @tapToAdd.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn để thêm'**
  String get tapToAdd;

  /// No description provided for @taxLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thuế'**
  String get taxLabel;

  /// No description provided for @totalLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tổng cộng'**
  String get totalLabel;

  /// No description provided for @customerToPay.
  ///
  /// In vi, this message translates to:
  /// **'KHÁCH CẦN TRẢ'**
  String get customerToPay;

  /// No description provided for @payButtonShort.
  ///
  /// In vi, this message translates to:
  /// **'THANH TOÁN (F9)'**
  String get payButtonShort;

  /// No description provided for @enterQuantity.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số lượng'**
  String get enterQuantity;

  /// No description provided for @sellPriceVnd.
  ///
  /// In vi, this message translates to:
  /// **'Giá bán (VNĐ)'**
  String get sellPriceVnd;

  /// No description provided for @enterSellPrice.
  ///
  /// In vi, this message translates to:
  /// **'Nhập giá bán'**
  String get enterSellPrice;

  /// No description provided for @discountLabelShort.
  ///
  /// In vi, this message translates to:
  /// **'Chiết khấu'**
  String get discountLabelShort;

  /// No description provided for @vnd.
  ///
  /// In vi, this message translates to:
  /// **'VNĐ'**
  String get vnd;

  /// No description provided for @enterPercentExample.
  ///
  /// In vi, this message translates to:
  /// **'Nhập % (ví dụ: 10)'**
  String get enterPercentExample;

  /// No description provided for @enterAmountExample.
  ///
  /// In vi, this message translates to:
  /// **'Nhập số tiền (ví dụ: 50000)'**
  String get enterAmountExample;

  /// No description provided for @orderDiscountTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chiết khấu đơn hàng'**
  String get orderDiscountTitle;

  /// No description provided for @percentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phần trăm (%)'**
  String get percentLabel;

  /// No description provided for @amountVnd.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền (VNĐ)'**
  String get amountVnd;

  /// No description provided for @discountPercentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Phần trăm giảm giá (%)'**
  String get discountPercentLabel;

  /// No description provided for @discountAmountLabel.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền giảm giá (VNĐ)'**
  String get discountAmountLabel;

  /// No description provided for @discountExceedsThreshold.
  ///
  /// In vi, this message translates to:
  /// **'Chiết khấu {percent}% vượt quá ngưỡng cho phép (10%).'**
  String discountExceedsThreshold(Object percent);

  /// No description provided for @onlyAdminCanApprove.
  ///
  /// In vi, this message translates to:
  /// **'Chỉ Admin/Manager mới có quyền phê duyệt chiết khấu này.'**
  String get onlyAdminCanApprove;

  /// No description provided for @searchProduct.
  ///
  /// In vi, this message translates to:
  /// **'Tìm kiếm sản phẩm...'**
  String get searchProduct;

  /// No description provided for @backToList.
  ///
  /// In vi, this message translates to:
  /// **'Xem lại danh sách sản phẩm'**
  String get backToList;

  /// No description provided for @backTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Quay lại'**
  String get backTooltip;

  /// No description provided for @totalToPay.
  ///
  /// In vi, this message translates to:
  /// **'Tổng cộng cần thanh toán'**
  String get totalToPay;

  /// No description provided for @defaultUnit.
  ///
  /// In vi, this message translates to:
  /// **'Cái'**
  String get defaultUnit;

  /// No description provided for @customerName.
  ///
  /// In vi, this message translates to:
  /// **'Tên khách hàng'**
  String get customerName;

  /// No description provided for @defaultAddress.
  ///
  /// In vi, this message translates to:
  /// **'Quận 1 - TP. Hồ Chí Minh'**
  String get defaultAddress;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
