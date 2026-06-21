ETTrace iOS Simulator profiling artifacts for Docmostly performance work.

launch-*:
  Instrumented app launch trace on iPhone 17 Pro simulator.

runtime-preview-before-*:
  MainShell preview page tree -> page reader -> back -> page reader -> scroll flow before passing modelContainer to MainShellDebugPreviewView.

runtime-preview-cache-reader-*:
  Same runtime flow after MainShellDebugPreviewView configures AppState with modelContainer, eliminating named main-actor CacheRepository read stacks from the preview flow.

ETTrace app wiring was done only in a temporary project copy and is not part of the repository project.
