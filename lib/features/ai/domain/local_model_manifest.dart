import 'local_model_spec.dart';
import 'local_model_task.dart';

class LocalModelManifest {
  const LocalModelManifest({
    required this.schemaVersion,
    required this.runtimeProfile,
    required this.models,
  });

  final int schemaVersion;
  final String runtimeProfile;
  final List<LocalModelSpec> models;

  LocalModelSpec? byTask(LocalModelTask task) {
    for (final model in models) {
      if (model.task == task) {
        return model;
      }
    }
    return null;
  }

  int get packagedCount => models.where((model) => model.packaged).length;

  factory LocalModelManifest.fromJson(Map<String, dynamic> json) {
    final rawModels = (json['models'] as List<dynamic>? ?? const []);
    return LocalModelManifest(
      schemaVersion: json['schema_version'] as int? ?? 1,
      runtimeProfile: json['runtime_profile'] as String? ?? 'unknown',
      models: rawModels
          .map((item) => LocalModelSpec.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
