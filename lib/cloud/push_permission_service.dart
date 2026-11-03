enum PushPermission {
  unsupported,
  notDetermined,
  denied,
  authorized,
  provisional,
}

abstract interface class PushPermissionService {
  Future<PushPermission> permissionStatus();
  Future<PushPermission> enableNotifications();
}
