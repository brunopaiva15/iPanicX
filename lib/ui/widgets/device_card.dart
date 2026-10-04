import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/iphone_device.dart';
import 'common.dart';
import 'status_badge.dart';

/// Device identity + connection status, with an optional action area.
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
    return SectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(icon: Icons.phone_iphone, color: colors.blue, size: 64),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: theme.textTheme.headlineSmall,
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
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        StatusDot(
                          label: statusLabel,
                          color: statusColor ?? colors.green,
                        ),
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
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final rows = <Widget>[
                  InfoRow(label: 'Device Name', value: device.deviceName),
                  InfoRow(label: 'Model', value: device.modelName),
                  InfoRow(
                    label: 'Product Type',
                    value: device.productType,
                    monospace: true,
                  ),
                  InfoRow(label: 'iOS Version', value: device.productVersion),
                  InfoRow(
                    label: 'Build Version',
                    value: device.buildVersion,
                    monospace: true,
                  ),
                  InfoRow(
                    label: 'UDID',
                    value: device.maskedUdid,
                    monospace: true,
                  ),
                ];
                if (c.maxWidth < 620) return Column(children: rows);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Column(children: rows.sublist(0, 3))),
                    const SizedBox(width: 24),
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
