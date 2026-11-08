import 'dart:convert';

import 'dart:io';

import 'package:visor_config/app_info.dart';

void main() => stdout.writeln(
  jsonEncode({
    'name': appName,
    'version': appVersion,
    'author': appAuthor,
    'licenseName': appLicenseName,
    'licenseSpdx': appLicenseSpdx,
    'licenseUrl': appLicenseUrl,
    'repositoryUrl': appRepositoryUrl,
    'issuesUrl': appIssuesUrl,
    'id': appId,
    'packageName': appPackageName,
    'binaryName': appBinaryName,
    'descriptions': appDescriptions,
  }),
);
