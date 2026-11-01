import 'package:flutter/widgets.dart';

import 'store.dart';

/// ให้ทุกหน้าเข้าถึง AppStore และ rebuild เมื่อข้อมูลเปลี่ยน
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

