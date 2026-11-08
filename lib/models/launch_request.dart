/// Values are already split by the calling shell. Never split or evaluate them.
enum LaunchInputKind { auto, file, text }

class LaunchInput {
  const LaunchInput(this.value, {this.kind = LaunchInputKind.auto});
  final String value;
  final LaunchInputKind kind;
}

enum LaunchAction { open, help, version }

class LaunchPlan {
  const LaunchPlan(this.inputs, {this.action = LaunchAction.open});
  final List<LaunchInput> inputs;
  final LaunchAction action;
  factory LaunchPlan.parse(List<String> arguments) {
    final inputs = <LaunchInput>[];
    var literal = false;
    for (var i = 0; i < arguments.length; i++) {
      final value = arguments[i];
      if (!literal && value == '--') {
        literal = true;
        continue;
      }
      if (!literal && value == '--help') {
        return const LaunchPlan([], action: LaunchAction.help);
      }
      if (!literal && value == '--version') {
        return const LaunchPlan([], action: LaunchAction.version);
      }
      if (!literal && (value == '--file' || value == '--json')) {
        if (++i >= arguments.length) {
          throw FormatException('$value requires an argument');
        }
        inputs.add(
          LaunchInput(
            arguments[i],
            kind: value == '--file'
                ? LaunchInputKind.file
                : LaunchInputKind.text,
          ),
        );
      } else {
        if (!literal && value.startsWith('--')) {
          throw FormatException('Unknown option: $value');
        }
        inputs.add(LaunchInput(value));
      }
    }
    return LaunchPlan(inputs);
  }
}

class LaunchDocument {
  const LaunchDocument({
    required this.text,
    this.name,
    this.path,
    this.deferred = false,
  });
  final String text;
  final bool deferred;
  final String? name, path;
  bool get unsaved => path == null;
}

class LaunchIssue {
  const LaunchIssue(this.input, this.message, {this.path});
  final String input, message;
  final String? path;
}

class LaunchResult {
  const LaunchResult({this.documents = const [], this.issues = const []});
  final List<LaunchDocument> documents;
  final List<LaunchIssue> issues;
}
