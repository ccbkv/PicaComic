// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';

/// Ohos side authentication messages.
///
/// Provides default values for all messages.
@immutable
class OhosAuthMessages extends AuthMessages {
  /// Constructs a new instance.
  const OhosAuthMessages({
    this.biometricHint,
    this.biometricNotRecognized,
    this.biometricRequiredTitle,
    this.biometricSuccess,
    this.cancelButton,
    this.deviceCredentialsRequiredTitle,
    this.deviceCredentialsSetupDescription,
    this.goToSettingsButton,
    this.goToSettingsDescription,
    this.signInTitle,
    this.authType,
  });

  /// Hint message advising the user how to authenticate with biometrics.
  /// Maximum 60 characters.
  final String? biometricHint;

  /// Message to let the user know that authentication was failed.
  /// Maximum 60 characters.
  final String? biometricNotRecognized;

  /// Message shown as a title in a dialog which indicates the user
  /// has not set up biometric authentication on their device.
  /// Maximum 60 characters.
  final String? biometricRequiredTitle;

  /// Message to let the user know that authentication was successful.
  /// Maximum 60 characters
  final String? biometricSuccess;

  /// Message shown on a button that the user can click to leave the
  /// current dialog.
  /// Maximum 30 characters.
  final String? cancelButton;

  /// Message shown as a title in a dialog which indicates the user
  /// has not set up credentials authentication on their device.
  /// Maximum 60 characters.
  final String? deviceCredentialsRequiredTitle;

  /// Message advising the user to go to the settings and configure
  /// device credentials on their device.
  final String? deviceCredentialsSetupDescription;

  /// Message shown on a button that the user can click to go to settings pages
  /// from the current dialog.
  /// Maximum 30 characters.
  final String? goToSettingsButton;

  /// Message advising the user to go to the settings and configure
  /// biometric on their device.
  final String? goToSettingsDescription;

  /// Message shown as a title in a dialog which indicates the user
  /// that they need to scan biometric to continue.
  /// Maximum 60 characters.
  final String? signInTitle;

  /// This is used to select the biometric type:
  /// FACE、FINGERPRINT、PIN.
  final String? authType;

  @override
  Map<String, String> get args {
    return <String, String>{
      'biometricHint': biometricHint ?? ohosBiometricHint,
      'biometricNotRecognized':
          biometricNotRecognized ?? ohosBiometricNotRecognized,
      'biometricSuccess': biometricSuccess ?? ohosBiometricSuccess,
      'biometricRequired':
          biometricRequiredTitle ?? ohosBiometricRequiredTitle,
      'cancelButton': cancelButton ?? ohosCancelButton,
      'deviceCredentialsRequired': deviceCredentialsRequiredTitle ??
          ohosDeviceCredentialsRequiredTitle,
      'deviceCredentialsSetupDescription': deviceCredentialsSetupDescription ??
          ohosDeviceCredentialsSetupDescription,
      'goToSetting': goToSettingsButton ?? goToSettings,
      'goToSettingDescription':
          goToSettingsDescription ?? ohosGoToSettingsDescription,
      'signInTitle': signInTitle ?? ohosSignInTitle,
      'authType': authType ?? '',
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OhosAuthMessages &&
          runtimeType == other.runtimeType &&
          biometricHint == other.biometricHint &&
          biometricNotRecognized == other.biometricNotRecognized &&
          biometricRequiredTitle == other.biometricRequiredTitle &&
          biometricSuccess == other.biometricSuccess &&
          cancelButton == other.cancelButton &&
          deviceCredentialsRequiredTitle ==
              other.deviceCredentialsRequiredTitle &&
          deviceCredentialsSetupDescription ==
              other.deviceCredentialsSetupDescription &&
          goToSettingsButton == other.goToSettingsButton &&
          goToSettingsDescription == other.goToSettingsDescription &&
          signInTitle == other.signInTitle &&
          authType == other.authType;

  @override
  int get hashCode => Object.hash(
      super.hashCode,
      biometricHint,
      biometricNotRecognized,
      biometricRequiredTitle,
      biometricSuccess,
      cancelButton,
      deviceCredentialsRequiredTitle,
      deviceCredentialsSetupDescription,
      goToSettingsButton,
      goToSettingsDescription,
      signInTitle,
      authType);
}

// Default strings for OhosAuthMessages. Currently supports English.
// Intl.message must be string literals.

/// Message shown on a button that the user can click to go to settings pages
/// from the current dialog.
String get goToSettings => Intl.message('Go to settings',
    desc: 'Message shown on a button that the user can click to go to '
        'settings pages from the current dialog. Maximum 30 characters.');

/// Hint message advising the user how to authenticate with biometrics.
String get ohosBiometricHint => Intl.message('Verify identity',
    desc: 'Hint message advising the user how to authenticate with biometrics. '
        'Maximum 60 characters.');

/// Message to let the user know that authentication was failed.
String get ohosBiometricNotRecognized =>
    Intl.message('Not recognized. Try again.',
        desc: 'Message to let the user know that authentication was failed. '
            'Maximum 60 characters.');

/// Message to let the user know that authentication was successful. It
String get ohosBiometricSuccess => Intl.message('Success',
    desc: 'Message to let the user know that authentication was successful. '
        'Maximum 60 characters.');

/// Message shown on a button that the user can click to leave the
/// current dialog.
String get ohosCancelButton => Intl.message('Cancel',
    desc: 'Message shown on a button that the user can click to leave the '
        'current dialog. Maximum 30 characters.');

/// Message shown as a title in a dialog which indicates the user
/// that they need to scan biometric to continue.
String get ohosSignInTitle => Intl.message('Authentication required',
    desc: 'Message shown as a title in a dialog which indicates the user '
        'that they need to scan biometric to continue. Maximum 60 characters.');

/// Message shown as a title in a dialog which indicates the user
/// has not set up biometric authentication on their device.
String get ohosBiometricRequiredTitle => Intl.message('Biometric required',
    desc: 'Message shown as a title in a dialog which indicates the user '
        'has not set up biometric authentication on their device. '
        'Maximum 60 characters.');

/// Message shown as a title in a dialog which indicates the user
/// has not set up credentials authentication on their device.
String get ohosDeviceCredentialsRequiredTitle =>
    Intl.message('Device credentials required',
        desc: 'Message shown as a title in a dialog which indicates the user '
            'has not set up credentials authentication on their device. '
            'Maximum 60 characters.');

/// Message advising the user to go to the settings and configure
/// device credentials on their device.
String get ohosDeviceCredentialsSetupDescription =>
    Intl.message('Device credentials required',
        desc: 'Message advising the user to go to the settings and configure '
            'device credentials on their device.');

/// Message advising the user to go to the settings and configure
/// biometric on their device.
String get ohosGoToSettingsDescription => Intl.message(
    'Biometric authentication is not set up on your device. Go to '
    "'Settings > Security' to add biometric authentication.",
    desc: 'Message advising the user to go to the settings and configure '
        'biometric on their device.');
