/// Tafsiri za mfumo — Kiswahili na English
/// Ongeza maneno mapya hapa kwa lugha zote mbili

enum AppLang { sw, en }

class S {
  static AppLang _lang = AppLang.sw;

  static AppLang get lang => _lang;

  static void setLang(AppLang l) => _lang = l;

  static bool get isSwahili => _lang == AppLang.sw;

  static String t(String sw, String en) => _lang == AppLang.sw ? sw : en;

  // ════════════════════════════════════════════════
  // JUMLA / GENERAL
  // ════════════════════════════════════════════════
  static String get appName        => t('Maktaba ya Vitabu', 'Book Library');
  static String get back           => t('Rudi', 'Back');
  static String get retry          => t('Jaribu Tena', 'Try Again');
  static String get save           => t('Hifadhi', 'Save');
  static String get cancel         => t('Ghairi', 'Cancel');
  static String get delete         => t('Futa', 'Delete');
  static String get close          => t('Funga', 'Close');
  static String get search         => t('Tafuta', 'Search');
  static String get loading        => t('Inapakia...', 'Loading...');
  static String get error          => t('Hitilafu', 'Error');
  static String get success        => t('Umefanikiwa', 'Success');
  static String get free           => t('Bure', 'Free');
  static String get bure           => t('Bure Kabisa', 'Completely Free');
  static String get buy            => t('Nunua', 'Buy');
  static String get yes            => t('Ndio', 'Yes');
  static String get no             => t('Hapana', 'No');
  static String get ok             => t('Sawa', 'OK');
  static String get books          => t('Vitabu', 'Books');
  static String get book           => t('Kitabu', 'Book');
  static String get failedSave     => t('Imeshindwa kuhifadhi', 'Failed to save');
  static String get remove         => t('Toa', 'Remove');

  // ════════════════════════════════════════════════
  // AUTH — LOGIN / REGISTER
  // ════════════════════════════════════════════════
  static String get login          => t('Ingia', 'Login');
  static String get logout         => t('Toka', 'Logout');
  static String get register       => t('Jisajili', 'Register');
  static String get username       => t('Jina la Mtumiaji', 'Username');
  static String get password       => t('Nywila', 'Password');
  static String get welcomeBack    => t('Karibu tena!', 'Welcome back!');
  static String get enterDetails   => t('Ingiza taarifa zako kuendelea', 'Enter your details to continue');
  static String get noAccount      => t('Huna akaunti? ', "Don't have an account? ");
  static String get hasAccount     => t('Una akaunti? ', 'Have an account? ');
  static String get usernameReq    => t('Jina linahitajika', 'Username is required');
  static String get passwordReq    => t('Nywila inahitajika', 'Password is required');
  static String get passwordMinReq => t('Nywila lazima iwe herufi 6+', 'Password must be at least 6 characters');
  static String get loginTo        => t('Ingia ili kuendelea kusoma', 'Login to continue reading');
  static String get loginHere      => t('Ingia Hapa', 'Login Here');
  static String get discoverBooks  => t('Gundua Vitabu Vipya', 'Discover New Books');
  static String get learnGrow      => t('Soma vitabu, ujifunze, ukue', 'Read books, learn, grow');
  static String get role           => t('Chagua Nafsi Yako', 'Choose Your Role');
  static String get reader         => t('Msomaji', 'Reader');
  static String get author         => t('Mwandishi', 'Author');
  static String get readerDesc     => t('Soma vitabu na ujifunze', 'Read books and learn');
  static String get authorDesc     => t('Chapisha na uuze vitabu', 'Publish and sell books');
  static String get createAccount  => t('Tengeneza Akaunti', 'Create Account');
  static String get createAccountSub => t('Tengeneza akaunti mpya', 'Create a new account');
  static String get chooseAccountType => t('Chagua aina ya akaunti', 'Choose account type');
  static String get orContinueWith     => t('AU', 'OR');
  static String get continueWithGoogle => t('Ingia kwa Google', 'Continue with Google');

  // ════════════════════════════════════════════════
  // AUTH — EMAIL/SIMU + OTP
  // ════════════════════════════════════════════════
  static String get emailOrPhone     => t('Email au Namba ya Simu', 'Email or Phone Number');
  static String get emailOrPhoneReq  => t('Email au namba ya simu inahitajika', 'Email or phone number is required');
  static String get invalidEmailOrPhone => t('Weka email sahihi au namba ya simu sahihi (mfano: +255712345678)', 'Enter a valid email or phone number (e.g. +255712345678)');
  static String get usernameOrContact => t('Jina, Email au Simu', 'Username, Email or Phone');
  static String get otpTitle         => t('Thibitisha Akaunti', 'Verify Account');
  static String get otpSentTo        => t('Tumetuma nambari ya uthibitisho (OTP) kwa', 'We sent a verification code (OTP) to');
  static String get enterOtpCode     => t('Weka Nambari ya OTP', 'Enter OTP Code');
  static String get otpCodeReq       => t('Nambari ya OTP inahitajika', 'OTP code is required');
  static String get verifyOtpBtn     => t('Thibitisha', 'Verify');
  static String get resendOtpBtn     => t('Tuma Tena', 'Resend');
  static String get resendIn         => t('Tuma Tena baada ya', 'Resend in');
  static String get otpResent        => t('Nambari mpya ya OTP imetumwa.', 'A new OTP code has been sent.');
  static String get registrationOtpSent => t('Usajili umefanikiwa. Tumetuma nambari ya OTP kwenye email yako.', 'Registration successful. We sent an OTP code to your email.');
  static String get accountNotVerified => t('Akaunti yako bado haijathibitishwa. Tumia OTP iliyotumwa kwenye email yako.', 'Your account is not verified yet. Use the OTP sent to your email.');

