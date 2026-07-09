import 'package:equatable/equatable.dart';

enum ProjectType {
  flutter,
  node,
  python,
  rust,
  go,
  java,
  kotlin,
  swift,
  gitRepo,
  general,
  unknown,
}

extension ProjectTypeX on ProjectType {
  String get displayName {
    switch (this) {
      case ProjectType.flutter:
        return 'Flutter';
      case ProjectType.node:
        return 'Node.js';
      case ProjectType.python:
        return 'Python';
      case ProjectType.rust:
        return 'Rust';
      case ProjectType.go:
        return 'Go';
      case ProjectType.java:
        return 'Java';
      case ProjectType.kotlin:
        return 'Kotlin';
      case ProjectType.swift:
        return 'Swift';
      case ProjectType.gitRepo:
        return 'Git repository';
      case ProjectType.general:
        return 'General project';
      case ProjectType.unknown:
        return 'Unknown';
    }
  }
}

class WorkspaceInfo extends Equatable {
  const WorkspaceInfo({
    required this.path,
    required this.name,
    required this.projectTypes,
    this.gitBranch,
    this.isGitRepo = false,
  });

  final String path;
  final String name;
  final List<ProjectType> projectTypes;
  final String? gitBranch;
  final bool isGitRepo;

  String get primaryProjectType {
    if (projectTypes.isEmpty) return ProjectType.unknown.displayName;
    return projectTypes.first.displayName;
  }

  @override
  List<Object?> get props => [path, name, projectTypes, gitBranch, isGitRepo];
}
