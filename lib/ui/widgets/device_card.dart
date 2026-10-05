import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/iphone_device.dart';
import 'common.dart';
import 'ring.dart';
import 'status_badge.dart';

/// Hero card: device glyph in a ring, name, connection, details grid.
class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    this.statusLabel = 'Connected via USB',
    this.statusColor,
    this.action,
    this.showDetails = true,
  });

  final IPhoneDevice device;
  final String statusLabel;
  final Color? statusColor;
  final Widget? action;
  final bool showDetails;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final theme = Theme.of(context);
    final ios = device.productVersion;
    final status = statusColor ?? colors.ample;
    return SectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UsageRing(
                fraction: 1,
                color: status,
                size: 78,
                stroke: 5,
                child: Icon(
                  Icons.phone_iphone_rounded,
                  color: colors.ink,
                  size: 32,
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: theme.textTheme.displaySmall,
                    ),
                    if (device.displayName != device.modelName)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          device.modelName,
                          style: TextStyle(
                            color: colors.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 18,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusDot(label: statusLabel, color: status),
                        if (ios != null)
                          Text(
                            'iOS $ios',
                            style: TextStyle(
                              color: colors.secondaryText,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 16), action!],
            ],
          ),
          if (showDetails) ...[
            const SizedBox(height: 24),
            Divider(color: colors.hairline),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final rows = <Widget>[
                  InfoRow(
                    label: 'Device Name',
                    value: device.deviceName,
                    padded: false,
                  ),
                  InfoRow(
                    label: 'Model',
                    value: device.modelName,
                    padded: false,
                  ),
                  InfoRow(
                    label: 'Product Type',
                    value: device.productType,
                    monospace: true,
                    padded: false,
                  ),
                  InfoRow(
                    label: 'iOS Version',
                    value: device.productVersion,
                    padded: false,
                  ),
                  InfoRow(
                    label: 'Build Version',
                    value: device.buildVersion,
                    monospace: true,
                    padded: false,
                  ),
                  InfoRow(
                    label: 'UDID',
                    value: device.maskedUdid,
                    monospace: true,
                    padded: false,
                  ),
                ];
                if (c.maxWidth < 620) return Column(children: rows);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: rows.sublist(0, 3))),
                    const SizedBox(width: 28),
                    Expanded(child: Column(children: rows.sublist(3))),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