  // ════════════════════════════════════════════════
  // KUSHARE KITABU / SHARE BOOK
  // ════════════════════════════════════════════════
  static String get shareBook       => t('Shiriki Kitabu', 'Share Book');
  static String get copyLink        => t('Nakili Link', 'Copy Link');
  static String get linkCopied      => t('Link imenakiliwa!', 'Link copied!');
  static String get shareOther      => t('Njia Nyingine', 'Other Apps');
  static String get shareStats      => t('Takwimu za Kushare', 'Share Stats');
  static String get totalShareClicks => t('Jumla ya Bonyezo', 'Total Clicks');
  static String get totalSignups    => t('Watumiaji Walioandikishwa', 'Signups');

  // ════════════════════════════════════════════════
  // HOME
  // ════════════════════════════════════════════════
  static String get greeting       => t('Habari', 'Hello');
  static String get searchHint     => t('Tafuta kitabu au mwandishi...', 'Search book or author...');
  static String get browseByCategory => t('Tafuta kwa Kategoria', 'Browse by Category');
  static String get newBooks       => t('Vitabu Vipya', 'New Books');
  static String get viewAll        => t('Ona Vyote', 'View All');
  static String get allBooks       => t('Vitabu Vyote', 'All Books');
  static String get noCategory     => t('Hakuna kategoria bado.', 'No categories yet.');
  static String get library        => t('Maktaba', 'Library');
  static String get myLibrary      => t('Maktaba Yangu', 'My Library');
  static String get wallet         => t('Mkoba', 'Wallet');
  static String get subscription   => t('Usajili', 'Subscription');
  static String get profile        => t('Wasifu Wangu', 'My Profile');
  static String get uploadBook     => t('Pakia Kitabu', 'Upload Book');
  static String get librarySubtitle => t('Maktaba yenye vitabu vya aina zote', 'Library with all types of books');
  static String get home           => t('Nyumbani', 'Home');
  static String get bookStore      => t('Duka la Vitabu', 'Book Store');
  static String get bookStoreShort => t('Duka la\nVitabu', 'Book\nStore');

  // ════════════════════════════════════════════════
  // CATEGORIES
  // ════════════════════════════════════════════════
  static String get sciTech        => t('Sayansi & Teknolojia', 'Science & Technology');
  static String get history        => t('Historia & Utamaduni', 'History & Culture');
  static String get business       => t('Biashara & Uchumi', 'Business & Economics');
  static String get education      => t('Elimu & Masomo', 'Education & Study');
  static String get fiction        => t('Riwaya & Hadithi', 'Fiction & Stories');
  static String get health         => t('Afya & Maisha', 'Health & Life');
  static String get religion       => t('Dini & Imani', 'Religion & Faith');
  static String get children       => t('Watoto', 'Children');
  static String get noBooksInCat   => t('Hakuna vitabu katika', 'No books in');
  static String get comingSoon     => t('Vitabu vitaongezwa hivi karibuni', 'Books coming soon');
  static String get booksCount     => t('vitabu', 'books');
  static String get notStarted     => t('Haijaanza', 'Not started');

  // ════════════════════════════════════════════════
  // BOOK DETAIL
  // ════════════════════════════════════════════════
  static String get readText       => t('Soma Maandishi', 'Read Text');
  static String get listenAudio    => t('Sikiliza Sauti', 'Listen Audio');
  static String get noAudioMsg     => t('Kitabu hiki hakina toleo la sauti',
                                        'This book has no audio version');
  static String get aboutBook      => t('Kuhusu Kitabu', 'About This Book');
  static String get noDesc         => t('Hakuna maelezo.', 'No description.');
  static String get viewComments   => t('Angalia Maoni', 'View Comments');
  static String get textAvail      => t('Maandishi', 'Text');
  static String get audioAvail     => t('Sauti Inapatikana', 'Audio Available');
  static String get noText         => t('Hakuna Maandishi', 'No Text');
  static String get noAudio        => t('Hakuna Sauti', 'No Audio');
  static String get preparing      => t('Inaandaliwa', 'Preparing');
  static String get buyBook        => t('Nunua', 'Buy');
  static String get buyingBook     => t('Inanunua...', 'Buying...');
  static String get buySuccess     => t('Umefanikiwa kununua!', 'Purchase successful!');
  static String get noPermission   => t('Huna ruhusa. Nunua au jisajili.', 'No permission. Buy or subscribe.');
  static String get audioBook      => t('Kitabu cha Sauti', 'Audio Book');
  static String get secure         => t('Salama', 'Secure');

  // ════════════════════════════════════════════════
  // READER
  // ════════════════════════════════════════════════
  static String get openingSecure  => t('Inafungua kitabu kwa usalama...', 'Opening book securely...');
  static String get failedOpen     => t('Imeshindwa Kufungua', 'Failed to Open');
  static String get textSize       => t('Ukubwa wa Maandishi', 'Text Size');
  static String get readBook       => t('Soma Kitabu', 'Read Book');

