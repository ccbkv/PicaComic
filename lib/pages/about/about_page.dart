import 'package:flutter/material.dart';
import 'package:pica_comic/request/config/api_endpoints.dart';

class AboutLicensePage extends StatelessWidget {
  const AboutLicensePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LicensePage(
      applicationName: 'Pica Comic',
      applicationVersion: ApiEndpoints.version,
      applicationLegalese: '开源许可证',
    );
  }
}
