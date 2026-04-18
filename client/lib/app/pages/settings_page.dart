import 'package:flutter/material.dart';

/// Settings tab. M0-01 surface only; real preference wiring
/// (distance/volume/currency/timezone) lands with the `settings` DAO
/// in M1.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.straighten),
          title: Text('Distance unit'),
          subtitle: Text('km (default)'),
        ),
        ListTile(
          leading: Icon(Icons.local_drink),
          title: Text('Volume unit'),
          subtitle: Text('L (default)'),
        ),
        ListTile(
          leading: Icon(Icons.attach_money),
          title: Text('Currency'),
          subtitle: Text('USD (default)'),
        ),
        ListTile(
          leading: Icon(Icons.schedule),
          title: Text('Timezone'),
          subtitle: Text('Device default'),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.cloud_off_outlined),
          title: Text('Backup'),
          subtitle: Text('Offline — sign in lands in M3.'),
        ),
      ],
    );
  }
}