  // ════════════════════════════════════════════════
  // AUDIO PLAYER
  // ════════════════════════════════════════════════
  static String get listenBook     => t('Sikiliza Kitabu', 'Listen to Book');
  static String get loadingAudio   => t('Inapakia sauti...', 'Loading audio...');
  static String get failedAudio    => t('Imeshindwa Kupakia Sauti', 'Failed to Load Audio');
  static String get audioHint      => t(
      'Unaweza kurudi nyuma au mbele kwa sekunde 15. Badilisha kasi kulingana na upendeleo wako.',
      'You can go back or forward 15 seconds. Adjust speed to your preference.');
  static String get speed          => t('Kasi', 'Speed');
  static String get skipBack       => t('Rudi 15s', 'Back 15s');
  static String get skipFwd        => t('Mbele 15s', 'Fwd 15s');

  // ════════════════════════════════════════════════
  // UPLOAD
  // ════════════════════════════════════════════════
  static String get uploadTitle    => t('Pakia Kitabu Kipya', 'Upload New Book');
  static String get bookTitle      => t('Jina la Kitabu *', 'Book Title *');
  static String get bookDesc       => t('Maelezo ya Kitabu *', 'Book Description *');
  static String get category       => t('Kategoria', 'Category');
  static String get anyCategory    => t('Kategoria yoyote', 'Any category');
  static String get freeBook       => t('Kitabu cha Bure', 'Free Book');
  static String get freeDesc       => t('Wasomaji watasoma bila malipo', 'Readers will read for free');
  static String get paidDesc       => t('Wasomaji watalipa bei', 'Readers will pay a fee');
  static String get addCover       => t('Bonyeza kuongeza picha ya jalada', 'Tap to add cover image');
  static String get price          => t('Bei (TZS) *', 'Price (TZS) *');
  static String get chooseBookFile => t('Chagua Faili la Kitabu *', 'Choose Book File *');
  static String get fileChosen     => t('Faili limechaguliwa', 'File chosen');
  static String get addAudio       => t('Ongeza Faili la Sauti (Si Lazima)', 'Add Audio File (Optional)');
  static String get audioChosen    => t('Sauti imechaguliwa', 'Audio file chosen');
  static String get uploading      => t('Inapakia na kusimba...', 'Uploading and encrypting...');
  static String get uploadBtn      => t('Pakia Kitabu', 'Upload Book');
  static String get uploadSuccess  => t('Kitabu kimepakiwa na kusimbwa!', 'Book uploaded and encrypted!');
  static String get encryptNote    => t(
      'Kitabu kitasimbwa kiotomatiki baada ya kupakiwa',
      'Book will be encrypted automatically after upload');
  static String get titleRequired  => t('Jina linahitajika', 'Title is required');
  static String get descRequired   => t('Maelezo yanahitajika', 'Description is required');
  static String get priceInvalid   => t('Bei si sahihi', 'Invalid price');
  static String get pickFileFirst  => t(
      'Chagua faili la kitabu kwanza (txt, pdf, au epub)',
      'Choose book file first (txt, pdf, or epub)');
  static String get fileRequired   => t(
      'Lazima uweke angalau faili la maandishi',
      'You must add at least a text file');

  // ════════════════════════════════════════════════
  // COMMENTS
  // ════════════════════════════════════════════════
  static String get comments       => t('Maoni', 'Comments');
  static String get writeComment   => t('Andika maoni yako...', 'Write your comment...');
  static String get noComments     => t('Hakuna maoni bado', 'No comments yet');
  static String get beFirst        => t('Kuwa wa kwanza kutoa maoni!', 'Be the first to comment!');

  // ════════════════════════════════════════════════
  // WALLET
  // ════════════════════════════════════════════════
  static String get myWallet       => t('Mkoba Wangu', 'My Wallet');
  static String get balance        => t('Salio', 'Balance');
  static String get myBalance      => t('Salio Lako', 'Your Balance');
  static String get topUp          => t('Weka Pesa', 'Top Up');
  static String get addMoneyTitle  => t('Weka Pesa Mkononi', 'Add Money to Wallet');
  static String get amountTzs      => t('Kiasi (TZS)', 'Amount (TZS)');
  static String get invalidAmount  => t('Ingiza kiasi sahihi', 'Enter valid amount');
  static String get addMoney       => t('Weka', 'Add');
  static String get txHistory      => t('Historia ya Shughuli', 'Transaction History');
  static String get noTx           => t('Hakuna shughuli bado.', 'No transactions yet.');

  // ════════════════════════════════════════════════
  // SUBSCRIPTION
  // ════════════════════════════════════════════════
  static String get subPlans       => t('Mipango ya Usajili', 'Subscription Plans');
  static String get readUnlimited  => t('Soma bila Mipaka', 'Read Unlimited');
  static String get choosePlan     => t('Chagua mpango unaokufaa na ufurahie vitabu vyote',
                                        'Choose a plan and enjoy all books');
  static String get choose         => t('Chagua', 'Choose');
  static String get perDays        => t('siku', 'days');
  static String get subSuccess     => t('Umefanikiwa kujisajili!', 'Subscription successful!');
  static String get popular        => t('MAARUFU', 'POPULAR');
  static String get whatYouGet     => t('Unachopata', 'What You Get');
  static String get noPlans        => t('Hakuna mipango bado.', 'No plans yet.');
  static String get benefitAllBooks     => t('Vitabu Vyote', 'All Books');
  static String get benefitAllBooksDesc => t('Soma vitabu yote bila kikwazo', 'Read all books without limits');
  static String get benefitOffline      => t('Soma Offline', 'Read Offline');
  static String get benefitOfflineDesc  => t('Pakua na soma bila internet', 'Download and read without internet');
  static String get benefitCancel       => t('Futa Wakati Wowote', 'Cancel Anytime');
  static String get benefitCancelDesc   => t('Hakuna mkataba wa lazima', 'No required contract');
  static String get currentPlan    => t('Mpango wa Sasa', 'Current Plan');
  static String get freePlanBadge  => t('BURE', 'FREE');
  static String get perMonth       => t('kwa mwezi', 'per month');

