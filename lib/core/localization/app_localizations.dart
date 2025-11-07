import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  Map<String, String> _localizedStrings = {};

  Future<bool> load() async {
    String jsonString = await rootBundle.loadString('assets/locales/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  // Getters for common strings
  String get appTitle => translate('appTitle');
  String get home => translate('home');
  String get scan => translate('scan');
  String get history => translate('history');
  String get map => translate('map');
  String get profile => translate('profile');
  String get takePhoto => translate('takePhoto');
  String get choosePhoto => translate('choosePhoto');
  String get recordVideo => translate('recordVideo');
  String get chooseVideo => translate('chooseVideo');
  String get liveCamera => translate('liveCamera');
  String get liveDetection => translate('liveDetection');
  String get language => translate('language');
  String get selectLanguage => translate('selectLanguage');
  String get english => translate('english');
  String get tamil => translate('tamil');
  String get sinhala => translate('sinhala');
  String get logout => translate('logout');
  String get createAccount => translate('createAccount');
  String get readyToScan => translate('readyToScan');
  String get scanLeaf => translate('scanLeaf');
  String get fillFrameTip => translate('fillFrameTip');
  String get retry => translate('retry');
  String get modelFailedToLoad => translate('modelFailedToLoad');
  String get pleaseLoginToViewMap => translate('pleaseLoginToViewMap');
  String get detectionResults => translate('detectionResults');
  String get prediction => translate('prediction');
  String get detectionAccuracy => translate('detectionAccuracy');
  String get recommendedTreatment => translate('recommendedTreatment');
  String get askMoreQuestions => translate('askMoreQuestions');
  String get save => translate('save');
  String get scanAgain => translate('scanAgain');
  String get close => translate('close');
  String get done => translate('done');
  String get editProfile => translate('editProfile');
  String get updateNameAndEmail => translate('updateNameAndEmail');
  String get changePassword => translate('changePassword');
  String get updateAccountPassword => translate('updateAccountPassword');
  String get teaHealthUser => translate('teaHealthUser');
  String get healthChecks => translate('healthChecks');
  String get name => translate('name');
  String get email => translate('email');
  String get cancel => translate('cancel');
  String get enterYourName => translate('enterYourName');
  String get enterValidEmail => translate('enterValidEmail');
  String get currentPassword => translate('currentPassword');
  String get newPassword => translate('newPassword');
  String get confirmNewPassword => translate('confirmNewPassword');
  String get enterCurrentPassword => translate('enterCurrentPassword');
  String get min6Characters => translate('min6Characters');
  String get passwordsDoNotMatch => translate('passwordsDoNotMatch');
  String get update => translate('update');
  String get reauthenticationRequired => translate('reauthenticationRequired');
  String get continueText => translate('continue');
  String get profilePhotoUpdated => translate('profilePhotoUpdated');
  String get profileUpdated => translate('profileUpdated');
  String get updatedSuccessfully => translate('updatedSuccessfully');
  String get updateFailed => translate('updateFailed');
  String get logoutFailed => translate('logoutFailed');
  String get passwordChanged => translate('passwordChanged');
  String get passwordChangeFailed => translate('passwordChangeFailed');
  String get reauthFailed => translate('reauthFailed');
  String get uploadFailed => translate('uploadFailed');
  String get verificationSentTo => translate('verificationSentTo');
  String get confirmViaInbox => translate('confirmViaInbox');
  String get emailUpdateFailed => translate('emailUpdateFailed');
  String get pleaseLoginToSeeHistory => translate('pleaseLoginToSeeHistory');
  String get failedToLoadHistory => translate('failedToLoadHistory');
  String get noScansYet => translate('noScansYet');
  String get scanTeaLeafToSeeResults => translate('scanTeaLeafToSeeResults');
  String get noScansFound => translate('noScansFound');
  String get clearSearch => translate('clearSearch');
  String get searchByDate => translate('searchByDate');
  String get date => translate('date');
  String get select => translate('select');
  String get deleteScan => translate('deleteScan');
  String get delete => translate('delete');
  String get permanentlyRemoveScan => translate('permanentlyRemoveScan');
  String get scanDeleted => translate('scanDeleted');
  String get deleteFailed => translate('deleteFailed');
  String get showLess => translate('showLess');
  String get showMore => translate('showMore');
  String get source => translate('source');
  String get confidence => translate('confidence');
  String get scannedAt => translate('scannedAt');
  String get scanDetail => translate('scanDetail');
  String get today => translate('today');
  String get yesterday => translate('yesterday');
  String get justNow => translate('justNow');
  String get minAgo => translate('minAgo');
  String get hrAgo => translate('hrAgo');
  String get jan => translate('jan');
  String get feb => translate('feb');
  String get mar => translate('mar');
  String get apr => translate('apr');
  String get may => translate('may');
  String get jun => translate('jun');
  String get jul => translate('jul');
  String get aug => translate('aug');
  String get sep => translate('sep');
  String get oct => translate('oct');
  String get nov => translate('nov');
  String get dec => translate('dec');
  String get from => translate('from');
  String get until => translate('until');
  String get teaHealthMap => translate('teaHealthMap');
  String get loadingMap => translate('loadingMap');
  String get preparingMarkers => translate('preparingMarkers');
  String get myLocation => translate('myLocation');
  String get noScanLocations => translate('noScanLocations');
  String get scanTeaLeavesToSeeLocations => translate('scanTeaLeavesToSeeLocations');
  String get locationPermissionDenied => translate('locationPermissionDenied');
  String get failedToGetLocation => translate('failedToGetLocation');
  String get viewDetails => translate('viewDetails');
  String get analyzing => translate('analyzing');
  String get detectionFailed => translate('detectionFailed');
  String get unknownErrorOccurred => translate('unknownErrorOccurred');
  String get goBack => translate('goBack');
  String get pinchToZoom => translate('pinchToZoom');
  String get gettingRecommendations => translate('gettingRecommendations');
  String get noRecommendationsAvailable => translate('noRecommendationsAvailable');
  String get errorLoadingRecommendations => translate('errorLoadingRecommendations');
  String get askAboutTreatment => translate('askAboutTreatment');
  String get saved => translate('saved');
  String get pleaseLoginToSaveScans => translate('pleaseLoginToSaveScans');
  String get scanSavedToHistory => translate('scanSavedToHistory');
  String get failedToSave => translate('failedToSave');
  String get noDiseaseDetected => translate('noDiseaseDetected');
  String get notTeaLeafGuidance => translate('notTeaLeafGuidance');
  String get scanningForTeaLeaf => translate('scanningForTeaLeaf');
  String get holdSteadyForResults => translate('holdSteadyForResults');
  String get comeCloserForDetection => translate('comeCloserForDetection');
  String get moveCloserGuidance => translate('moveCloserGuidance');
  String get positionTeaLeafCenter => translate('positionTeaLeafCenter');
  String get positionTeaLeafCenterShort => translate('positionTeaLeafCenterShort');
  String get flashOn => translate('flashOn');
  String get flashOff => translate('flashOff');
  String get switchCamera => translate('switchCamera');
  String get readyToScanLive => translate('readyToScanLive');
  String get fillFrameWithTeaLeaf => translate('fillFrameWithTeaLeaf');
  String get teaLeafDetected => translate('teaLeafDetected');
  String get notATeaLeaf => translate('notATeaLeaf');
  String get scanning => translate('scanning');
  String get waiting => translate('waiting');
  String get treatmentNotAvailable => translate('treatmentNotAvailable');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ta', 'si'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}



