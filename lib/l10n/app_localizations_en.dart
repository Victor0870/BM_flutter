// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BizMate POS';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get register => 'Register';

  @override
  String get taxCode => 'Tax Code';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get loginToAccount => 'Login to your account';

  @override
  String get registerOwner => 'Register as Store Owner';

  @override
  String get registerStaff => 'Register as Staff';

  @override
  String get ownerChip => 'Owner';

  @override
  String get staffChip => 'Staff';

  @override
  String get shopId => 'Shop ID';

  @override
  String get shopIdHint => 'Enter or scan Shop ID';

  @override
  String get shopIdHintDesktop => 'Enter store Shop ID';

  @override
  String get scanShopQr => 'Scan shop QR code';

  @override
  String get scanShopQrTitle => 'Scan shop QR code';

  @override
  String get close => 'Close';

  @override
  String get rememberPassword => 'Remember password';

  @override
  String get rememberAccount => 'Remember account';

  @override
  String get noAccountRegister => 'Don\'t have an account? Register now';

  @override
  String get haveAccountLogin => 'Already have an account? Login';

  @override
  String get pleaseEnterEmail => 'Please enter email';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get pleaseEnterPassword => 'Please enter password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get pleaseConfirmPassword => 'Please confirm password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get pleaseEnterShopId => 'Please enter or scan store Shop ID';

  @override
  String get pleaseEnterShopIdDesktop => 'Please enter store Shop ID';

  @override
  String get firebaseNotReady =>
      'Firebase is not ready. Please try again later.';

  @override
  String get loginSuccess => 'Login successful!';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get registerSuccess => 'Registration successful! Creating store...';

  @override
  String get registerSuccessStaff =>
      'Registration successful, please wait for Admin approval.';

  @override
  String get registerFailed => 'Registration failed';

  @override
  String get initializingFirebase => 'Initializing Firebase...';

  @override
  String get selectColumns => 'Select columns to display';

  @override
  String get productCode => 'Product code';

  @override
  String get productName => 'Product name';

  @override
  String get category => 'Category';

  @override
  String get sellPrice => 'Sell price';

  @override
  String get costPrice => 'Cost price';

  @override
  String get stock => 'Stock';

  @override
  String get customerOrder => 'Customer order';

  @override
  String get createdAt => 'Created at';

  @override
  String get expiry => 'Expected expiry';

  @override
  String get isSellable => 'Selling';

  @override
  String get productSellEnabled => 'Product selling enabled';

  @override
  String get productSellDisabled => 'Product selling disabled';

  @override
  String errorOnUpdate(Object error) {
    return 'Error on update: $error';
  }

  @override
  String get pleaseSelectBranchToUpdateStock =>
      'Please select a branch to update stock.';

  @override
  String get updateStock => 'Update stock';

  @override
  String get quickUpdateDisabledMessage =>
      'Quick update is disabled. Please use \'Purchase order\' to adjust quantity.';

  @override
  String get goToPurchase => 'Go to Purchase order';

  @override
  String get newQuantity => 'New quantity';

  @override
  String get cancel => 'Cancel';

  @override
  String get update => 'Update';

  @override
  String get invalidQuantity => 'Invalid quantity';

  @override
  String get quantityUnchanged => 'Quantity unchanged';

  @override
  String stockUpdated(Object productName) {
    return 'Stock updated for $productName';
  }

  @override
  String get errorUpdateStock => 'Error updating stock';

  @override
  String errorGeneric(Object error) {
    return 'Error: $error';
  }

  @override
  String get confirmDelete => 'Confirm delete';

  @override
  String confirmDeleteProduct(Object productName) {
    return 'Are you sure you want to delete product \"$productName\"? It will be moved to inactive status.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get productDeleted => 'Product deleted';

  @override
  String errorOnDelete(Object error) {
    return 'Error on delete: $error';
  }

  @override
  String get apply => 'Apply';

  @override
  String get allCategories => 'All categories';

  @override
  String get all => 'All';

  @override
  String get inStock => 'In stock';

  @override
  String get lowStock => 'Low stock';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String get searchByNameSku => 'Search by name, SKU or barcode...';

  @override
  String get searchByCodeNameSku => 'Search by code, name, SKU...';

  @override
  String get selectCategory => 'Select category';

  @override
  String get createNew => 'Create new';

  @override
  String get productList => 'Product list';

  @override
  String get addProduct => 'Add product';

  @override
  String get addCategory => 'Add category';

  @override
  String get addProductShort => 'product';

  @override
  String get addCategoryShort => 'category';

  @override
  String get importExcel => 'Import Excel';

  @override
  String get retry => 'Retry';

  @override
  String get loadMore => 'Load more';

  @override
  String get allTime => 'All time';

  @override
  String get customDate => 'Custom date...';

  @override
  String get advancedFilter => 'Advanced filter';

  @override
  String get resetFilter => 'Reset filter';

  @override
  String get searchCategory => 'Search category...';

  @override
  String get allCategoriesFilter => 'All categories';

  @override
  String get stockStatus => 'Stock status';

  @override
  String get warehouseLocation => 'Warehouse location';

  @override
  String get selectLocation => 'Select location';

  @override
  String get extraOptions => 'Extra options';

  @override
  String get points => 'POINTS';

  @override
  String get directSale => 'DIRECT SALE';

  @override
  String get channelLink => 'CHANNEL LINK';

  @override
  String get productStatus => 'Product status';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get description => 'Description, notes';

  @override
  String get stockTag => 'Stock tag';

  @override
  String get copy => 'Copy';

  @override
  String get edit => 'Edit';

  @override
  String get branch => 'Branch';

  @override
  String get status => 'Status';

  @override
  String get total => 'Total';

  @override
  String get unclassified => 'Unclassified';

  @override
  String get regularProduct => 'Regular product';

  @override
  String get directSell => 'Direct sell';

  @override
  String get noDirectSell => 'No direct sell';

  @override
  String get pointsChip => 'Points';

  @override
  String get searchBranchName => 'Search branch name';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get stopSelling => 'Stop selling';

  @override
  String get unit => 'Unit';

  @override
  String get barcode => 'Barcode';

  @override
  String get brand => 'Brand';

  @override
  String get version => 'Version';

  @override
  String get noVersion => 'None';

  @override
  String get minStockLabel => 'Stock level';

  @override
  String get location => 'Location';

  @override
  String get quickUpdateFromList => 'Quick update from product list';

  @override
  String currentStock(Object value) {
    return 'Current stock: $value';
  }

  @override
  String get customerManagement => 'Customer management';

  @override
  String get allGroups => 'All groups';

  @override
  String get deactivate => 'Deactivate';

  @override
  String contentUpdating(Object label) {
    return 'Content $label is updating';
  }

  @override
  String get noDebt => 'Customer has no debt to collect';

  @override
  String get currentDebt => 'Current debt';

  @override
  String get viewAnalysis => 'View analysis';

  @override
  String get chooseBranch => 'Choose branch';

  @override
  String get allGroupsFilter => 'All groups';

  @override
  String get custom => 'Custom';

  @override
  String get productNotFound => 'Product not found';

  @override
  String get noBatchAtBranch => 'No batches available at this branch';

  @override
  String addedToCart(Object batch, Object productName) {
    return 'Added $productName — Batch $batch to cart';
  }

  @override
  String addedToCartSimple(Object productName) {
    return 'Added $productName to cart';
  }

  @override
  String get selectBatch => 'Select batch';

  @override
  String get existingBatches => 'Existing batches:';

  @override
  String get addToCart => 'Add to cart';

  @override
  String quantityExceedsBatch(Object quantity) {
    return 'Quantity exceeds batch stock ($quantity)';
  }

  @override
  String get emptyCart => 'Empty cart';

  @override
  String get selectPaymentMethod => 'Select payment method';

  @override
  String get cash => 'Cash';

  @override
  String get qrTransfer => 'QR Transfer';

  @override
  String get confirmPayment => 'Confirm payment';

  @override
  String totalAmount(Object amount) {
    return 'Total: $amount đ';
  }

  @override
  String get paymentMethodCash => 'Method: Cash';

  @override
  String get confirm => 'Confirm';

  @override
  String get qrPayment => 'Transfer payment';

  @override
  String get createOrder => 'Create order';

  @override
  String get orderCreatedMessage =>
      'Order created. Please check your account and confirm when payment is received.';

  @override
  String get cannotCreateQr =>
      'Cannot create QR code. Please check payment settings in Settings.';

  @override
  String get paymentSuccessEinvoice =>
      'Payment successful! Electronic invoice created.';

  @override
  String cannotOpenLink(Object error) {
    return 'Cannot open link: $error';
  }

  @override
  String get paymentSuccess => 'Payment successful!';

  @override
  String get exit => 'Exit';

  @override
  String get totalAmountLabel => 'Subtotal';

  @override
  String get pay => 'Pay';

  @override
  String get customer => 'Customer';

  @override
  String get promotion => 'Promotion';

  @override
  String get done => 'Done';

  @override
  String get featureInDevelopment => 'Feature in development';

  @override
  String get addProductToCart => 'Add product to cart';

  @override
  String get quantity => 'Quantity';

  @override
  String get removeDiscount => 'Remove discount';

  @override
  String get priceCannotBeNegative => 'Price cannot be negative';

  @override
  String get discountCannotBeNegative => 'Discount cannot be negative';

  @override
  String get discountPercentExceeds100 =>
      'Discount percentage cannot exceed 100%';

  @override
  String get approvalRequired => 'Approval required';

  @override
  String get selectProduct => 'Select product';

  @override
  String get productOutOfStock => 'Product temporarily out of stock';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get checkout => 'CHECKOUT';

  @override
  String errorSaveSettings(Object error) {
    return 'Error saving settings: $error';
  }

  @override
  String get settingsSaved => 'Settings saved successfully!';

  @override
  String get logoUploadSuccess =>
      'Logo uploaded successfully. It will appear on invoices.';

  @override
  String logoUploadError(Object error) {
    return 'Error uploading logo: $error';
  }

  @override
  String get userGuide => 'User guide';

  @override
  String get salesGuide => 'Sales guide';

  @override
  String get purchaseGuide => 'Purchase guide';

  @override
  String get purchaseGuideUpdating => 'Purchase guide is being updated.';

  @override
  String get addProductGuide => 'Add product guide';

  @override
  String get addProductGuideUpdating => 'Add product guide is being updated.';

  @override
  String get paymentConfig => 'Payment configuration';

  @override
  String get autoConfirmPayment => 'Auto confirm payment received';

  @override
  String get save => 'Save';

  @override
  String get eInvoiceConfig => 'Electronic invoice configuration';

  @override
  String get contactAdminUpgrade =>
      'Contact administrator to upgrade to PRO package.';

  @override
  String get upgrade => 'Upgrade';

  @override
  String get shopSettings => 'Shop settings';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get featureInDev => 'Feature in development';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get vietnamese => 'Tiếng Việt';

  @override
  String get english => 'English';

  @override
  String get overview => 'Overview';

  @override
  String get needSupport => 'NEED SUPPORT?';

  @override
  String get contactTechTeam => 'Contact our tech team now.';

  @override
  String get sendRequest => 'Send request';

  @override
  String get orders => 'Orders';

  @override
  String get salesInvoice => 'Sales invoice';

  @override
  String get returnInvoice => 'Return invoice';

  @override
  String get cancelInvoice => 'Cancel invoice';

  @override
  String get eInvoice => 'E-invoice';

  @override
  String get products => 'Products';

  @override
  String get productGroup => 'Product group';

  @override
  String get serviceList => 'Service list';

  @override
  String get serviceGroup => 'Service group';

  @override
  String get inventoryManagement => 'Inventory';

  @override
  String get stockOverview => 'Stock';

  @override
  String get purchase => 'Purchase';

  @override
  String get transferStock => 'Transfer stock';

  @override
  String get adjustStock => 'Adjust stock';

  @override
  String get customers => 'Customers';

  @override
  String get customerList => 'Customer list';

  @override
  String get customerGroup => 'Customer group';

  @override
  String get staffManagement => 'Staff management';

  @override
  String get employeeList => 'Employee list';

  @override
  String get employeeGroup => 'Employee group';

  @override
  String get reports => 'Reports';

  @override
  String get salesReport => 'Sales report';

  @override
  String get profitReport => 'Profit report';

  @override
  String get stockMovementReport => 'Stock movement report';

  @override
  String get debtReport => 'Debt report';

  @override
  String get salesReturnReport => 'Sales return report';

  @override
  String get lowStockReport => 'Low stock report';

  @override
  String get expiryReport => 'Expiring soon';

  @override
  String get settings => 'Settings';

  @override
  String get more => 'More';

  @override
  String get shopInfo => 'Shop info';

  @override
  String get generalSettings => 'General settings';

  @override
  String get storeSetup => 'Store setup';

  @override
  String get transactions => 'Transactions';

  @override
  String get invoices => 'Invoices';

  @override
  String get returns => 'Returns';

  @override
  String get cashBook => 'Cash book';

  @override
  String get goods => 'Goods';

  @override
  String get inventoryCheck => 'Inventory check';

  @override
  String get goodsReceipt => 'Goods receipt';

  @override
  String get partners => 'Partners';

  @override
  String get suppliers => 'Suppliers';

  @override
  String get taxAndAccounting => 'Tax & Accounting';

  @override
  String get branchManagement => 'Branch';

  @override
  String get advancedFeatures => 'Advanced features';

  @override
  String get appAccount => 'App account';

  @override
  String get bizmate => 'BizMate';

  @override
  String get home => 'Home';

  @override
  String get sales => 'Sales';

  @override
  String get employees => 'Employees';

  @override
  String get guideTouchHint =>
      'Tap here to view guides: sales, purchase, add product.';

  @override
  String get registrationEnabled => 'Staff registration enabled';

  @override
  String get registrationDisabled => 'Staff registration disabled';

  @override
  String get accountInfo => 'Account info';

  @override
  String get loginEmail => 'Login email';

  @override
  String get servicePackage => 'Service package';

  @override
  String get packagePro => 'Package: PRO';

  @override
  String get packageBasic => 'Package: BASIC';

  @override
  String get cloudSyncEnabled => 'Cloud sync and Real-time features unlocked.';

  @override
  String get offlineOnly => 'Offline-only mode.';

  @override
  String get logoutReloginHint =>
      'If you just renewed/upgraded, please logout and login again to apply.';

  @override
  String get goHome => 'Go home';

  @override
  String get shopName => 'Shop name';

  @override
  String get pleaseEnterShopName => 'Please enter shop name';

  @override
  String get phone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get website => 'Website';

  @override
  String get shopLogo => 'Shop logo';

  @override
  String get logoOnInvoice => 'Logo displays at the top of printed invoices.';

  @override
  String get uploading => 'Uploading...';

  @override
  String get selectLogo => 'Select logo';

  @override
  String get branchManagementTile => 'Branch management';

  @override
  String get branchManagementSubtitle => 'Add, edit, delete shop branches';

  @override
  String get paymentConfigTile => 'Payment configuration';

  @override
  String get configured => 'Configured';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get setup => 'Setup';

  @override
  String get printerConfig => 'Printer configuration';

  @override
  String get defaultPaperSize => 'Default paper size';

  @override
  String get paper58mm => '58mm (K58)';

  @override
  String get paper80mm => '80mm (K80)';

  @override
  String get copyShopId => 'Copy Shop ID';

  @override
  String get shopIdCopied => 'Shop ID copied to clipboard';

  @override
  String get viewQr => 'View QR';

  @override
  String get shopQrCode => 'Shop QR Code';

  @override
  String get noShopId => 'No Shop ID';

  @override
  String get staffShopIdHint => 'Staff can use this Shop ID to register';

  @override
  String get guideList => 'View sales, purchase, add product guides';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get cannotCreateOrder => 'Cannot create order';

  @override
  String get cannotApplyDiscount => 'Cannot apply discount';

  @override
  String get selectReportType => 'Select report type';

  @override
  String get revenueReportSubtitle => 'Revenue and order count by day';

  @override
  String get profitReportSubtitle => 'Revenue, cost, profit by day/month';

  @override
  String invoiceTabName(Object n) {
    return 'Invoice $n';
  }

  @override
  String get tutorialOrderSuccess => 'Sample order completed successfully!';

  @override
  String get qrTransferManualConfirm =>
      'Please verify payment confirmation from customer before completing order.';

  @override
  String get openInvoice => 'Open invoice';

  @override
  String get mainBranch => 'Main branch';

  @override
  String get noBranchSelected => 'No branch selected';

  @override
  String get pleaseSelectBranch => 'Please select branch';

  @override
  String get staffLabel => 'Staff';

  @override
  String get tutorialModeHint =>
      'You are in tutorial mode - Data will not be saved';

  @override
  String get emptyCartHint => 'No products in cart';

  @override
  String get pressAddProductHint => 'Press \"Add product\" to select items';

  @override
  String get customerInfo => 'Customer info';

  @override
  String get taxCodeForInvoice => 'Tax code (for invoice)';

  @override
  String get branchLabel => 'Branch: ';

  @override
  String get staffShortLabel => 'Staff: ';

  @override
  String get searchProductHint =>
      'Search product (F2) - scan barcode or type name...';

  @override
  String get deleteHeader => 'Delete';

  @override
  String get unitHeader => 'Unit';

  @override
  String get unitPriceHeader => 'Unit price';

  @override
  String get amountHeader => 'Amount';

  @override
  String get printLabel => 'Print';

  @override
  String get selectPriceList => 'Select price list';

  @override
  String get deliveryLabel => 'Delivery';

  @override
  String get pressCartToPay => 'Press Cart button below to view and pay';

  @override
  String get confirmLabel => 'Confirm';

  @override
  String get totalBeforeDiscount => 'Subtotal';

  @override
  String get discountLabel => 'Discount';

  @override
  String get tapToAdd => 'Tap to add';

  @override
  String get taxLabel => 'Tax';

  @override
  String get totalLabel => 'Total';

  @override
  String get customerToPay => 'AMOUNT DUE';

  @override
  String get payButtonShort => 'PAY (F9)';

  @override
  String get enterQuantity => 'Enter quantity';

  @override
  String get sellPriceVnd => 'Sell price (VND)';

  @override
  String get enterSellPrice => 'Enter sell price';

  @override
  String get discountLabelShort => 'Discount';

  @override
  String get vnd => 'VND';

  @override
  String get enterPercentExample => 'Enter % (e.g. 10)';

  @override
  String get enterAmountExample => 'Enter amount (e.g. 50000)';

  @override
  String get orderDiscountTitle => 'Order discount';

  @override
  String get percentLabel => 'Percent (%)';

  @override
  String get amountVnd => 'Amount (VND)';

  @override
  String get discountPercentLabel => 'Discount percent (%)';

  @override
  String get discountAmountLabel => 'Discount amount (VND)';

  @override
  String discountExceedsThreshold(Object percent) {
    return 'Discount $percent% exceeds allowed threshold (10%).';
  }

  @override
  String get onlyAdminCanApprove =>
      'Only Admin/Manager can approve this discount.';

  @override
  String get searchProduct => 'Search product...';

  @override
  String get backToList => 'Back to product list';

  @override
  String get backTooltip => 'Back';

  @override
  String get totalToPay => 'Total to pay';

  @override
  String get defaultUnit => 'pcs';

  @override
  String get customerName => 'Customer name';

  @override
  String get defaultAddress => 'District 1 - Ho Chi Minh City';
}