  // ── Book plan-availability (upload/edit) ──
  static String get availableTo        => t('Kitabu Hiki Kipatikane Kwa', 'This Book is Available To');
  static String get availableToDesc    => t('Chagua kiwango cha chini cha mpango wa usajili kinachohitajika kusoma kitabu hiki',
                                            'Choose the minimum subscription plan level required to access this book');
  static String get planLevelAll       => t('Wote (pamoja na mpango wa Bure)', 'Everyone (including Free plan)');
  static String get planLevelFrom      => t('na zaidi', 'and above');
  static String get planLevelOnly      => t('pekee', 'only');

  // ── Locked book badge ──
  static String get lockedBook         => t('Imefungwa', 'Locked');
  static String get upgradeToUnlock    => t('Pandisha Mpango Kufungua', 'Upgrade Plan to Unlock');
  static String get requiresPlanPrefix => t('Inahitaji mpango wa', 'Requires plan');
  static String get goToPlans          => t('Tazama Mipango', 'View Plans');

  // ════════════════════════════════════════════════
  // KIKOMO CHA UMRI / AGE RESTRICTION
  // ════════════════════════════════════════════════
  static String get minAgeLabel        => t('Kikomo cha Umri', 'Age Restriction');
  static String get minAgeDesc         => t('Chagua umri wa chini unaohitajika kusoma/kusikiliza kitabu hiki',
                                            'Choose the minimum age required to access this book');
  static String minAgeOption(int age)  => age == 0
      ? t('Hakuna kikomo (Wote)', 'No limit (Everyone)')
      : t('Miaka $age+', 'Ages $age+');
  static String ageBadge(int age)      => t('Miaka $age+', '$age+');
  static String get ageRestrictionTitle => t('Kitabu cha Watu Wazima', 'Age-Restricted Book');
  static String ageRestrictionMessage(int minAge) => t(
      'Kitabu hiki ni kwa wasomaji wenye umri wa miaka $minAge na kuendelea.',
      'This book is restricted to readers aged $minAge and above.');
  static String get ageRestrictionNoDob => t(
      'Weka tarehe yako ya kuzaliwa kwenye wasifu ili kuangalia ruhusa.',
      'Add your date of birth in your profile to check eligibility.');
  static String get ageRestrictionTooYoung => t(
      'Samahani, huna ruhusa ya kufungua kitabu hiki kwa sasa.',
      'Sorry, you are not eligible to access this book.');
  static String get goToProfile        => t('Tazama Wasifu', 'Go to Profile');

  // ── Tarehe ya Kuzaliwa / Date of Birth ──
  static String get dateOfBirth        => t('Tarehe ya Kuzaliwa', 'Date of Birth');
  static String get dateOfBirthOptional => t('Tarehe ya Kuzaliwa (Hiari)', 'Date of Birth (Optional)');
  static String get dateOfBirthHint    => t('Inatumika kuonyesha vitabu vinavyofaa umri wako',
                                            'Used to show age-appropriate books for you');
  static String get selectDate         => t('Chagua Tarehe', 'Select date');
  static String get dateOfBirthSaved   => t('Tarehe ya kuzaliwa imehifadhiwa', 'Date of birth saved');
  static String get notSet             => t('Haijawekwa', 'Not set');

  // ════════════════════════════════════════════════
  // PROFILE
  // ════════════════════════════════════════════════
  static String get failedProfile  => t('Imeshindwa kupakia wasifu.', 'Failed to load profile.');
  static String get personalBio    => t('Maelezo ya Kibinafsi', 'Personal Description');
  static String get bioHint        => t('Jieleze kidogo...', 'Describe yourself...');
  static String get profileSaved   => t('Wasifu umehifadhiwa!', 'Profile saved!');
  static String get saveBio        => t('Hifadhi Mabadiliko', 'Save Changes');
  static String get changePhoto    => t('Badilisha Picha ya Profaili', 'Change Profile Picture');
  static String get photoUpdated   => t('Picha ya profaili imebadilishwa!', 'Profile picture updated!');
  static String get failedPhoto    => t('Imeshindwa kupakia picha', 'Failed to upload picture');
  static String get changePassword => t('Badilisha Nenosiri', 'Change Password');
  static String get oldPassword    => t('Nenosiri la Sasa', 'Current Password');
  static String get newPassword    => t('Nenosiri Jipya', 'New Password');
  static String get confirmPassword => t('Thibitisha Nenosiri Jipya', 'Confirm New Password');
  static String get passwordChanged => t('Nenosiri limebadilishwa kwa mafanikio!', 'Password changed successfully!');
  static String get passwordsNoMatch => t('Manenosiri mapya hayafanani', 'New passwords do not match');
  static String get passwordTooShort => t('Nenosiri jipya liwe na herufi/namba angalau 6', 'New password must be at least 6 characters');
  static String get fillAllFields  => t('Jaza sehemu zote', 'Fill in all fields');

