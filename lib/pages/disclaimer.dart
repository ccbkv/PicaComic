import 'package:flutter/material.dart';
import 'package:pica_comic/foundation/disclaimer_content.dart';
import 'package:pica_comic/utils/translations.dart';

/// Shared text, including the emphasis approved in the preview.
class DisclaimerBody extends StatelessWidget {
  const DisclaimerBody({super.key, this.sectionKeys, this.wide = false});
  final List<GlobalKey>? sectionKeys;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var section = 0; section < kDisclaimerSections.length; section++)
          Padding(
            key: sectionKeys?[section],
            padding: EdgeInsets.only(top: section == 0 ? 0 : 9, bottom: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  kDisclaimerSections[section].$1.tl,
                  style: TextStyle(
                    fontSize: wide ? 15 : 14,
                    fontWeight: FontWeight.w600,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 12),
                for (
                  var row = 0;
                  row < kDisclaimerSections[section].$2.length;
                  row++
                )
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: section == 6 || (section == 8 && row == 2)
                        ? const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          )
                        : section == 4 && row == 4
                        ? const EdgeInsets.only(left: 14)
                        : EdgeInsets.zero,
                    decoration: section == 6 || (section == 8 && row == 2)
                        ? BoxDecoration(
                            color: colors.primaryContainer,
                            border: Border(
                              left: BorderSide(color: colors.primary, width: 3),
                            ),
                          )
                        : section == 4 && row == 4
                        ? const BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Color(0xffb28d48),
                                width: 3,
                              ),
                            ),
                          )
                        : null,
                    child: Text(
                      kDisclaimerSections[section].$2[row].tl,
                      style: TextStyle(
                        fontSize: wide ? 14 : 13,
                        height: 2.05,
                        fontWeight: section == 6 || (section == 8 && row == 2)
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

void showDisclaimerDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                kDisclaimerTitle.tl,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('v$kDisclaimerVersion · $kDisclaimerDate'),
              const SizedBox(height: 12),
              const Expanded(
                child: SingleChildScrollView(child: DisclaimerBody()),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('OK'.tl),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