  // ════════════════════════════════════════════════
  // AUTHOR DASHBOARD
  // ════════════════════════════════════════════════
  static String get dashboard      => t('Dashibodi', 'Dashboard');
  static String get authorDashboard => t('Dashibodi ya Mwandishi', 'Author Dashboard');
  static String get myBooks        => t('Vitabu Vyangu', 'My Books');
  static String get balanceTzs     => t('Salio (TZS)', 'Balance (TZS)');
  static String get readers        => t('Wasomaji', 'Readers');
  static String get quickActions   => t('Vitendo vya Haraka', 'Quick Actions');
  static String get uploadBookShort => t('Pakia\nKitabu', 'Upload\nBook');
  static String get walletShort    => t('Mkoba\nWangu', 'My\nWallet');
  static String get profileShort   => t('Wasifu\nWangu', 'My\nProfile');
  static String get noBooksYet     => t('Huna vitabu bado', 'No books yet');
  static String get noBooksDesc    => t('Bonyeza "Pakia Kitabu" kuanza', 'Tap "Upload Book" to start');
  static String get uploadFirst    => t('Pakia Kitabu cha Kwanza', 'Upload Your First Book');
  static String get published      => t('Imechapishwa', 'Published');
  static String get draft          => t('Rasimu', 'Draft');
  static String get stats          => t('Takwimu', 'Statistics');

  // ════════════════════════════════════════════════
  // SORT / FILTER
  // ════════════════════════════════════════════════
  static String get sortNewest     => t('Mpya Zaidi', 'Newest');
  static String get sortPriceAsc   => t('Bei: Chini kwenda Juu', 'Price: Low to High');
  static String get sortPriceDesc  => t('Bei: Juu kwenda Chini', 'Price: High to Low');
  static String get freeOnly       => t('Bure tu', 'Free only');
  static String get booksResult    => t('vitabu', 'books');

  // ════════════════════════════════════════════════
  // SEARCH
  // ════════════════════════════════════════════════
  static String get searchResults  => t('Matokeo', 'Results');
  static String get noResults      => t('Hakuna matokeo kwa', 'No results for');
  static String get typeToSearch   => t('Andika kutafuta vitabu...', 'Type to search books...');

  // ════════════════════════════════════════════════
  // LIBRARY METADATA — Taarifa za Kimaktaba
  // ════════════════════════════════════════════════
  static String get metadataTitle    => t('Taarifa za Kimaktaba', 'Library Information');
  static String get isbn             => t('ISBN', 'ISBN');
  static String get isbnHint         => t('Mfano: 978-9987-123-45-6', 'e.g. 978-9987-123-45-6');
  static String get isbnInvalid      => t('ISBN lazima iwe nambari 10 au 13', 'ISBN must be 10 or 13 digits');
  static String get bookAuthors      => t('Waandishi wa Kitabu', 'Book Authors');
  static String get bookAuthorsHint  => t('Majina ya waandishi, tenganisha kwa koma', 'Author names, comma-separated');
  static String get publisher        => t('Mchapishaji / Kampuni', 'Publisher / Company');
  static String get publisherHint    => t('Mfano: Oxford University Press', 'e.g. Oxford University Press');
  static String get yearPublished    => t('Mwaka wa Kuchapishwa', 'Year Published');
  static String get yearHint         => t('Mfano: 2024', 'e.g. 2024');
  static String get yearInvalid      => t('Weka mwaka sahihi (1800–sasa)', 'Enter a valid year (1800–present)');
  static String get edition          => t('Toleo', 'Edition');
  static String get editionHint      => t('Mfano: Toleo la 2', 'e.g. 2nd Edition');
  static String get pageCount        => t('Idadi ya Kurasa', 'Number of Pages');
  static String get pageCountHint    => t('Mfano: 350', 'e.g. 350');
  static String get bookLanguage     => t('Lugha ya Kitabu', 'Book Language');
  static String get optional         => t('(Hiari)', '(Optional)');
  static String get bookInfo         => t('Maelezo ya Kitabu', 'Book Details');
  static String get metaSectionNote  => t('Taarifa hizi husaidia wasomaji kupata kitabu haraka', 'This info helps readers find the book faster');

  // Detail screen metadata labels
  static String get detailAuthors    => t('Waandishi', 'Authors');
  static String get detailPublisher  => t('Mchapishaji', 'Publisher');
  static String get detailYear       => t('Mwaka', 'Year');
  static String get detailEdition    => t('Toleo', 'Edition');
  static String get detailPages      => t('Kurasa', 'Pages');
  static String get detailLanguage   => t('Lugha', 'Language');
  static String get detailIsbn       => t('ISBN', 'ISBN');
  static String get detailCategory   => t('Kategoria', 'Category');
  static String get detailFormat     => t('Muundo', 'Format');
  static String get formatText       => t('Maandishi', 'Text');
  static String get formatAudio      => t('Sauti', 'Audio');
  static String get formatBoth       => t('Maandishi & Sauti', 'Text & Audio');
  static String get notAvailable     => t('Haipatikani', 'N/A');
  static String get readNow          => t('Soma Sasa', 'Read Now');
  static String get listenNow        => t('Sikiliza Sasa', 'Listen Now');

  // ════════════════════════════════════════════════
  // COMMENT / CHAT SYSTEM
  // ════════════════════════════════════════════════
  static String get discussion       => t('Majadiliano', 'Discussion');
  static String get replyTo          => t('Jibu kwa', 'Replying to');
  static String get authorBadge      => t('Mwandishi', 'Author');
  static String get deletedMsg       => t('🗑 Ujumbe huu umefutwa', '🗑 Message deleted');
  static String get deleteMsg        => t('Futa Ujumbe', 'Delete Message');
  static String get replyMsg         => t('Jibu', 'Reply');
  static String get cancelReply      => t('Ghairi Jibu', 'Cancel Reply');
  static String get confirmDelete    => t('Una uhakika wa kufuta ujumbe huu?', 'Are you sure you want to delete this message?');
  static String get deleted          => t('Imefutwa', 'Deleted');
  static String get msgDeleted       => t('Ujumbe umefutwa', 'Message deleted');
  static String get sendFailed       => t('Imeshindwa kutuma', 'Failed to send');
  static String get typeMessage      => t('Andika ujumbe...', 'Type a message...');
  static String get participants     => t('washiriki', 'participants');
  static String get reactWith        => t('Ongeza Emoji', 'Add Emoji');

  // ════════════════════════════════════════════════
  // MODERATION: REPORT / FLAG / BAN
  // ════════════════════════════════════════════════
  static String get reportMsg         => t('Ripoti Ujumbe', 'Report Message');
  static String get reportReason      => t('Chagua sababu ya kuripoti', 'Select a reason for reporting');
  static String get reasonProfanity   => t('Lugha Chafu / Matusi', 'Profanity / Bad Language');
  static String get reasonSpam        => t('Spam', 'Spam');
  static String get reasonHarassment  => t('Unyanyasaji', 'Harassment');
  static String get reasonOther       => t('Nyingine', 'Other');
  static String get reportDetails     => t('Maelezo ya ziada (hiari)', 'Additional details (optional)');
  static String get submitReport      => t('Tuma Ripoti', 'Submit Report');
  static String get reportSent        => t('Ripoti imetumwa kwa mfumo. Asante!', 'Report sent to the system. Thank you!');
  static String get alreadyReported   => t('Tayari umeripoti ujumbe huu', 'You already reported this message');
  static String get flaggedMsg        => t('⚠️ Ujumbe huu una lugha isiyofaa', '⚠️ This message contains inappropriate language');
  static String get removeViolation   => t('Ondoa kwa Kukiuka Kanuni', 'Remove for Violation');
  static String get removedByAuthor   => t('🚫 Ujumbe umeondolewa na mwandishi', '🚫 Message removed by the author');
  static String get accountBanned     => t('Akaunti Yako Imefungiwa', 'Your Account Is Banned');
  static String get cannotComment     => t('Akaunti yako imefungiwa kuandika maoni kwa kukiuka kanuni za mfumo.', 'Your account has been banned from posting comments due to violating system rules.');

  // ════════════════════════════════════════════════
  // NOTIFICATIONS
  // ════════════════════════════════════════════════
  static String get notifications     => t('Arifa', 'Notifications');
  static String get noNotifications   => t('Huna arifa kwa sasa', 'You have no notifications yet');
  static String get markAllRead       => t('Weka zote kama zimesomwa', 'Mark all as read');
  static String get newMessageNotif   => t('Ujumbe Mpya', 'New Message');
  static String get justNow           => t('Sasa hivi', 'Just now');
  static String get minutesAgo        => t('dakika zilizopita', 'minutes ago');
  static String get hoursAgo          => t('masaa yaliyopita', 'hours ago');
  static String get daysAgo           => t('siku zilizopita', 'days ago');
  static String get viewDiscussion    => t('Tazama Mjadala', 'View Discussion');

  // ════════════════════════════════════════════════
  // AUTHOR BROADCAST MESSAGE
  // ════════════════════════════════════════════════
  static String get messageReaders    => t('Tuma Ujumbe kwa Wasomaji', 'Message Readers');
  static String get broadcastHint     => t('Andika ujumbe wako kwa wasomaji wa kitabu hiki...', 'Write your message to the readers of this book...');
  static String get broadcastSend     => t('Tuma kwa Wasomaji', 'Send to Readers');
  static String get broadcastSentOk   => t('Ujumbe umetumwa kwa wasomaji', 'Message sent to readers');
  static String get broadcastNoReaders=> t('Hakuna msomaji aliyenunua au kusajili kitabu hiki bado', 'No reader has purchased or subscribed to this book yet');
  static String get broadcastEmpty    => t('Andika ujumbe kwanza', 'Write a message first');

  // ════════════════════════════════════════════════
  // AUTHOR READERS STATS
  // ════════════════════════════════════════════════
  static String get readersStats        => t('Takwimu za Wasomaji', 'Readers Stats');
  static String get totalReaders        => t('Jumla ya Wasomaji', 'Total Readers');
  static String get readersPerBook      => t('Wasomaji kwa Kila Kitabu', 'Readers per Book');
  static String get noReadersYet        => t('Hakuna msomaji bado', 'No readers yet');
  static String get buyersLabel         => t('Wamenunua', 'Purchased');
  static String get readersLabel        => t('Wasomaji', 'Readers');

  // ════════════════════════════════════════════════
  // WISHLIST
  // ════════════════════════════════════════════════
  static String get wishlist            => t('Wishlist', 'Wishlist');
  static String get myWishlist          => t('Wishlist Yangu', 'My Wishlist');
  static String get addToWishlist       => t('Ongeza kwenye Wishlist', 'Add to Wishlist');
  static String get removeFromWishlist  => t('Toa kwenye Wishlist', 'Remove from Wishlist');
  static String get addedToWishlist     => t('Kimeongezwa kwenye Wishlist', 'Added to Wishlist');
  static String get removedFromWishlist => t('Kimetolewa kwenye Wishlist', 'Removed from Wishlist');
  static String get wishlistEmpty       => t('Wishlist yako iko tupu', 'Your wishlist is empty');
  static String get wishlistEmptyHint   => t('Ongeza vitabu unavyotaka kuvinunua baadaye', 'Add books you want to buy later');

  // ════════════════════════════════════════════════
  // CART / BILL
  // ════════════════════════════════════════════════
  static String get cart                => t('Kikapu', 'Cart');
  static String get myCart              => t('Kikapu Changu', 'My Cart');
  static String get addToCart           => t('Ongeza kwenye Kikapu', 'Add to Cart');
  static String get removeFromCart      => t('Toa kwenye Kikapu', 'Remove from Cart');
  static String get addedToCart         => t('Kimeongezwa kwenye Kikapu', 'Added to Cart');
  static String get cartEmpty           => t('Kikapu chako kiko tupu', 'Your cart is empty');
  static String get cartEmptyHint       => t('Ongeza vitabu unavyotaka kununua', 'Add books you want to buy');
  static String get total               => t('Jumla', 'Total');
  static String get payAll              => t('Lipa Vyote', 'Pay All');
  static String get paySelected         => t('Lipa Vilivyochaguliwa', 'Pay Selected');
  static String get checkoutSuccess     => t('Malipo yamefanikiwa', 'Payment successful');
  static String get insufficientBalance => t('Mizania haitoshi', 'Insufficient balance');
  static String get selectAtLeastOne    => t('Chagua angalau kitabu kimoja', 'Select at least one book');
  static String get alreadyInCart       => t('Kipo kwenye Kikapu', 'Already in Cart');

  // ════════════════════════════════════════════════
  // MAKUNDI UNAYOPENDA / FOR YOU / BEST SELLERS
  // ════════════════════════════════════════════════
  static String get chooseFavCategories   => t('Chagua Makundi Unayopenda', 'Choose Your Favorite Categories');
  static String get chooseFavCategoriesHint => t('Chagua makundi yasiyozidi matatu (3) ya vitabu unavyopenda kusoma', 'Choose up to three (3) categories of books you like to read');
  static String get categoriesMaxReached  => t('Umefikia ukomo wa makundi 3', 'You have reached the limit of 3 categories');
  static String get forYou                => t('Kwa Ajili Yako', 'For You');
  static String get forYouEmpty           => t('Hakuna vitabu kwenye makundi uliyochagua bado', 'No books in your chosen categories yet');
  static String get manageCategories      => t('Makundi Ninayopenda', 'My Favorite Categories');
  static String get myCategories          => t('Makundi Ninayopenda', 'My Favorite Categories');
  static String get myCategoriesHint      => t('Ongeza makundi mengine unayopenda ili kuona vitabu vyake kwa urahisi', 'Add more categories you like to easily see their books');
  static String get saveCategories        => t('Hifadhi', 'Save');
  static String get categoriesSaved       => t('Makundi yamehifadhiwa', 'Categories saved');

  static String get bestSellers           => t('Vinavyosomwa Zaidi', 'Best Sellers');
  static String get bestSellersSub        => t('Vitabu vinavyonunuliwa/visomwa zaidi na wasomaji', 'Most purchased / most read books');

  // ════════════════════════════════════════════════
  // RATING / TATHMINI
  // ════════════════════════════════════════════════
  static String get ratingsAndReviews     => t('Tathmini na Maoni', 'Ratings & Reviews');
  static String get rateThisBook          => t('Toa Tathmini Yako', 'Rate this Book');
  static String get yourRating            => t('Tathmini Yako', 'Your Rating');
  static String get writeReviewHint       => t('Andika maoni yako kuhusu kitabu hiki (si lazima)...', 'Write your review about this book (optional)...');
  static String get submitRating          => t('Tuma Tathmini', 'Submit Rating');
  static String get updateRating          => t('Sasisha Tathmini', 'Update Rating');
  static String get ratingSubmitted       => t('Tathmini imetumwa, asante!', 'Rating submitted, thank you!');
  static String get noRatingsYet          => t('Hakuna tathmini bado. Kuwa wa kwanza kutoa maoni!', 'No ratings yet. Be the first to review!');
  static String get readToRate            => t('Lazima usome/ununue kitabu kwanza ndipo uweze kukitathmini', 'You must read/buy the book first to rate it');
  static String get selectRatingFirst     => t('Chagua nyota kwanza', 'Please select a star rating first');

  // ════════════════════════════════════════════════
  // SETTINGS / MIPANGILIO
  // ════════════════════════════════════════════════
  static String get settings              => t('Mipangilio', 'Settings');
  static String get displaySettings       => t('Mipangilio ya Mwonekano', 'Display Settings');
  static String get textSizeHint          => t('Badilisha ukubwa wa maandishi ili kurahisisha usomaji', 'Adjust text size to make reading easier');
  static String get textSizeSmall         => t('Ndogo', 'Small');
  static String get textSizeNormal        => t('Kawaida', 'Normal');
  static String get textSizeLarge         => t('Kubwa', 'Large');
  static String get resetTextSize         => t('Rejesha Ukubwa wa Kawaida', 'Reset to Default');
  static String get appearance            => t('Mwonekano', 'Appearance');
  static String get appearanceHint        => t('Chagua mandhari ya programu kulingana na wakati wa siku', 'Choose the app theme based on time of day');
  static String get themeLight            => t('Mwanga (Mchana)', 'Light (Day)');
  static String get themeDark             => t('Giza (Usiku)', 'Dark (Night)');
  static String get themeSystem           => t('Mfumo wa Kifaa', 'System Default');
  static String get textPreview           => t('Hivi ndivyo maandishi yatakavyoonekana. Mfano wa sentensi ya kusoma.', 'This is how text will look. Sample reading sentence.');

  // ════════════════════════════════════════════════
  // READER LAYOUT / MTINDO WA KUSOMA
  // ════════════════════════════════════════════════
  static String get readerLayout          => t('Mtindo wa Kusoma', 'Reading Layout');
  static String get layoutScroll          => t('Kushuka Chini (Endelevu)', 'Continuous Scroll');
  static String get layoutScrollHint      => t('Soma ukiteleza chini, kurasa zote zinaonekana mfululizo', 'Scroll down continuously through the whole book');
  static String get layoutPaged           => t('Ukurasa kwa Ukurasa', 'Page by Page');
  static String get layoutPagedHint       => t('Bonyeza kulia kuendelea, kushoto kurudi nyuma — kama kitabu halisi', 'Tap right for next page, left for previous — like a real book');
  static String get pageOf                => t('Ukurasa', 'Page');
  static String get darkMode              => t('Mwanga wa Usiku (Punguza Mng\'ao)', 'Night Mode (Reduce Glare)');
  static String get nextPage              => t('Ukurasa Unaofuata', 'Next Page');
  static String get prevPage              => t('Ukurasa Uliopita', 'Previous Page');

  // ════════════════════════════════════════════════
  // ADMIN DASHBOARD
  // ════════════════════════════════════════════════
  static String get adminDashboard   => t('Dashibodi ya Msimamizi', 'Admin Dashboard');
  static String get overview         => t('Muhtasari', 'Overview');
  static String get totalUsers       => t('Watumiaji Wote', 'Total Users');
  static String get authors          => t('Waandishi', 'Authors');
  static String get bannedUsers      => t('Waliozuiwa', 'Banned Users');
  static String get totalBooks       => t('Vitabu Vyote', 'Total Books');
  static String get publishedBooks   => t('Vilivyochapishwa', 'Published');
  static String get pendingBooks     => t('Vinavyosubiri', 'Pending');
  static String get totalRevenue     => t('Mapato Yote', 'Total Revenue');
  static String get walletBalance    => t('Salio la Mkoba', 'Wallet Balance');
  static String get activeSubs       => t('Wanaojiunga Hai', 'Active Subscriptions');
  static String get totalPlans       => t('Mipango Yote', 'Plans');
  static String get manageUsers      => t('Simamia Watumiaji', 'Manage Users');
  static String get manageBooks      => t('Simamia Vitabu', 'Manage Books');
  static String get managePlans      => t('Simamia Mipango', 'Manage Plans');
  static String get ban              => t('Zuia', 'Ban');
  static String get unban            => t('Ondoa Zuio', 'Unban');
  static String get publish          => t('Chapisha', 'Publish');
  static String get unpublish        => t('Ondoa Uchapishaji', 'Unpublish');
  static String get actionSuccess    => t('Hatua imefanikiwa', 'Action successful');
  static String get noData           => t('Hakuna taarifa', 'No data');
  static String get djangoAdminPanel => t('Paneli ya Wavuti (Django Admin)', 'Web Panel (Django Admin)');
  static String get openInBrowser    => t('Fungua kwenye Kivinjari', 'Open in Browser');

  // ════════════════════════════════════════════════
  // ROYALTIES / MGAWANYO WA MAPATO
  // ════════════════════════════════════════════════
  static String get royalties           => t('Mgawanyo wa Mapato', 'Revenue Sharing');
  static String get commissionSettings  => t('Mipangilio ya Tume', 'Commission Settings');
  static String get purchaseCommission  => t('Tume ya Mauzo ya Moja kwa Moja (%)', 'Direct Purchase Commission (%)');
  static String get subscriptionCommission => t('Tume ya Mapato ya Usajili (%)', 'Subscription Revenue Commission (%)');
  static String get currentMonthPool    => t('Kasha la Mwezi Huu', 'Current Month Pool');
  static String get totalPoolRevenue    => t('Mapato Yote ya Usajili', 'Total Subscription Revenue');
  static String get platformShare       => t('Sehemu ya Mfumo', 'Platform Share');
  static String get authorsPool         => t('Sehemu ya Waandishi', 'Authors\' Pool');
  static String get totalReads          => t('Jumla ya Usomaji', 'Total Reads');
  static String get distributeNow       => t('Gawa Mapato Sasa', 'Distribute Now');
  static String get alreadyDistributed  => t('Mapato ya mwezi huu yamesha gawanywa', 'This month\'s revenue has already been distributed');
  static String get distributionPreview => t('Mchanganuo wa Mgawanyo', 'Distribution Breakdown');
  static String get myEarnings          => t('Mapato Yangu', 'My Earnings');
  static String get fromPurchases       => t('Kutoka Mauzo', 'From Purchases');
  static String get fromSubscriptions   => t('Kutoka Usajili', 'From Subscriptions');
  static String get totalEarnings       => t('Jumla ya Mapato', 'Total Earnings');
  static String get earningsHistory     => t('Historia ya Mapato', 'Earnings History');
  static String get confirmDistribute   => t('Una uhakika unataka kugawa mapato ya mwezi huu kwa waandishi sasa? Hatua hii haiwezi kurudishwa.', 'Are you sure you want to distribute this month\'s revenue to authors now? This action cannot be undone.');
}
